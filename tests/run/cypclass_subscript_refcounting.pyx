# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcpp.vector cimport vector

cdef cypclass Value:
    __dealloc__(self) with gil:
        print("Value destroyed")

    int foo(self):
        return 0

def test_cpp_index_refcounting():
    """
    >>> test_cpp_index_refcounting()
    Value destroyed
    0
    """
    cdef vector[Value] vec
    vec.push_back(Value())
    a = vec[0]
    if Cy_GETREF(a) != 3:
        return -1
    return 0

cdef cypclass Vector[T]:
    vector[T] vec

    T __getitem__(self, int index):
        return vec[index]

def test_cyp_template_index_refcounting():
    """
    >>> test_cyp_template_index_refcounting()
    Value destroyed
    0
    """
    v = Vector[Value]()
    v.vec.push_back(Value())
    a = v[0]
    if Cy_GETREF(a) != 3:
        return -1
    return 0

cdef cypclass ValueVector:
    vector[Value] vec

    Value __getitem__(self, int index):
        return vec[index]

def test_cyp_index_refcounting():
    """
    >>> test_cyp_index_refcounting()
    Value destroyed
    0
    """
    v = ValueVector()
    v.vec.push_back(Value())
    a = v[0]
    if Cy_GETREF(a) != 3:
        return -1
    return 0

def test_call_on_cpp_index_refcounting():
    """
    >>> test_call_on_cpp_index_refcounting()
    Value destroyed
    0
    """
    cdef vector[Value] vec
    val = Value()
    vec.push_back(val)
    vec[0].foo()
    if Cy_GETREF(val) != 3:
        return -1
    return 0

def test_call_on_cyp_template_index_refcounting():
    """
    >>> test_call_on_cyp_template_index_refcounting()
    Value destroyed
    0
    """
    v = Vector[Value]()
    val = Value()
    v.vec.push_back(val)
    v[0].foo()
    if Cy_GETREF(val) != 3:
        return -1
    return 0

def test_call_on_cyp_index_refcounting():
    """
    >>> test_call_on_cyp_index_refcounting()
    Value destroyed
    0
    """
    v = ValueVector()
    val = Value()
    v.vec.push_back(val)
    v[0].foo()
    if Cy_GETREF(val) != 3:
        return -1
    return 0
