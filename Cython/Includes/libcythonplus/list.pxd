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
    ctypedef list_iterator_t[cyplist[V], vector[value_type].iterator, value_type] iterator

    vector[value_type] _elements
    atomic[int] _active_iterators

    __init__(self):
        self._active_iterators.store(0)

    __dealloc__(self):
        for value in self._elements:
            Cy_DECREF(value)

    V __getitem__(self, const size_type index) except ~ const:
        if index < self._elements.size():
           return self._elements[index]
        else:
            with gil:
                raise IndexError("Getting list index out of range")

    void __setitem__(self, size_type index, const value_type value) except ~:
        if index < self._elements.size():
            Cy_INCREF(value)
            Cy_DECREF(self._elements[index])
            self._elements[index] = value
        else:
            with gil:
                raise IndexError("Setting list index out of range")

    void __delitem__(self, size_type index) except ~:
        if index < self._elements.size():
            if self._active_iterators == 0:
                it = self._elements.begin() + index
                Cy_DECREF(dereference(it))
                self._elements.erase(it)
            else:
                with gil:
                    raise RuntimeError("Modifying a list with active iterators")
        else:
            with gil:
                raise IndexError("Deleting list index out of range")

    void append(self, const value_type value) except ~:
        if self._active_iterators == 0:
            Cy_INCREF(value)
            self._elements.push_back(value)
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    void insert(self, size_type index, const value_type value) except ~:
        if self._active_iterators == 0:
            if index <= self._elements.size():
                it = self._elements.begin() + index
                Cy_INCREF(value)
                self._elements.insert(it, value)
            else:
                with gil:
                    raise IndexError("Inserting list index out of range")
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    void clear(self) except ~:
        if self._active_iterators == 0:
            for value in self._elements:
                Cy_DECREF(value)
            self._elements.clear()
        else:
            with gil:
                raise RuntimeError("Modifying a list with active iterators")

    list_iterator_t[cyplist[V], vector[value_type].iterator, value_type] begin(self) const:
        return list_iterator_t[cyplist[V], vector[value_type].iterator, value_type](self._elements.begin(), self)

    vector[value_type].iterator end(self) const:
        return self._elements.end()

    size_type __len__(self) const:
        return self._elements.size()

    bint __contains__(self, const value_type value):
        for v in self._elements:
            if value is v:
                return 1
        return 0
