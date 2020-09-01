# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcythonplus.list cimport cyplist

cdef cypclass Value:
    int value
    __init__(self, int i):
        self.value = i

def test_append_and_comp_iteration():
    """
    >>> test_append_and_comp_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    l = cyplist[Value]()
    for i in range(10):
        l.append(Value(i))

    return [v.value for v in l]

def test_nogil_append_and_iteration():
    """
    >>> test_nogil_append_and_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    indices = []

    with nogil:
        l = cyplist[Value]()
        for i in range(10):
            l.append(Value(i))

        for v in l:
            with gil:
                indices.append(v.value)

    return indices

def test_nogil_insert_and_iteration():
    """
    >>> test_nogil_insert_and_iteration()
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    """
    indices = []

    with nogil:
        l = cyplist[Value]()
        for i in range(10):
            l.insert(0, Value(i))

        for v in l:
            with gil:
                indices.append(v.value)

    return indices

def test_len():
    """
    >>> test_len()
    0
    """
    l = cyplist[Value]()
    cdef long unsigned int nb_elements = 0
    for i in range(10):
        l.append(Value(i))
    for v in l:
        nb_elements += 1
    if l.__len__() != nb_elements:
        return -1
    if nb_elements != 10:
        return -2
    return 0

def test_clear():
    """
    >>> test_clear()
    0
    """
    l = cyplist[Value]()
    for i in range(10):
        l.append(Value(i))
    if l.__len__() != 10:
        return -1
    l.clear()
    if l.__len__() != 0:
        return -2
    return 0

def test_contains():
    """
    >>> test_clear()
    0
    """
    l = cyplist[Value]()
    for i in range(10):
        value = Value(i)
        if value in l:
            return -1
        l.append(value)
        if value not in l:
            return -2
    return 0

def test_add():
    """
    >>> test_add()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    l1 = cyplist[Value]()
    for i in range(5):
        l1.append(Value(i))
    l2 = cyplist[Value]()
    for i in range(5, 10):
        l2.append(Value(i))
    l = l1 + l2
    return [v.value for v in l]

def test_iadd():
    """
    >>> test_iadd()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    l1 = cyplist[Value]()
    for i in range(5):
        l1.append(Value(i))
    l2 = cyplist[Value]()
    for i in range(5, 10):
        l2.append(Value(i))
    l1 += l2
    return [v.value for v in l1]

def test_mul():
    """
    >>> test_mul()
    [0, 1, 0, 1, 0, 1]
    """
    l1 = cyplist[Value]()
    for i in range(2):
        l1.append(Value(i))
    l = l1 * 3
    return [v.value for v in l]

def test_imul():
    """
    >>> test_imul()
    [0, 1, 0, 1, 0, 1]
    """
    l = cyplist[Value]()
    for i in range(2):
        l.append(Value(i))
    l *= 3
    return [v.value for v in l]

def test_getitem_out_of_range():
    """
    >>> test_getitem_out_of_range()
    Getting list index out of range
    0
    """
    l = cyplist[Value]()
    try:
        with nogil:
            v = l[0]
            with gil:
                return -1
    except IndexError as e:
        print(e)
        return 0

def test_setitem_out_of_range():
    """
    >>> test_setitem_out_of_range()
    Setting list index out of range
    0
    """
    l = cyplist[Value]()
    try:
        with nogil:
            l[0] = Value(0)
            with gil:
                return -1
    except IndexError as e:
        print(e)
        return 0

def test_delitem_out_of_range():
    """
    >>> test_delitem_out_of_range()
    Deleting list index out of range
    0
    """
    l = cyplist[Value]()
    try:
        with nogil:
            del l[0]
            with gil:
                return -1
    except IndexError as e:
        print(e)
        return 0

def test_append_iterator_invalidation():
    """
    >>> test_append_iterator_invalidation()
    Modifying a list with active iterators
    0
    """
    l = cyplist[Value]()
    iterator = l.begin()
    try:
        with nogil:
            l.append(Value(1))
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_insert_iterator_invalidation():
    """
    >>> test_insert_iterator_invalidation()
    Modifying a list with active iterators
    0
    """
    l = cyplist[Value]()
    iterator = l.begin()
    try:
        with nogil:
            l.insert(0, Value(1))
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_del_iterator_invalidation():
    """
    >>> test_del_iterator_invalidation()
    Modifying a list with active iterators
    0
    """
    l = cyplist[Value]()
    l.append(Value(0))
    iterator = l.begin()
    try:
        with nogil:
            del l[0]
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_clear_iterator_invalidation():
    """
    >>> test_clear_iterator_invalidation()
    Modifying a list with active iterators
    0
    """
    l = cyplist[Value]()
    iterator = l.begin()
    try:
        with nogil:
            l.clear()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_modification_after_iteration():
    """
    >>> test_modification_after_iteration()
    0
    """
    l = cyplist[Value]()
    for value in l:
        pass
    try:
        with nogil:
            l.append(Value(1))
            l.insert(0, Value(0))
            del l[0]
            l.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return -1

def test_scalar_types_list():
    """
    >>> test_scalar_types_list()
    [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
    """
    l = cyplist[double]()
    for i in range(10):
        value = <double> i
        l.append(value)

    return [value for value in l]

cdef cypclass DestroyCheckValue(Value):
    __dealloc__(self) with gil:
        print("destroyed value", self.value)

def test_values_destroyed():
    """
    >>> test_values_destroyed()
    ('destroyed value', 0)
    ('destroyed value', 1)
    ('destroyed value', 2)
    ('destroyed value', 3)
    ('destroyed value', 4)
    ('destroyed value', 5)
    ('destroyed value', 6)
    ('destroyed value', 7)
    ('destroyed value', 8)
    ('destroyed value', 9)
    """
    l = cyplist[DestroyCheckValue]()
    for i in range(10):
        l.append(DestroyCheckValue(i))

def test_values_refcount():
    """
    >>> test_values_refcount()
    0
    """
    l = cyplist[Value]()
    value = Value()
    if Cy_GETREF(value) != 2:
        return -1
    l.append(value)
    if Cy_GETREF(value) != 3:
        return -2
    l.insert(0, value)
    if Cy_GETREF(value) != 4:
        return -3
    del l[0]
    if Cy_GETREF(value) != 3:
        return -4
    l.clear()
    if Cy_GETREF(value) != 2:
        return -5
    l.append(value)
    if Cy_GETREF(value) != 3:
        return -6
    del l
    if Cy_GETREF(value) != 2:
        return -7
    return 0

def test_iterator_refcount():
    """
    >>> test_iterator_refcount()
    0
    """
    l = cyplist[Value]()
    if Cy_GETREF(l) != 2:
        return -1

    def begin_iterator():
        it = l.begin()
        if Cy_GETREF(l) != 3:
            return -1
        return 0

    if begin_iterator():
        return -2

    if Cy_GETREF(l) != 2:
        return -3

    def end_iterator():
        it = l.end()
        if Cy_GETREF(l) != 2:
            return -1
        return 0

    if end_iterator():
        return -4

    if Cy_GETREF(l) != 2:
        return -5

    return 0

def test_concatenation_refcount():
    """
    >>> test_concatenation_refcount()
    0
    """
    value = Value(1)
    l1 = cyplist[Value]()

    if Cy_GETREF(value) != 2:
        return -1

    l1.append(value)
    if Cy_GETREF(value) != 3:
        return -2

    l2 = cyplist[Value]()
    l2.append(value)
    if Cy_GETREF(value) != 4:
        return -3

    l3 = l1 + l2
    if Cy_GETREF(value) != 6:
        return -4

    l3 += l1
    if Cy_GETREF(value) != 7:
        return -5

    l4 = l3 * 3
    if Cy_GETREF(value) != 16:
        return -6

    l4 *= 2
    if Cy_GETREF(value) != 25:
        return -7

    return 0
