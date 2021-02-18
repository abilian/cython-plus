# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Template[T]:
    T value

    __init__(self, T value):
        self.value = value

    __dealloc__(self) with gil:
        print("Template destroyed")

    void set(self, T value):
        self.value = value

    T get(self):
        return self.value

cdef cypclass Value:
    __dealloc__(self) with gil:
        print("Value destroyed")

def test_destruction():
    """
    >>> test_destruction()
    Template destroyed
    Value destroyed
    """
    h = Template[Value](Value())

def test_setting():
    """
    >>> test_setting()
    Value destroyed
    Template destroyed
    0
    """
    v = Value()
    if Cy_GETREF(v) != 2:
        return -1

    h = Template[Value](NULL)
    if Cy_GETREF(v) != 2:
        return -2

    h.set(v)
    if Cy_GETREF(v) != 3:
        return -3

    h.set(NULL)
    if Cy_GETREF(v) != 2:
        return -4

    return 0

def test_deleting():
    """
    >>> test_deleting()
    Template destroyed
    Value destroyed
    0
    """
    v = Value()
    if Cy_GETREF(v) != 2:
        return -1

    h = Template[Value](v)
    if Cy_GETREF(v) != 3:
        return -2

    del h
    if Cy_GETREF(v) != 2:
        return -3

    return 0

def test_getting():
    """
    >>> test_getting()
    Template destroyed
    Value destroyed
    0
    """
    h = Template[Value](Value())

    v1 = h.get()
    if Cy_GETREF(v1) != 3:
        return -1

    v2 = h.get()
    if Cy_GETREF(v1) != 4:
        return -2
    if Cy_GETREF(v2) != 4:
        return -3

    return 0

def test_getting_inspecting_setting():
    """
    >>> test_getting_inspecting_setting()
    Template destroyed
    Value destroyed
    0
    """
    h = Template[Value](Value())

    for i in range(10):
        v = h.get()
        if Cy_GETREF(v) != 3:
            return -(i+1)
        h.set(v)
    return 0

def test_getting_and_setting():
    """
    >>> test_getting_and_setting()
    Template destroyed
    Value destroyed
    0
    """
    v = Value()
    h = Template[Value](v)
    if Cy_GETREF(v) != 3:
        return -1

    for i in range(10):
        h.set(h.get())
        if Cy_GETREF(v) != 3:
            return -(i+2)
    return 0

def test_field_getting():
    """
    >>> test_field_getting()
    Template destroyed
    Value destroyed
    0
    """
    v = Value()
    h = Template[Value](v)
    if Cy_GETREF(v) != 3:
        return -1

    for i in range(10):
        v = h.value
        if Cy_GETREF(v) != 3:
            return -(i+2)
    return 0

def test_field_setting():
    """
    >>> test_field_setting()
    Template destroyed
    Value destroyed
    0
    """
    h = Template[Value](NULL)
    v = Value()

    for i in range(10):
        h.value = v
        if Cy_GETREF(v) != 3:
            return -(i+1)
    return 0

def test_field_deleting():
    """
    >>> test_field_deleting()
    Template destroyed
    Value destroyed
    0
    """
    v = Value()
    h = Template[Value](v)
    if Cy_GETREF(v) != 3:
        return -1

    del h.value
    if Cy_GETREF(v) != 2:
        return -1

    del h

    return 0
