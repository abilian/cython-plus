# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Refcounted:
    int index
    __init__(self, int index):
        self.index = index
    __dealloc__(self) with gil:
        print("destroyed: %d" % index)

cdef Refcounted global_array[10]

def test_global_array_init():
    """
    >>> test_global_array_init()
    0
    """
    for i in range(10):
        if global_array[i] is not NULL:
            return -(i+1)
    return 0

def test_local_array_init():
    """
    >>> test_local_array_init()
    0
    """
    cdef Refcounted local_array[10]
    for i in range(10):
        if local_array[i] is not NULL:
            return -(i+1)
    return 0

def test_global_array_refcount():
    """
    >>> test_global_array_refcount()
    destroyed: 0
    0
    """
    obj = Refcounted(0)
    if Cy_GETREF(obj) != 2:
        return -1
    for i in range(10):
        global_array[i] = obj
        if Cy_GETREF(obj) != 2 + i + 1:
            return -(i+2)
    for i in range(10):
        del global_array[i]
        if Cy_GETREF(obj) != 12 - i - 1:
            return -(i+12)
    if Cy_GETREF(obj) != 2:
        return -22
    return 0

def test_local_array_refcount():
    """
    >>> test_local_array_refcount()
    destroyed: 0
    0
    """
    cdef Refcounted local_array[10]
    obj = Refcounted(0)
    if Cy_GETREF(obj) != 2:
        return -1
    for i in range(10):
        local_array[i] = obj
        if Cy_GETREF(obj) != 2 + i + 1:
            return -(i+2)
    for i in range(10):
        del local_array[i]
        if Cy_GETREF(obj) != 12 - i - 1:
            return -(i+12)
    if Cy_GETREF(obj) != 2:
        return -22
    return 0

def test_local_array_destruction():
    """
    >>> test_local_array_destruction()
    destroyed: 0
    destroyed: 1
    destroyed: 2
    destroyed: 3
    destroyed: 4
    destroyed: 5
    destroyed: 6
    destroyed: 7
    destroyed: 8
    destroyed: 9
    """
    cdef Refcounted local_array[10]
    for i in range(10):
        local_array[i] = Refcounted(i)

def test_local_array_assignment_destruction():
    """
    >>> test_local_array_assignment_destruction()
    destroyed: 0
    destroyed: 1
    destroyed: 2
    destroyed: 3
    destroyed: 4
    destroyed: 5
    destroyed: 6
    destroyed: 7
    destroyed: 8
    destroyed: 9
    destroyed: 10
    destroyed: 11
    destroyed: 12
    destroyed: 13
    destroyed: 14
    destroyed: 15
    destroyed: 16
    destroyed: 17
    destroyed: 18
    destroyed: 19
    """
    cdef Refcounted local_array[10]
    cdef Refcounted local_array2[10]
    for i in range(10):
        local_array[i] = Refcounted(i)
    for i in range(10):
        local_array2[i] = Refcounted(i + 10)
    local_array = local_array2

cdef int test_array_as_argument(Refcounted* array, int size):
    obj = Refcounted(0)
    if Cy_GETREF(obj) != 2:
        return -1
    for i in range(size):
        array[i] = obj
        if Cy_GETREF(obj) != 2 + i + 1:
            return -(i+2)
    for i in range(10):
        del array[i]
        if Cy_GETREF(obj) != 12 - i - 1:
            return -(i+size+2)
    if Cy_GETREF(obj) != 2:
        return -(2*size+2)
    return 0

def test_array_argument_refcount():
    """
    >>> test_array_argument_refcount()
    destroyed: 0
    0
    """
    cdef Refcounted local_array[10]
    return test_array_as_argument(local_array, 10)
