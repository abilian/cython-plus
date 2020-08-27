from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from libcpp.vector cimport vector
from cython.operator cimport dereference

cdef extern from * nogil:
    """
    template<typename base_iterator_t, typename reference_t>
    struct key_iterator_t : base_iterator_t
    {
        using base = base_iterator_t;
        using reference = reference_t;

        key_iterator_t() = default;
        key_iterator_t(base const & b) : base{b} {}

        key_iterator_t operator++(int)
        {
            return static_cast<base&>(*this)++;
        }

        key_iterator_t & operator++()
        {
            ++static_cast<base&>(*this);
            return (*this);
        }

        reference operator*() const
        {
            return static_cast<base>(*this)->first;
        }
    };

    template<typename base_iterator_t, typename reference_t>
    struct value_iterator_t : base_iterator_t
    {
        using base = base_iterator_t;
        using reference = reference_t;

        value_iterator_t() = default;
        value_iterator_t(base const & b) : base{b} {}

        value_iterator_t operator++(int)
        {
            return static_cast<base&>(*this)++;
        }

        value_iterator_t & operator++()
        {
            ++static_cast<base&>(*this);
            return (*this);
        }

        reference operator*() const
        {
            return static_cast<base>(*this)->second;
        }
    };

    template<typename base_iterator_t, typename reference_t>
    struct item_iterator_t : base_iterator_t
    {
        using base = base_iterator_t;
        using reference = reference_t;

        item_iterator_t() = default;
        item_iterator_t(base const & b) : base{b} {}

        item_iterator_t operator++(int)
        {
            return static_cast<base&>(*this)++;
        }

        item_iterator_t & operator++()
        {
            ++static_cast<base&>(*this);
            return (*this);
        }

        reference operator*() const
        {
            return *static_cast<base>(*this);
        }
    };

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
            return std::begin(*urange);
        }

        iterator end() const
        {
            return std::end(*urange);
        }
    };

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using view_dict_keys = view_dict<dict_t, key_iterator_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using view_dict_values = view_dict<dict_t, value_iterator_t<base_iterator_t, reference_t>>;

    template<typename dict_t, typename base_iterator_t, typename reference_t>
    using view_dict_items = view_dict<dict_t, item_iterator_t<base_iterator_t, reference_t>>;
    """
    cdef cppclass key_iterator_t[base_iterator_t, reference_t]:
        key_iterator_t()
        key_iterator_t(base_iterator_t)
        reference_t operator*()
        key_iterator_t operator++()
        bint operator!=(key_iterator_t)

    cdef cppclass value_iterator_t[base_iterator_t, reference_t]:
        value_iterator_t()
        value_iterator_t(base_iterator_t)
        reference_t operator*()
        value_iterator_t operator++()
        bint operator!=(value_iterator_t)

    cdef cppclass item_iterator_t[base_iterator_t, reference_t]:
        item_iterator_t()
        item_iterator_t(base_iterator_t)
        reference_t operator*()
        item_iterator_t operator++()
        bint operator!=(item_iterator_t)

    cdef cppclass view_dict_keys[dict_t, base_iterator_t, reference_t]:
        view_dict_keys()
        view_dict_keys(dict_t)
        key_iterator_t[base_iterator_t, reference_t] begin()
        key_iterator_t[base_iterator_t, reference_t] end()

    cdef cppclass view_dict_values[dict_t, base_iterator_t, reference_t]:
        view_dict_values()
        view_dict_values(dict_t)
        value_iterator_t[base_iterator_t, reference_t] begin()
        value_iterator_t[base_iterator_t, reference_t] end()

    cdef cppclass view_dict_items[dict_t, base_iterator_t, reference_t]:
        view_dict_items()
        view_dict_items(dict_t)
        item_iterator_t[base_iterator_t, reference_t] begin()
        item_iterator_t[base_iterator_t, reference_t] end()


cdef cypclass cypdict[K, V]:
    ctypedef K key_type
    ctypedef V value_type
    ctypedef pair[key_type, value_type] item_type
    ctypedef vector[item_type].size_type size_type

    vector[item_type] _items
    unordered_map[key_type, size_type] _indices

    V __getitem__(self, const key_type key) except ~:
        it = self._indices.find(key)
        end = self._indices.end()
        if it != end:
           return self._items[dereference(it).second].second
        else:
            with gil:
                raise KeyError("Getting nonexistent item")

    void __setitem__(self, key_type key, value_type value):
        Cy_INCREF(key)
        Cy_INCREF(value)
        it = self._indices.find(key)
        end = self._indices.end()
        if it != end:
            index = dereference(it).second
            Cy_DECREF(self._items[index].first)
            Cy_DECREF(self._items[index].second)
            self._items[index].second = value
        else:
            self._indices[key] = self._items.size()
            self._items.push_back(item_type(key, value))

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

    key_iterator_t[vector[item_type].iterator, key_type] begin(self):
        return key_iterator_t[vector[item_type].iterator, key_type](self._items.begin())

    key_iterator_t[vector[item_type].iterator, key_type] end(self):
        return key_iterator_t[vector[item_type].iterator, key_type](self._items.end())

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
