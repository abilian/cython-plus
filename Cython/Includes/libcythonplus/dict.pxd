from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from libcpp.vector cimport vector
from libcpp.atomic cimport atomic
from cython.operator cimport dereference

from libcythonplus.iterator cimport *

cdef extern from * nogil:
    """
    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t dict_key_getter_t(base_iterator_t iter)
    {
        return iter->first;
    }

    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t dict_value_getter_t(base_iterator_t iter)
    {
        return iter->second;
    }

    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t dict_item_getter_t(base_iterator_t iter)
    {
        return *iter;
    }

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_key_iterator_t = cy_iterator_t<dict_t, base_iterator_t, reference_t, dict_key_getter_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_value_iterator_t = cy_iterator_t<dict_t, base_iterator_t, reference_t, dict_value_getter_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_item_iterator_t = cy_iterator_t<dict_t, base_iterator_t, reference_t, dict_item_getter_t<base_iterator_t, reference_t>>;


    template <typename dict_t, typename iterator_t>
    class dict_view
    {
    private:
        dict_t urange = NULL;

    public:
        using iterator = iterator_t;

        dict_view() = default;
        dict_view(const dict_view & rhs) = default;
        dict_view(dict_view && rhs) = default;
        dict_view & operator=(const dict_view& rhs) = default;
        dict_view & operator=(dict_view&& rhs) = default;
        ~dict_view() = default;

        dict_view(dict_t urange) : urange(urange) {}

        iterator begin() const
        {
            return iterator(std::begin(urange->_items), urange);
        }

        typename iterator::base end() const
        {
            return std::end(urange->_items);
        }
    };

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_keys_view_t = dict_view<dict_t, dict_key_iterator_t<dict_t, base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_values_view_t = dict_view<dict_t, dict_value_iterator_t<dict_t, base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using dict_items_view_t = dict_view<dict_t, dict_item_iterator_t<dict_t, base_iterator_t, reference_t>>;
    """
    cdef cppclass dict_key_iterator_t[dict_t, base_iterator_t, reference_t]:
        dict_key_iterator_t()
        dict_key_iterator_t(base_iterator_t)
        dict_key_iterator_t(base_iterator_t, const dict_t)
        reference_t operator*()
        dict_key_iterator_t operator++()
        bint operator!=(base_iterator_t)

    cdef cppclass dict_value_iterator_t[dict_t, base_iterator_t, reference_t]:
        dict_value_iterator_t()
        dict_value_iterator_t(base_iterator_t)
        dict_value_iterator_t(base_iterator_t, const dict_t)
        reference_t operator*()
        dict_value_iterator_t operator++()
        bint operator!=(base_iterator_t)

    cdef cppclass dict_item_iterator_t[dict_t, base_iterator_t, reference_t]:
        dict_item_iterator_t()
        dict_item_iterator_t(base_iterator_t)
        dict_item_iterator_t(base_iterator_t, const dict_t)
        reference_t operator*()
        dict_item_iterator_t operator++()
        bint operator!=(base_iterator_t)

    cdef cppclass dict_keys_view_t[dict_t, base_iterator_t, reference_t]:
        ctypedef dict_key_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        dict_keys_view_t()
        dict_keys_view_t(const dict_t)
        dict_key_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()

    cdef cppclass dict_values_view_t[dict_t, base_iterator_t, reference_t]:
        ctypedef dict_value_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        dict_values_view_t()
        dict_values_view_t(const dict_t)
        dict_value_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()

    cdef cppclass dict_items_view_t[dict_t, base_iterator_t, reference_t]:
        ctypedef dict_item_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        dict_items_view_t()
        dict_items_view_t(const dict_t)
        dict_item_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()


cdef cypclass cypdict[K, V]:
    ctypedef K key_type
    ctypedef V value_type
    ctypedef pair[key_type, value_type] item_type
    ctypedef vector[item_type].size_type size_type
    ctypedef dict_key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type] iterator

    vector[item_type] _items
    unordered_map[key_type, size_type] _indices
    atomic[int] _active_iterators

    __init__(self):
        self._active_iterators.store(0)

    V __getitem__(self, const key_type key) except ~ const:
        it = self._indices.find(key)
        if it != self._indices.end():
           return self._items[dereference(it).second].second
        with gil:
            raise KeyError("Getting nonexistent item")

    void __setitem__(self, const key_type key, const value_type value) except ~:
        it = self._indices.find(key)
        if it != self._indices.end():
            index = dereference(it).second
            self._items[index].second = value
        elif self._active_iterators == 0:
            self._indices[key] = self._items.size()
            self._items.push_back(item_type(key, value))
        else:
            with gil:
                raise RuntimeError("Modifying a dictionary with active iterators")

    void __delitem__(self, const key_type key) except ~:
        it = self._indices.find(key)
        if it == self._indices.end():
            with gil:
                raise KeyError("Deleting nonexistent item")
        if self._active_iterators != 0:
            with gil:
                raise RuntimeError("Modifying a dictionary with active iterators")
        index = dereference(it).second
        self._indices.erase(it)
        if index < self._items.size() - 1:
            self._items[index] = self._items[self._indices.size() - 1]
        self._items.pop_back()

    void update(self, const cypdict[K, V] other):
        for item in other.items():
            self[item.first] = item.second

    void clear(self) except ~:
        if self._active_iterators == 0:
            self._items.clear()
            self._indices.clear()
        else:
            with gil:
                raise RuntimeError("Modifying a dictionary with active iterators")

    dict_key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type] begin(self) const:
        return dict_key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type](self._items.begin(), self)

    vector[item_type].iterator end(self) const:
        return self._items.end()

    size_type __len__(self) const:
        return self._items.size()

    bint __contains__(self, const key_type key) const:
        return self._indices.count(key)

    dict_keys_view_t[cypdict[K, V], vector[item_type].iterator, key_type] keys(self) const:
        return dict_keys_view_t[cypdict[K, V], vector[item_type].iterator, key_type](self)

    dict_values_view_t[cypdict[K, V], vector[item_type].iterator, value_type] values(self) const:
        return dict_values_view_t[cypdict[K, V], vector[item_type].iterator, value_type](self)

    dict_items_view_t[cypdict[K, V], vector[item_type].iterator, item_type] items(self) const:
        return dict_items_view_t[cypdict[K, V], vector[item_type].iterator, item_type](self)
