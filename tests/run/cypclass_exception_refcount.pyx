# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Refcounted:
    pass

cdef int raises(Refcounted r) except 0:
    raise Exception

def test_exception_refcount_cleanup():
    """
    >>> test_exception_refcount_cleanup()
    2
    """
    r = Refcounted()
    for i in range(50):
        try:
            raises(r)
        except:
            pass
    return Cy_GETREF(r)
