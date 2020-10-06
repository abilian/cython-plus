from libcpp.unordered_set cimport unordered_set
from libcpp.atomic cimport atomic
from cython.operator cimport dereference
from cython.operator cimport postincrement

from libcythonplus.iterator cimport *

cdef extern from * nogil:
    """
    template<typename base_iterator_t, typename reference_t>
    constexpr reference_t set_value_getter_t(base_iterator_t iter)
    {
        return *iter;
    }

    template<typename set_t, typename base_iterator_t, typename reference_t>
    using set_iterator_t = cy_iterator_t<set_t, base_iterator_t, reference_t, set_value_getter_t<base_iterator_t, reference_t>>;
    """
    cdef cppclass set_iterator_t[set_t, base_iterator_t, reference_t]:
        set_iterator_t()
        set_iterator_t(base_iterator_t)
        set_iterator_t(base_iterator_t, const set_t)
        reference_t operator*()
        set_iterator_t operator++()
        bint operator!=(base_iterator_t)

cdef cypclass cypset[V]:
    ctypedef V value_type
    ctypedef size_t size_type
    ctypedef set_iterator_t[const cypset[V], unordered_set[value_type].const_iterator, value_type] iterator

    unordered_set[value_type] _elements
    mutable atomic[int] _active_iterators

    __init__(self):
        self._active_iterators.store(0)

    # set elementary operations

    void add(self, const value_type value) except ~:
        if self._active_iterators == 0:
            self._elements.insert(value)
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    void remove(self, const value_type value) except ~:
        if self._active_iterators == 0:
            if self._elements.erase(value) == 0:
                with gil:
                    raise KeyError("Element not in set")
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    void discard(self, const value_type value) except ~:
        if self._active_iterators == 0:
            self._elements.erase(value)
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    V pop(self) except ~:
        if self._active_iterators == 0:
            it = self._elements.begin()
            value = dereference(it)
            self._elements.erase(it)
            return value
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    void clear(self) except ~:
        if self._active_iterators == 0:
            self._elements.clear()
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    # inspection operations

    size_type __len__(const self):
        return self._elements.size()

    bint __contains__(const self, const value_type value):
        return self._elements.count(value)

    bint isdisjoint(const self, const cypset[V] other):
        cdef const cypset[V] smallest
        cdef const cypset[V] greatest
        if self._elements.size() < other._elements.size():
            smallest = self
            greatest = other
        else:
            smallest = other
            greatest = self
        for value in smallest._elements:
            if greatest._elements.count(value) > 0:
                return 0
        return 1

    # set comparisons

    bint __eq__(const self, const cypset[V] other):
        if self._elements.size() != other._elements.size():
            return 0
        for value in self._elements:
            if other._elements.count(value) == 0:
                return 0
        return 1

    bint __ne__(const self, const cypset[V] other):
        if self._elements.size() != other._elements.size():
            return 1
        for value in self._elements:
            if other._elements.count(value) == 0:
                return 1
        return 0

    bint __le__(const self, const cypset[V] other):
        if self._elements.size() > other._elements.size():
            return 0
        for value in self._elements:
            if other._elements.count(value) == 0:
                return 0
        return 1

    bint __lt__(const self, const cypset[V] other):
        return self <= other and self._elements.size() < other._elements.size()

    bint issubset(const self, const cypset[V] other):
        return self <= other

    bint __ge__(const self, const cypset[V] other):
        if self._elements.size() < other._elements.size():
            return 0
        for value in other._elements:
            if self._elements.count(value) == 0:
                return 0
        return 1

    bint __gt__(const self, const cypset[V] other):
        return self >= other and self._elements.size() > other._elements.size()

    bint issuperset(const self, const cypset[V] other):
        return self >= other


    # set non-modifying operations

    cypset[V] __or__(const self, const cypset[V] other):
        result = cypset[V]()
        result._elements.insert(self._elements.const_begin(), self._elements.const_end())
        result._elements.insert(other._elements.const_begin(), other._elements.const_end())
        return result

    cypset[V] union "set_union"(const self, const cypset[V] other):
        return self | other

    cypset[V] __and__(const self, const cypset[V] other):
        cdef const cypset[V] smallest
        cdef const cypset[V] greatest
        if self._elements.size() < other._elements.size():
            smallest = self
            greatest = other
        else:
            smallest = other
            greatest = self
        result = cypset[V]()
        for value in smallest._elements:
            if greatest._elements.count(value) > 0:
                result._elements.insert(value)
        return result

    cypset[V] intersection(const self, const cypset[V] other):
        return self & other

    cypset[V] __sub__(const self, const cypset[V] other):
        result = cypset[V]()
        for value in self._elements:
            if other._elements.count(value) == 0:
                result._elements.insert(value)
        return result

    cypset[V] difference(const self, const cypset[V] other):
        return self - other

    cypset[V] __xor__(const self, const cypset[V] other):
        result = cypset[V]()
        result._elements = other._elements
        for value in self._elements:
            it = result._elements.find(value)
            if it != result._elements.end():
                result._elements.erase(it)
            else:
                result._elements.insert(value)
        return result

    cypset[V] symmetric_difference(const self, const cypset[V] other):
        return self ^ other


    # set in-place (modifying) operations

    cypset[V] __ior__(self, const cypset[V] other) except ~:
        if self._active_iterators == 0:
            self._elements.insert(other._elements.const_begin(), other._elements.end())
            return self
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    cypset[V] update(self, const cypset[V] other) except ~:
        self |= other
        return self

    cypset[V] __iand__(self, const cypset[V] other) except ~:
        if self._active_iterators == 0:
            it = self._elements.begin()
            end = self._elements.end()
            while it != end:
                value = dereference(it)
                if other._elements.count(value) == 0:
                    it = self._elements.erase(it)
                else:
                    postincrement(it)
            return self
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    cypset[V] intersection_update(self, const cypset[V] other) except ~:
        self &= other
        return self

    cypset[V] __isub__(self, const cypset[V] other) except ~:
        if self._active_iterators == 0:
            for value in other._elements:
                self._elements.erase(value)
            return self
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    cypset[V] difference_update(self, const cypset[V] other) except ~:
        self -= other
        return self

    cypset[V] __ixor__(self, const cypset[V] other) except ~:
        if self._active_iterators == 0:
            for value in other._elements:
                if self._elements.erase(value) == 0:
                    self._elements.insert(value)
        else:
            with gil:
                raise RuntimeError("Modifying a set with active iterators")

    cypset[V] symmetric_difference_update(self, const cypset[V] other) except ~:
        self ^= other
        return self

    # iterators

    iterator begin(const self):
        return iterator(self._elements.const_begin(), self)

    unordered_set[value_type].const_iterator end(const self):
        return self._elements.const_end()
