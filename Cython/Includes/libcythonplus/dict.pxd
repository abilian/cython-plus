from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from libcpp.vector cimport vector
from libcpp.atomic cimport atomic
from cython.operator cimport dereference

cdef extern from * nogil:
    """
    template<typename dict_t, typename base_iterator_t, typename reference_t, reference_t (*getter_t)(base_iterator_t)>
    struct dict_iterator_t : base_iterator_t
    {
        using base = base_iterator_t;
        using reference = reference_t;

        dict_t urange = NULL;

        friend void swap(dict_iterator_t & first, dict_iterator_t & second)
        {
            using std::swap;
            swap(first.urange, second.urange);
            swap(static_cast<base&>(first), static_cast<base&>(second));
        }

        dict_iterator_t() = default;
        dict_iterator_t(dict_iterator_t const & rhs) : urange(rhs.urange)
        {
            if (urange != NULL)
            {
                urange->CyObject_INCREF();
                urange->_active_iterators++;
            }
        }

        dict_iterator_t(dict_iterator_t && rhs) : dict_iterator_t()
        {
            std::swap(*this, rhs);
        }

        dict_iterator_t & operator=(dict_iterator_t rhs)
        {
            swap(*this, rhs);
            return *this;
        }

        dict_iterator_t & operator=(base_iterator_t rhs)
        {
            swap(static_cast<base&>(*this), rhs);
            if (urange != NULL) {
                urange->_active_iterators--;
                urange->CyObject_DECREF();
                urange = NULL;
            }
            return *this;
        }

        ~dict_iterator_t()
        {
            if (urange != NULL) {
                urange->_active_iterators--;
                urange->CyObject_DECREF();
                urange = NULL;
            }
        }

        dict_iterator_t(base const & b) : base{b} {}

        dict_iterator_t(base const & b, dict_t urange) : base{b}, urange{urange}
        {
            if (urange != NULL) {
                urange->CyObject_INCREF();
                urange->_active_iterators++;
            }
        }

        dict_iterator_t operator++(int)
        {
            return static_cast<base&>(*this)++;
        }

        dict_iterator_t & operator++()
        {
            ++static_cast<base&>(*this);
            return (*this);
        }

        reference operator*() const
        {
            return getter_t(static_cast<base>(*this));
        }
    };

    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t key_getter_t(base_iterator_t iter)
    {
        return iter->first;
    }

    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t value_getter_t(base_iterator_t iter)
    {
        return iter->second;
    }

    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t item_getter_t(base_iterator_t iter)
    {
        return *iter;
    }

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using key_iterator_t = dict_iterator_t<dict_t, base_iterator_t, reference_t, key_getter_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using value_iterator_t = dict_iterator_t<dict_t, base_iterator_t, reference_t, value_getter_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using item_iterator_t = dict_iterator_t<dict_t, base_iterator_t, reference_t, item_getter_t<base_iterator_t, reference_t>>;


    template <typename dict_t, typename iterator_t>
    class view_dict
    {
    private:
        dict_t urange = NULL;

    public:
        using iterator = iterator_t;

        friend void swap(view_dict & first, view_dict & second)
        {
            using std::swap;
            swap(first.urange, second.urange);
        }

        view_dict() = default;
        view_dict(view_dict const & rhs) : urange(rhs.urange)
        {
            if (urange != NULL)
            {
                urange->CyObject_INCREF();
            }
        }

        view_dict(view_dict && rhs) : view_dict()
        {
            swap(*this, rhs);
        }

        view_dict & operator=(view_dict rhs)
        {
            swap(*this, rhs);
            return *this;
        }

        ~view_dict()
        {
            if (urange != NULL)
            {
                urange->CyObject_DECREF();
                urange = NULL;
            }
        }

        view_dict(dict_t urange) : urange(urange)
        {
            if (urange != NULL)
            {
                urange->CyObject_INCREF();
            }
        }

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
    using view_dict_keys = view_dict<dict_t, key_iterator_t<dict_t, base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using view_dict_values = view_dict<dict_t, value_iterator_t<dict_t, base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using view_dict_items = view_dict<dict_t, item_iterator_t<dict_t, base_iterator_t, reference_t>>;
    """
    cdef cppclass key_iterator_t[dict_t, base_iterator_t, reference_t]:
        key_iterator_t()
        key_iterator_t(base_iterator_t)
        key_iterator_t(base_iterator_t, dict_t)
        reference_t operator*()
        key_iterator_t operator++()
        bint operator!=(key_iterator_t)

    cdef cppclass value_iterator_t[dict_t, base_iterator_t, reference_t]:
        value_iterator_t()
        value_iterator_t(base_iterator_t)
        value_iterator_t(base_iterator_t, dict_t)
        reference_t operator*()
        value_iterator_t operator++()
        bint operator!=(value_iterator_t)

    cdef cppclass item_iterator_t[dict_t, base_iterator_t, reference_t]:
        item_iterator_t()
        item_iterator_t(base_iterator_t)
        item_iterator_t(base_iterator_t, dict_t)
        reference_t operator*()
        item_iterator_t operator++()
        bint operator!=(item_iterator_t)

    cdef cppclass view_dict_keys[dict_t, base_iterator_t, reference_t]:
        ctypedef key_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        view_dict_keys()
        view_dict_keys(dict_t)
        key_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()

    cdef cppclass view_dict_values[dict_t, base_iterator_t, reference_t]:
        ctypedef value_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        view_dict_values()
        view_dict_values(dict_t)
        value_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()

    cdef cppclass view_dict_items[dict_t, base_iterator_t, reference_t]:
        ctypedef item_iterator_t[dict_t, base_iterator_t, reference_t] iterator
        view_dict_items()
        view_dict_items(dict_t)
        item_iterator_t[dict_t, base_iterator_t, reference_t] begin()
        base_iterator_t end()


cdef cypclass cypdict[K, V]:
    ctypedef K key_type
    ctypedef V value_type
    ctypedef pair[key_type, value_type] item_type
    ctypedef vector[item_type].size_type size_type
    ctypedef key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type] iterator

    vector[item_type] _items
    unordered_map[key_type, size_type] _indices
    atomic[int] _active_iterators

    __init__(self):
        self._active_iterators.store(0)

    __dealloc__(self):
        for item in self._items:
            Cy_DECREF(item.first)
            Cy_DECREF(item.second)

    V __getitem__(self, const key_type key) except ~:
        it = self._indices.find(key)
        end = self._indices.end()
        if it != end:
           return self._items[dereference(it).second].second
        else:
            with gil:
                raise KeyError("Getting nonexistent item")

    void __setitem__(self, key_type key, value_type value) except ~:
        it = self._indices.find(key)
        end = self._indices.end()
        if it != end:
            Cy_INCREF(key)
            Cy_INCREF(value)
            index = dereference(it).second
            Cy_DECREF(self._items[index].first)
            Cy_DECREF(self._items[index].second)
            self._items[index].second = value
        elif self._active_iterators == 0:
            Cy_INCREF(key)
            Cy_INCREF(value)
            self._indices[key] = self._items.size()
            self._items.push_back(item_type(key, value))
        else:
            with gil:
                raise RuntimeError("Modifying a dictionary with active iterators")

    void __delitem__(self, key_type key) except ~:
        it = self._indices.find(key)
        end = self._indices.end()
        if it != end:
            index = dereference(it).second
            Cy_DECREF(self._items[index].first)
            Cy_DECREF(self._items[index].second)
            self._indices.erase(it)
            if index < self._items.size() - 1:
                self._items[index] = self._items[self._indices.size() - 1]
            self._items.pop_back()
        else:
            with gil:
                raise KeyError("Deleting nonexistent item")

    void clear(self) except ~:
        if self._active_iterators == 0:
            for item in self._items:
                Cy_DECREF(item.first)
                Cy_DECREF(item.second)
            self._items.clear()
            self._indices.clear()
        else:
            with gil:
                raise RuntimeError("Modifying a dictionary with active iterators")

    key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type] begin(self):
        return key_iterator_t[cypdict[K, V], vector[item_type].iterator, key_type](self._items.begin(), self)

    vector[item_type].iterator end(self):
        return self._items.end()

    size_type __len__(self):
        return self._items.size()

    bint __contains__(self, key_type key):
        return self._indices.count(key)

    view_dict_keys[cypdict[K, V], vector[item_type].iterator, key_type] keys(self):
        return view_dict_keys[cypdict[K, V], vector[item_type].iterator, key_type](self)

    view_dict_values[cypdict[K, V], vector[item_type].iterator, value_type] values(self):
        return view_dict_values[cypdict[K, V], vector[item_type].iterator, value_type](self)

    view_dict_items[cypdict[K, V], vector[item_type].iterator, item_type] items(self):
        return view_dict_items[cypdict[K, V], vector[item_type].iterator, item_type](self)
