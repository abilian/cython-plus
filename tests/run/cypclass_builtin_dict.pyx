# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcythonplus.dict cimport cypdict

cdef cypclass Value:
    int value
    __init__(self, int i):
        self.value = i

cdef cypclass Index:
    int index
    __init__(self, int i):
        self.index = i

def test_setitem_and_iteration():
    """
    >>> test_setitem_and_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [key.index for key in d]

def test_nogil_setitem_and_iteration():
    """
    >>> test_nogil_setitem_and_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    indices = []

    with nogil:
        d = cypdict[Index, Value]()
        for i in range(10):
            d[Index(i)] = Value(i)

        for key in d:
            with gil:
                indices.append(key.index)

    return indices

def test_setitem_and_keys_iteration():
    """
    >>> test_setitem_and_keys_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [key.index for key in d.keys()]

def test_nogil_setitem_and_keys_iteration():
    """
    >>> test_nogil_setitem_and_keys_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    indices = []

    with nogil:
        d = cypdict[Index, Value]()
        for i in range(10):
            d[Index(i)] = Value(i)

        for key in d.keys():
            with gil:
                indices.append(key.index)

    return indices

def test_setitem_and_values_iteration():
    """
    >>> test_setitem_and_values_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [value.value for value in d.values()]

def test_nogil_setitem_and_values_iteration():
    """
    >>> test_nogil_setitem_and_values_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    values = []

    with nogil:
        d = cypdict[Index, Value]()
        for i in range(10):
            d[Index(i)] = Value(i)

        for value in d.values():
            with gil:
                values.append(value.value)

    return values

def test_setitem_and_items_iteration():
    """
    >>> test_setitem_and_items_iteration()
    [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9)]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [(key.index, value.value) for (key, value) in d.items()]

def test_nogil_setitem_and_items_iteration():
    """
    >>> test_nogil_setitem_and_items_iteration()
    [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9)]
    """
    items = []

    with nogil:
        d = cypdict[Index, Value]()
        for i in range(10):
            d[Index(i)] = Value(i)

        for item in d.items():
            with gil:
                items.append((item.first.index, item.second.value))

    return items

def test_len():
    """
    >>> test_len()
    0
    """
    d = cypdict[Index, Value]()
    cdef long unsigned int nb_elements = 0
    for i in range(10):
        d[Index(i)] = Value(i)
    for k in d:
        nb_elements += 1
    if d.__len__() != nb_elements:
        return -1
    if nb_elements != 10:
        return -2
    return 0

def test_delitem():
    """
    >>> test_delitem()
    (1, 10)
    (2, 20)
    (3, 30)
    (4, 40)
    (5, 50)
    -------
    (1, 10)
    (2, 20)
    (5, 50)
    (4, 40)
    -------
    (4, 40)
    (2, 20)
    (5, 50)
    """
    d = cypdict[int, int]()
    for i in range(1, 7):
        d[i] = i * 10
    del d[6]
    for item in d.items():
        print(item)
    print("-------")
    del d[3]
    for item in d.items():
        print(item)
    print("-------")
    del d[1]
    for item in d.items():
        print(item)

def test_clear():
    """
    >>> test_clear()
    0
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)
    if d.__len__() != 10:
        return -1
    d.clear()
    if d.__len__() != 0:
        return -2
    return 0

def test_update():
    """
    >>> test_update()
    0
    """
    d1 = cypdict[Index, Value]()
    d2 = cypdict[Index, Value]()
    d1[Index(1)] = Value(10)
    d1[Index(3)] = Value(30)
    d2[Index(4)] = Value(40)
    d2[Index(2)] = Value(20)
    d1.update(d2)
    if d1.__len__() != 4:
        return -1
    for key in d2:
        if not key in d1:
            return -2
        if d2[key] is not d1[key]:
            return -3
    return 0

def test_contains():
    """
    >>> test_contains()
    0
    """
    d = cypdict[Index, double]()
    for i in range(10):
        index = Index(i)
        if index in d:
            return -1
        d[index] = <double> i
        if index not in d:
            return -2
    return 0

cdef cypclass EqualIndex(Index):
    bint __eq__(self, EqualIndex other):
        return self.index == other.index
    int __hash__(self):
        return self.index

cdef cypclass AlwaysEqualIndex(Index):
    bint __eq__(self, AlwaysEqualIndex other):
        return True
    int __hash__(self):
        return 0

def test_custom_eq_and_hash():
    """
    >>> test_custom_eq_and_hash()
    0
    """
    d1 = cypdict[EqualIndex, double]()
    d1[EqualIndex(0)] = 0.0
    if EqualIndex(0) not in d1:
        return -1
    if EqualIndex(1) in d1:
        return -2
    if d1.__len__() != 1:
        return -3
    d1[EqualIndex(0)] = 2.0
    if d1.__len__() != 1:
        return -4
    d1[EqualIndex(1)] = 1.0
    if d1.__len__() != 2:
        return -5

    d2 = cypdict[AlwaysEqualIndex, double]()
    d2[AlwaysEqualIndex(11)] = 11.0
    for i in range(10):
        index = AlwaysEqualIndex(i)
        if index not in d2:
            return -(i+6)
        d2[index] = <double> i
        if d2.__len__() != 1:
            return -(i+16)
    return 0

def test_nonexistent_getitem_exception():
    """
    >>> test_nonexistent_getitem_exception()
    'Getting nonexistent item'
    0
    """
    d = cypdict[Index, Value]()
    try:
        with nogil:
            v = d[Index()]
            with gil:
                return -1
    except KeyError as e:
        print(e)
        return 0

def test_nonexistent_delitem_exception():
    """
    >>> test_nonexistent_delitem_exception()
    'Deleting nonexistent item'
    0
    """
    d = cypdict[Index, Value]()
    try:
        with nogil:
            del d[Index()]
            with gil:
                return -1
    except KeyError as e:
        print(e)
        return 0

def test_setitem_iterator_invalidation():
    """
    >>> test_setitem_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    iterator = d.begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_keys_iterator_invalidation():
    """
    >>> test_setitem_keys_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    iterator = d.keys().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_values_iterator_invalidation():
    """
    >>> test_setitem_values_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    iterator = d.values().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_items_iterator_invalidation():
    """
    >>> test_setitem_items_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    iterator = d.items().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_delitem_iterator_invalidation():
    """
    >>> test_delitem_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    index = Index(0)
    d[index] = Value(0)
    iterator = d.begin()
    try:
        with nogil:
            del d[index]
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_clear_iterator_invalidation():
    """
    >>> test_clear_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    iterator = d.begin()
    try:
        with nogil:
            d.clear()
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_update_iterator_invalidation():
    """
    >>> test_update_iterator_invalidation()
    Modifying a dictionary with active iterators
    0
    """
    d = cypdict[Index, Value]()
    d2 = cypdict[Index, Value]()
    d2[Index(1)] = Value(1)
    iterator = d.begin()
    try:
        with nogil:
            d.update(d2)
            with gil:
                return -1
    except RuntimeError as e:
        print(e)
        return 0

def test_modification_after_dict_iterator():
    """
    >>> test_modification_after_dict_iterator()
    0
    """
    d = cypdict[Index, Value]()
    for key in d:
        pass
    try:
        with nogil:
            index = Index(0)
            d[index] = Value(0)
            del d[index]
            d.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return -1

def test_modification_after_dict_keys_iterator():
    """
    >>> test_modification_after_dict_keys_iterator()
    0
    """
    d = cypdict[Index, Value]()
    for key in d.keys():
        pass
    try:
        with nogil:
            index = Index(0)
            d[index] = Value(0)
            del d[index]
            d.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return -1

def test_modification_after_dict_values_iterator():
    """
    >>> test_modification_after_dict_values_iterator()
    0
    """
    d = cypdict[Index, Value]()
    for value in d.values():
        pass
    try:
        with nogil:
            index = Index(0)
            d[index] = Value(0)
            del d[index]
            d.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return -1

def test_modification_after_dict_items_iterator():
    """
    >>> test_modification_after_dict_items_iterator()
    0
    """
    d = cypdict[Index, Value]()
    for item in d.items():
        pass
    try:
        with nogil:
            index = Index(0)
            d[index] = Value(0)
            del d[index]
            d.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return -1

def test_scalar_types_dict():
    """
    >>> test_scalar_types_dict()
    [(0.0, 0), (1.0, 1), (2.0, 2), (3.0, 3), (4.0, 4), (5.0, 5), (6.0, 6), (7.0, 7), (8.0, 8), (9.0, 9)]
    """
    d = cypdict[double, int]()
    for i in range(10):
        index = <double> i
        d[index] = i

    return [(key, value) for (key, value) in d.items()]

cdef cypclass DestroyCheckIndex(Index):
    __dealloc__(self) with gil:
        print("destroyed index", self.index)

cdef cypclass DestroyCheckValue(Value):
    __dealloc__(self) with gil:
        print("destroyed value", self.value)

def test_items_destroyed():
    """
    >>> test_items_destroyed()
    ('destroyed value', 0)
    ('destroyed index', 0)
    ('destroyed value', 1)
    ('destroyed index', 1)
    ('destroyed value', 2)
    ('destroyed index', 2)
    ('destroyed value', 3)
    ('destroyed index', 3)
    ('destroyed value', 4)
    ('destroyed index', 4)
    ('destroyed value', 5)
    ('destroyed index', 5)
    ('destroyed value', 6)
    ('destroyed index', 6)
    ('destroyed value', 7)
    ('destroyed index', 7)
    ('destroyed value', 8)
    ('destroyed index', 8)
    ('destroyed value', 9)
    ('destroyed index', 9)
    """
    d = cypdict[DestroyCheckIndex, DestroyCheckValue]()
    for i in range(10):
        d[DestroyCheckIndex(i)] = DestroyCheckValue(i)

def test_items_refcount():
    """
    >>> test_items_refcount()
    0
    """
    d = cypdict[Index, Value]()
    index = Index()
    value = Value()
    if Cy_GETREF(index) != 2:
        return -1
    if Cy_GETREF(value) != 2:
        return -2
    d[index] = value
    if Cy_GETREF(index) != 4:
        return -3
    if Cy_GETREF(value) != 3:
        return -4
    del d[index]
    if Cy_GETREF(index) != 2:
        return -5
    if Cy_GETREF(value) != 2:
        return -6
    d[index] = value
    if Cy_GETREF(index) != 4:
        return -7
    if Cy_GETREF(value) != 3:
        return -8
    d.clear()
    if Cy_GETREF(index) != 2:
        return -9
    if Cy_GETREF(value) != 2:
        return -10
    d[index] = value
    if Cy_GETREF(index) != 4:
        return -11
    if Cy_GETREF(value) != 3:
        return -12
    d = cypdict[Index, Value]()
    if Cy_GETREF(index) != 2:
        return -13
    if Cy_GETREF(value) != 2:
        return -14
    return 0

def test_update_refcount():
    """
    >>> test_update_refcount()
    0
    """
    d1 = cypdict[Index, Value]()
    d2 = cypdict[Index, Value]()
    index1 = Index(1)
    value1 = Value(10)
    index2 = Index(2)
    value2 = Value(20)
    index3 = Index(3)
    value3 = Value(30)
    d1[index1] = value1
    d2[index2] = value2
    d2[index3] = value3
    if Cy_GETREF(index1) != 4:
        return -1
    if Cy_GETREF(value1) != 3:
        return -2
    if Cy_GETREF(index2) != 4:
        return -3
    if Cy_GETREF(value2) != 3:
        return -4
    if Cy_GETREF(index3) != 4:
        return -5
    if Cy_GETREF(value3) != 3:
        return -6
    d1.update(d2)
    if Cy_GETREF(index1) != 4:
        return -7
    if Cy_GETREF(value1) != 3:
        return -8
    if Cy_GETREF(index2) != 6:
        return -9
    if Cy_GETREF(value2) != 4:
        return -10
    if Cy_GETREF(index3) != 6:
        return -11
    if Cy_GETREF(value3) != 4:
        return -12
    del d2
    if Cy_GETREF(index1) != 4:
        return -13
    if Cy_GETREF(value1) != 3:
        return -14
    if Cy_GETREF(index2) != 4:
        return -15
    if Cy_GETREF(value2) != 3:
        return -16
    if Cy_GETREF(index3) != 4:
        return -17
    if Cy_GETREF(value3) != 3:
        return -18
    del d1
    if Cy_GETREF(index1) != 2:
        return -19
    if Cy_GETREF(value1) != 2:
        return -20
    if Cy_GETREF(index2) != 2:
        return -21
    if Cy_GETREF(value2) != 2:
        return -22
    if Cy_GETREF(index3) != 2:
        return -23
    if Cy_GETREF(value3) != 2:
        return -24
    return 0

def test_view_dict_refcount():
    """
    >>> test_view_dict_refcount()
    0
    """
    d = cypdict[Index, Value]()
    if Cy_GETREF(d) != 2:
        return -1

    def keys_view():
        key_view = d.keys()
        if Cy_GETREF(d) != 3:
            return -1
        return 0

    if keys_view():
        return -2

    if Cy_GETREF(d) != 2:
        return -3

    def values_view():
        values_view = d.values()
        if Cy_GETREF(d) != 3:
            return -1
        return 0

    if values_view():
        return -4

    if Cy_GETREF(d) != 2:
        return -5

    def items_view():
        items_view = d.items()
        if Cy_GETREF(d) != 3:
            return -1
        return 0

    if items_view():
        return -6

    if Cy_GETREF(d) != 2:
        return -7

    return 0

def test_iterator_refcount():
    """
    >>> test_iterator_refcount()
    0
    """
    d = cypdict[Index, Value]()
    if Cy_GETREF(d) != 2:
        return -1

    def begin_iterator():
        it = d.begin()
        if Cy_GETREF(d) != 3:
            return -1
        return 0

    if begin_iterator():
        return -2

    if Cy_GETREF(d) != 2:
        return -3

    def end_iterator():
        it = d.end()
        if Cy_GETREF(d) != 2:
            return -1
        return 0

    if end_iterator():
        return -4

    if Cy_GETREF(d) != 2:
        return -5

    def keys_begin_iterator():
        keys = d.keys()
        if Cy_GETREF(d) != 3:
            return -1
        it = keys.begin()
        if Cy_GETREF(d) != 4:
            return -2
        return 0

    if keys_begin_iterator():
        return -6

    if Cy_GETREF(d) != 2:
        return -7

    def values_begin_iterator():
        values = d.values()
        if Cy_GETREF(d) != 3:
            return -1
        it = values.begin()
        if Cy_GETREF(d) != 4:
            return -2
        return 0

    if values_begin_iterator():
        return -8

    if Cy_GETREF(d) != 2:
        return -9

    def items_begin_iterator():
        items = d.items()
        if Cy_GETREF(d) != 3:
            return -1
        it = items.begin()
        if Cy_GETREF(d) != 4:
            return -2
        return 0

    if items_begin_iterator():
        return -10

    if Cy_GETREF(d) != 2:
        return -11

    return 0

cdef cypdict[Index, Value] pass_along(cypdict[Index, Value] d):
    return d

def test_iteration_refcount():
    """
    >>> test_iteration_refcount()
    0
    """
    d = cypdict[Index, Value]()
    if Cy_GETREF(d) != 2:
        return -1

    for key in d:
        pass

    if Cy_GETREF(d) != 2:
        return -2

    for key in pass_along(d):
        pass

    if Cy_GETREF(d) != 2:
        return -3

    return 0
