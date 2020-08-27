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
    try:
        d = cypdict[Index, Value]()
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
    try:
        d = cypdict[Index, Value]()
        with nogil:
            del d[Index()]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1

