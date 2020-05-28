# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A nolock:
    int a

    __init__(self, int a):
        self.a = a

    A foo(self, int other):
        return A(a + other)

cdef cypclass B(A) nolock:
    int b

    __init__(self, int b):
        self.b = 10 + b

    B foo(self, int other):
        return B(b + other)

def test_hide_override():
    """
    >>> test_hide_override()
    21
    """
    cdef B b1 = B(0)

    # This should not result in a 'ambiguous overloaded method' compilation error
    cdef B b2 = b1.foo(1)

    return b2.b