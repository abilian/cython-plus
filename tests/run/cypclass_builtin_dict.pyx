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

def test_comp_iteration():
    """
    >>> test_comp_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [key.index for key in d]

def test_nogil_iteration():
    """
    >>> test_nogil_iteration()
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

def test_comp_keys_iteration():
    """
    >>> test_comp_keys_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [key.index for key in d.keys()]

def test_nogil_keys_iteration():
    """
    >>> test_nogil_keys_iteration()
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

def test_comp_values_iteration():
    """
    >>> test_comp_values_iteration()
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [value.value for value in d.values()]

def test_nogil_values_iteration():
    """
    >>> test_nogil_values_iteration()
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

def test_comp_items_iteration():
    """
    >>> test_comp_items_iteration()
    [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9)]
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)

    return [(key.index, value.value) for (key, value) in d.items()]

def test_nogil_items_iteration():
    """
    >>> test_nogil_items_iteration()
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

def test_getitem_exception():
    """
    >>> test_getitem_exception()
    'Getting nonexistent item'
    1
    """
    d = cypdict[Index, Value]()
    try:
        with nogil:
            v = d[Index()]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1

def test_delitem_exception():
    """
    >>> test_delitem_exception()
    'Deleting nonexistent item'
    1
    """
    d = cypdict[Index, Value]()
    try:
        with nogil:
            del d[Index()]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1

def test_setitem_exception_dict_iterator():
    """
    >>> test_setitem_exception_dict_iterator()
    Modifying a dictionary with active iterators
    1
    """
    d = cypdict[Index, Value]()
    iterator = d.begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return 1

def test_setitem_exception_dict_keys_iterator():
    """
    >>> test_setitem_exception_dict_keys_iterator()
    Modifying a dictionary with active iterators
    1
    """
    d = cypdict[Index, Value]()
    iterator = d.keys().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return 1

def test_setitem_exception_dict_values_iterator():
    """
    >>> test_setitem_exception_dict_values_iterator()
    Modifying a dictionary with active iterators
    1
    """
    d = cypdict[Index, Value]()
    iterator = d.values().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return 1

def test_setitem_exception_dict_items_iterator():
    """
    >>> test_setitem_exception_dict_items_iterator()
    Modifying a dictionary with active iterators
    1
    """
    d = cypdict[Index, Value]()
    iterator = d.items().begin()
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return 1

def test_setitem_after_dict_iterator():
    """
    >>> test_setitem_after_dict_iterator()
    1
    """
    d = cypdict[Index, Value]()
    for key in d:
        pass
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_after_dict_keys_iterator():
    """
    >>> test_setitem_after_dict_keys_iterator()
    1
    """
    d = cypdict[Index, Value]()
    for key in d.keys():
        pass
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_after_dict_values_iterator():
    """
    >>> test_setitem_after_dict_values_iterator()
    1
    """
    d = cypdict[Index, Value]()
    for value in d.values():
        pass
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 1
    except RuntimeError as e:
        print(e)
        return 0

def test_setitem_after_dict_items_iterator():
    """
    >>> test_setitem_after_dict_items_iterator()
    1
    """
    d = cypdict[Index, Value]()
    for item in d.items():
        pass
    try:
        with nogil:
            d[Index()] = Value()
            with gil:
                return 1
    except RuntimeError as e:
        print(e)
        return 0

def test_len():
    """
    >>> test_len()
    1
    """
    d = cypdict[Index, Value]()
    cdef long unsigned int nb_elements = 0
    for i in range(10):
        d[Index(i)] = Value(i)
    for k in d:
        nb_elements += 1
    if d.__len__() != nb_elements:
        return 0
    if nb_elements != 10:
        return 0
    return 1

def test_clear():
    """
    >>> test_clear()
    1
    """
    d = cypdict[Index, Value]()
    for i in range(10):
        d[Index(i)] = Value(i)
    if d.__len__() != 10:
        return -1
    d.clear()
    if d.__len__() != 0:
        return 0
    return 1

def test_clear_exception_dict_iterator():
    """
    >>> test_clear_exception_dict_iterator()
    Modifying a dictionary with active iterators
    1
    """
    d = cypdict[Index, Value]()
    iterator = d.begin()
    try:
        with nogil:
            d.clear()
            with gil:
                return 0
    except RuntimeError as e:
        print(e)
        return 1

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
    ('destroyed index', 0)
    ('destroyed value', 0)
    ('destroyed index', 1)
    ('destroyed value', 1)
    ('destroyed index', 2)
    ('destroyed value', 2)
    ('destroyed index', 3)
    ('destroyed value', 3)
    ('destroyed index', 4)
    ('destroyed value', 4)
    ('destroyed index', 5)
    ('destroyed value', 5)
    ('destroyed index', 6)
    ('destroyed value', 6)
    ('destroyed index', 7)
    ('destroyed value', 7)
    ('destroyed index', 8)
    ('destroyed value', 8)
    ('destroyed index', 9)
    ('destroyed value', 9)
    """
    d = cypdict[DestroyCheckIndex, DestroyCheckValue]()
    for i in range(10):
        d[DestroyCheckIndex(i)] = DestroyCheckValue(i)

def test_items_refcount():
    """
    >>> test_items_refcount()
    1
    """
    d = cypdict[Index, Value]()
    index = Index()
    value = Value()
    if Cy_GETREF(index) != 2:
        return 0
    if Cy_GETREF(value) != 2:
        return 0
    d[index] = value
    if Cy_GETREF(index) != 3:
        return 0
    if Cy_GETREF(value) != 3:
        return 0
    del d[index]
    if Cy_GETREF(index) != 2:
        return 0
    if Cy_GETREF(value) != 2:
        return 0
    d[index] = value
    if Cy_GETREF(index) != 3:
        return 0
    if Cy_GETREF(value) != 3:
        return 0
    d.clear()
    if Cy_GETREF(index) != 2:
        return 0
    if Cy_GETREF(value) != 2:
        return 0
    d[index] = value
    if Cy_GETREF(index) != 3:
        return 0
    if Cy_GETREF(value) != 3:
        return 0
    d = cypdict[Index, Value]()
    if Cy_GETREF(index) != 2:
        return 0
    if Cy_GETREF(value) != 2:
        return 0
    return 1

def test_update():
    """
    >>> test_update()
    1
    """
    d1 = cypdict[Index, Value]()
    d2 = cypdict[Index, Value]()
    d1[Index(1)] = Value(10)
    d1[Index(3)] = Value(30)
    d2[Index(4)] = Value(40)
    d2[Index(2)] = Value(20)
    d1.update(d2)
    if d1.__len__() != 4:
        return 0
    for key in d2:
        if not key in d1:
            return 0
        if d2[key] is not d1[key]:
            return 0
    return 1

def test_update_refcount():
    """
    >>> test_update_refcount()
    1
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
    if Cy_GETREF(index1) != 3:
        return 0
    if Cy_GETREF(value1) != 3:
        return 0
    if Cy_GETREF(index2) != 3:
        return 0
    if Cy_GETREF(value2) != 3:
        return 0
    if Cy_GETREF(index3) != 3:
        return 0
    if Cy_GETREF(value3) != 3:
        return 0
    d1.update(d2)
    if Cy_GETREF(index1) != 3:
        return 0
    if Cy_GETREF(value1) != 3:
        return 0
    if Cy_GETREF(index2) != 4:
        return 0
    if Cy_GETREF(value2) != 4:
        return 0
    if Cy_GETREF(index3) != 4:
        return 0
    if Cy_GETREF(value3) != 4:
        return 0
    del d2
    if Cy_GETREF(index1) != 3:
        return 0
    if Cy_GETREF(value1) != 3:
        return 0
    if Cy_GETREF(index2) != 3:
        return 0
    if Cy_GETREF(value2) != 3:
        return 0
    if Cy_GETREF(index3) != 3:
        return 0
    if Cy_GETREF(value3) != 3:
        return 0
    del d1
    if Cy_GETREF(index1) != 2:
        return 0
    if Cy_GETREF(value1) != 2:
        return 0
    if Cy_GETREF(index2) != 2:
        return 0
    if Cy_GETREF(value2) != 2:
        return 0
    if Cy_GETREF(index3) != 2:
        return 0
    if Cy_GETREF(value3) != 2:
        return 0
    return 1
