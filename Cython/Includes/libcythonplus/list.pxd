from libcpp.vector cimport vector
from libcpp.atomic cimport atomic
from cython.operator cimport dereference

from libcythonplus.iterator cimport *

cdef extern from * nogil:
    """
    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t list_value_getter_t(base_iterator_t iter)
    {
        return *iter;
    }

    template<typename list_t, typename base_iterator_t, typename reference_t>
    using list_iterator_t = cy_iterator_t<list_t, base_iterator_t, reference_t, list_value_getter_t<base_iterator_t, reference_t>>;
    """
    cdef cppclass list_iterator_t[list_t, base_iterator_t, reference_t]:
        list_iterator_t()
        list_iterator_t(base_iterator_t)
        list_iterator_t(base_iterator_t, const list_t)
        reference_t operator*()
        list_iterator_t operator++()
        bint operator!=(base_iterator_t)

cdef cypclass cyplist[V]:
    ctypedef V value_type
    ctypedef vector[value_type].size_type size_type
    ctypedef list_iterator_t[const cyplist[V], vector[value_type].const_iterator, value_type] iterator

    vector[value_type] _elements
    mutable atomic[int] _active_iterators

    __init__(self):
        self._active_iterators.store(0)

    V __getitem__(const self, const size_type index) except ~:
        if index < self._elements.size():
           return self._elements[index]
        else:
            with gil:
                raise IndexError("Getting list index out of range")

    void __setitem__(self, size_type index, const value_type value) except ~:
        if index < self._elements.size():
            self._elements[index] = value
        else:
            with gil:
                raise IndexError("Setting list index out of range")

    void __delitem__(self, size_type index) except ~:
        if index < self._elements.size():
            if self._active_iterators == 0:
                it = self._elements.begin() + index
                self._elements.erase(it)
            else:
                with gil:
                    raise RuntimeError("Modifying a list with active iterators")
        else:
            with gil:
                raise IndexError("Deleting list index out of range")

    void append(self, const value_type value) except ~:
        if self._active_iterators == 0:
            self._elements.push_back(value)
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    void insert(self, size_type index, const value_type value) except ~:
        if self._active_iterators == 0:
            if index <= self._elements.size():
                it = self._elements.begin() + index
                self._elements.insert(it, value)
            else:
                with gil:
                    raise IndexError("Inserting list index out of range")
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    void clear(self) except ~:
        if self._active_iterators == 0:
            self._elements.clear()
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    cyplist[V] __add__(const self, const cyplist[V] other):
        result = cyplist[V]()
        result._elements.reserve(self._elements.size() + other._elements.size())
        result._elements.insert(result._elements.end(), self._elements.const_begin(), self._elements.const_end())
        result._elements.insert(result._elements.end(), other._elements.const_begin(), other._elements.const_end())
        return result

    cyplist[V] __iadd__(self, const cyplist[V] other):
        if self._active_iterators == 0:
            self._elements.insert(self._elements.end(), other._elements.const_begin(), other._elements.const_end())
            return self
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    cyplist[V] __mul__(const self, size_type n):
        result = cyplist[V]()
        result._elements.reserve(self._elements.size() * n)
        for i in range(n):
            result._elements.insert(result._elements.end(), self._elements.const_begin(), self._elements.const_end())
        return result

    cyplist[V] __imul__(self, size_type n):
        if self._active_iterators == 0:
            if n > 1:
                elements = self._elements
                self._elements.reserve(elements.size() * n)
                for i in range(1, n):
                    self._elements.insert(self._elements.end(), elements.begin(), elements.end())
                return self
            elif n == 1:
                return self
            else:
                self._elements.clear()
                return self
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    iterator begin(const self):
        return iterator(self._elements.const_begin(), self)

    vector[value_type].const_iterator end(const self):
        return self._elements.const_end()

    size_type __len__(const self):
        return self._elements.size()

    bint __contains__(const self, const value_type value):
        for v in self._elements:
            if value is v:
                return 1
        return 0
