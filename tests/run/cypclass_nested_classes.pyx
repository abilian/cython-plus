# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A:
    int a

    cypclass B:
        int b
        __init__(self, int b):
            self.b = b

        int foo(self):
            return self.b

    B b

    __init__(self, int a, int b):
        self.a = a
        self.b = B(b)

    int foo(self):
        return self.a + self.b.foo()

def test_nested_classes():
    """
    >>> test_nested_classes()
    11
    """
    a = A(1, 10)
    return a.foo()
