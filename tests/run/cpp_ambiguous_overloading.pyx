# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cppclass A:
    int foo(int a = 0):
        # always return odd result
        return 2 * a + 1

    int foo(int* a):
        # always return even result
        if a:
            return 2 * a[0]
        return 0

def test_ambiguous_overloading():
    """
    >>> test_ambiguous_overloading()
    1
    """
    b = new A()

    # This turns into a C++ call to the first "foo" method with a NULL argument 
    # (no argument passed to a method with default-value parameter)
    # This "NULL" needs to be correctly cast, otherwise the call is ambiguous:
    # it could be the second "foo" method with a NULL pointer.
    # In that case the generated C++ would not compile.
    r = b.foo()

    # Check that the correct "foo" method was called and returned expected result.
    return r
