# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcythonplus.set cimport cypset

cdef cypclass Value:
    int value
    __init__(self, int i):
        self.value = i

def test_add_and_comp_iteration():
    """
    >>> test_add_and_comp_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    s = cypset[Value]()
    for i in range(10):
        s.add(Value(i))

    values = [v.value for v in s]
    values.sort()
    return values

def test_nogil_add_and_iteration():
    """
    >>> test_nogil_add_and_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    values = []

    with nogil:
        s = cypset[Value]()
        for i in range(10):
            s.add(Value(i))

        for v in s:
            with gil:
                values.append(v.value)

    values.sort()
    return values

def test_pop():
    """
    >>> test_pop()
    0
    """
    s = cypset[Value]()
    value = Value(0)
    s.add(value)
    value2 = s.pop()
    if value is not value2:
        return -1
    if s.__len__() != 0:
        return -2
    return 0

def test_remove():
    """
    >>> test_remove()
    'Element not in set'
    0
    """
    s = cypset[Value]()
    value = Value(0)
    value2 = Value(1)
    s.add(value)
    s.add(value2)
    s.remove(value)
    if s.__len__() != 1:
        return -1
    try:
        s.remove(Value(1))
        return -2
    except KeyError as e:
        print(e)
    
    return 0

def test_discard():
    """
    >>> test_discard()
    0
    """
    s = cypset[Value]()
    value = Value(0)
    value2 = Value(1)
    s.add(value)
    s.add(value2)
    s.discard(value)
    if s.__len__() != 1:
        return -1
    try:
        s.discard(Value(1))
    except Exception as e:
        return -2
    if s.__len__() != 1:
        return -3
    
    return 0

def test_add_iterator_invalidation():
    """
    >>> test_add_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s = cypset[Value]()
    iterator = s.begin()
    try:
        with nogil:
            s.add(Value(1))
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_remove_iterator_invalidation():
    """
    >>> test_remove_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s = cypset[Value]()
    value = Value(0)
    s.add(value)
    iterator = s.begin()
    try:
        with nogil:
            s.remove(value)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_discard_iterator_invalidation():
    """
    >>> test_discard_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s = cypset[Value]()
    value = Value(0)
    s.add(value)
    iterator = s.begin()
    try:
        with nogil:
            s.discard(value)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_inplace_union_iterator_invalidation():
    """
    >>> test_inplace_union_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1 |= s2
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_inplace_intersection_iterator_invalidation():
    """
    >>> test_inplace_intersection_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1 &= s2
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_inplace_difference_iterator_invalidation():
    """
    >>> test_inplace_difference_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1 -= s2
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_inplace_symmetric_difference_iterator_invalidation():
    """
    >>> test_inplace_symmetric_difference_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1 ^= s2
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_update_iterator_invalidation():
    """
    >>> test_update_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1.update(s2)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_intersection_update_iterator_invalidation():
    """
    >>> test_intersection_update_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1.intersection_update(s2)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_difference_update_iterator_invalidation():
    """
    >>> test_difference_update_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1.difference_update(s2)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0

def test_symmetric_difference_update_iterator_invalidation():
    """
    >>> test_symmetric_difference_update_iterator_invalidation()
    Modifying a set with active iterators
    0
    """
    s1 = cypset[Value]()
    s1.add(Value(1))
    s2 = cypset[Value]()
    s2.add(Value(2))
    iterator = s1.begin()
    try:
        with nogil:
            s1.symmetric_difference_update(s2)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
    return 0


def test_len():
    """
    >>> test_len()
    0
    """
    s = cypset[Value]()
    cdef long unsigned int nb_elements = 0
    for i in range(10):
        s.add(Value(i))
    for v in s:
        nb_elements += 1
    if s.__len__() != nb_elements:
        return -1
    if nb_elements != 10:
        return -2
    return 0

def test_clear():
    """
    >>> test_clear()
    0
    """
    s = cypset[Value]()
    for i in range(10):
        s.add(Value(i))
    if s.__len__() != 10:
        return -1
    s.clear()
    if s.__len__() != 0:
        return -2
    return 0

def test_contains():
    """
    >>> test_contains()
    0
    """
    s = cypset[Value]()
    for i in range(10):
        value = Value(i)
        if value in s:
            return -1
        s.add(value)
        if value not in s:
            return -2
    return 0

def test_comparison_strict_subset():
    """
    >>> test_comparison_strict_subset()
    (0, 1, 1, 1, 0, 0, 0)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6
    s1 = cypset[int]()
    for i in range(5):
        s1.add(2*i)
    s2 = cypset[int]()
    for i in range(10):
        s2.add(i)
    r0 = s1 == s2
    r1 = s1 != s2
    r2 = s1 < s2
    r3 = s1 <= s2
    r4 = s1 > s2
    r5 = s1 >= s2
    r6 = s1.isdisjoint(s2)
    return (r0, r1, r2, r3, r4, r5, r6)

def test_comparison_strict_superset():
    """
    >>> test_comparison_strict_superset()
    (0, 1, 0, 0, 1, 1, 0)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6
    s1 = cypset[int]()
    for i in range(10):
        s1.add(i)
    s2 = cypset[int]()
    for i in range(5):
        s2.add(2*i)
    r0 = s1 == s2
    r1 = s1 != s2
    r2 = s1 < s2
    r3 = s1 <= s2
    r4 = s1 > s2
    r5 = s1 >= s2
    r6 = s1.isdisjoint(s2)
    return (r0, r1, r2, r3, r4, r5, r6)

def test_comparison_equal():
    """
    >>> test_comparison_equal()
    (1, 0, 0, 1, 0, 1, 0)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6
    s1 = cypset[int]()
    for i in range(5):
        s1.add(2*i)
    s2 = cypset[int]()
    for i in range(5):
        s2.add(2*i)
    r0 = s1 == s2
    r1 = s1 != s2
    r2 = s1 < s2
    r3 = s1 <= s2
    r4 = s1 > s2
    r5 = s1 >= s2
    r6 = s1.isdisjoint(s2)
    return (r0, r1, r2, r3, r4, r5, r6)

def test_comparison_disjoint():
    """
    >>> test_comparison_disjoint()
    (0, 1, 0, 0, 0, 0, 1)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6
    s1 = cypset[int]()
    for i in range(5):
        s1.add(2*i)
    s2 = cypset[int]()
    for i in range(5):
        s2.add(2*i+1)
    r0 = s1 == s2
    r1 = s1 != s2
    r2 = s1 < s2
    r3 = s1 <= s2
    r4 = s1 > s2
    r5 = s1 >= s2
    r6 = s1.isdisjoint(s2)
    return (r0, r1, r2, r3, r4, r5, r6)
    

cdef cypclass EqualValue(Value):
    bint __eq__(self, EqualValue other):
        return self.value == other.value
    int __hash__(self):
        return self.value

def test_comparison_custom_equal():
    """
    >>> test_comparison_custom_equal()
    (1, 0, 0, 1, 0, 1, 0)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6
    s1 = cypset[EqualValue]()
    for i in range(5):
        s1.add(EqualValue(2*i))
    s2 = cypset[EqualValue]()
    for i in range(5):
        s2.add(EqualValue(2*i))
    r0 = s1 == s2
    r1 = s1 != s2
    r2 = s1 < s2
    r3 = s1 <= s2
    r4 = s1 > s2
    r5 = s1 >= s2
    r6 = s1.isdisjoint(s2)
    return (r0, r1, r2, r3, r4, r5, r6)

def test_union():
    """
    >>> test_union()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    s1 = cypset[Value]()
    for i in range(5):
        s1.add(Value(2*i))
    s2 = cypset[Value]()
    for i in range(5):
        s2.add(Value(2*i + 1))
    set1 = s1 | s2
    set2 = s1.union(s2)
    if set1 != set2:
        return -1
    values1 = [v.value for v in set1]
    values2 = [v.value for v in set2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_intersection():
    """
    >>> test_intersection()
    [0, 6, 12]
    """
    s1 = cypset[EqualValue]()
    for i in range(9):
        s1.add(EqualValue(2*i))
    s2 = cypset[EqualValue]()
    for i in range(6):
        s2.add(EqualValue(3*i))
    set1 = s1 & s2
    set2 = s1.intersection(s2)
    if set1 != set2:
        return -1
    values1 = [v.value for v in set1]
    values2 = [v.value for v in set2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_difference():
    """
    >>> test_difference()
    [2, 4, 8, 10, 14, 16]
    """
    s1 = cypset[EqualValue]()
    for i in range(9):
        s1.add(EqualValue(2*i))
    s2 = cypset[EqualValue]()
    for i in range(6):
        s2.add(EqualValue(3*i))
    set1 = s1 - s2
    set2 = s1.difference(s2)
    if set1 != set2:
        return -1
    values1 = [v.value for v in set1]
    values2 = [v.value for v in set2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_symmetric_difference():
    """
    >>> test_symmetric_difference()
    [2, 3, 4, 8, 9, 10, 14, 15, 16]
    """
    s1 = cypset[EqualValue]()
    for i in range(9):
        s1.add(EqualValue(2*i))
    s2 = cypset[EqualValue]()
    for i in range(6):
        s2.add(EqualValue(3*i))
    set1 = s1 ^ s2
    set2 = s1.symmetric_difference(s2)
    if set1 != set2:
        return -1
    values1 = [v.value for v in set1]
    values2 = [v.value for v in set2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_inplace_union():
    """
    >>> test_inplace_union()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    s1 = cypset[EqualValue]()
    s2 = cypset[EqualValue]()
    for i in range(5):
        v = EqualValue(2*i)
        s1.add(v)
        s2.add(v)
    set_rhs = cypset[EqualValue]()
    for i in range(5):
        set_rhs.add(EqualValue(2*i + 1))
    s1 |= set_rhs
    s2.update(set_rhs)
    if s1 != s2:
        return -1
    values1 = [v.value for v in s1]
    values2 = [v.value for v in s2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_inplace_intersection():
    """
    >>> test_inplace_intersection()
    [0, 6, 12]
    """
    s1 = cypset[EqualValue]()
    s2 = cypset[EqualValue]()
    for i in range(9):
        v = EqualValue(2*i)
        s1.add(v)
        s2.add(v)
    set_rhs = cypset[EqualValue]()
    for i in range(6):
        set_rhs.add(EqualValue(3*i))
    s1 &= set_rhs
    s2.intersection_update(set_rhs)
    if s1 != s2:
        return -1
    values1 = [v.value for v in s1]
    values2 = [v.value for v in s2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_inplace_difference():
    """
    >>> test_inplace_difference()
    [2, 4, 8, 10, 14, 16]
    """
    s1 = cypset[EqualValue]()
    s2 = cypset[EqualValue]()
    for i in range(9):
        v = EqualValue(2*i)
        s1.add(v)
        s2.add(v)
    set_rhs = cypset[EqualValue]()
    for i in range(6):
        set_rhs.add(EqualValue(3*i))
    s1 -= set_rhs
    s2.difference_update(set_rhs)
    if s1 != s2:
        return -1
    values1 = [v.value for v in s1]
    values2 = [v.value for v in s2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1

def test_inplace_symmetric_difference():
    """
    >>> test_inplace_symmetric_difference()
    [2, 3, 4, 8, 9, 10, 14, 15, 16]
    """
    s1 = cypset[EqualValue]()
    s2 = cypset[EqualValue]()
    for i in range(9):
        v = EqualValue(2*i)
        s1.add(v)
        s2.add(v)
    set_rhs = cypset[EqualValue]()
    for i in range(6):
        set_rhs.add(EqualValue(3*i))
    s1 ^= set_rhs
    s2.symmetric_difference_update(set_rhs)
    if s1 != s2:
        return -1
    values1 = [v.value for v in s1]
    values2 = [v.value for v in s2]
    values1.sort()
    values2.sort()
    if values1 != values2:
        return -2
    return values1


def test_scalar_types_set():
    """
    >>> test_scalar_types_set()
    [0.0]
    """
    s = cypset[double]()
    s.add(0.0)

    return [value for value in s]


cdef cypclass DestroyCheckValue(Value):
    __dealloc__(self) with gil:
        print("destroyed value", self.value)

def test_values_destroyed():
    """
    >>> test_values_destroyed()
    ('destroyed value', 0)
    """
    s = cypset[DestroyCheckValue]()
    s.add(DestroyCheckValue(0))

def test_values_refcount():
    """
    >>> test_values_refcount()
    0
    """
    s = cypset[Value]()
    value = Value()
    if Cy_GETREF(value) != 2:
        return -1
    s.add(value)
    if Cy_GETREF(value) != 3:
        return -2
    s.remove(value)
    if Cy_GETREF(value) != 2:
        return -3
    s.add(value)
    s.discard(value)
    if Cy_GETREF(value) != 2:
        return -5
    s.add(value)
    if Cy_GETREF(value) != 3:
        return -6
    value2 = s.pop()
    if Cy_GETREF(value) != 3:
        return -7
    del value2
    if Cy_GETREF(value) != 2:
        return -7
    s.add(value)
    s.clear()
    if Cy_GETREF(value) != 2:
        return -8
    s.add(value)
    del s
    if Cy_GETREF(value) != 2:
        return -9
    return 0

def test_iterator_refcount():
    """
    >>> test_iterator_refcount()
    0
    """
    s = cypset[Value]()
    if Cy_GETREF(s) != 2:
        return -1

    def begin_iterator():
        it = s.begin()
        if Cy_GETREF(s) != 3:
            return -1
        return 0

    if begin_iterator():
        return -2

    if Cy_GETREF(s) != 2:
        return -3

    def end_iterator():
        it = s.end()
        if Cy_GETREF(s) != 2:
            return -1
        return 0

    if end_iterator():
        return -4

    if Cy_GETREF(s) != 2:
        return -5

    return 0
