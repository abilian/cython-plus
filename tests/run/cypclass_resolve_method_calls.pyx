# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A:
    int foo(self, int a):
        return a + 42
 
cdef cypclass B(A):
    int foo(self, int a, int b):
        return a + b

def test_resolve_unhidden_method():
    """
    >>> test_resolve_unhidden_method()
    43
    """
    cdef B b = B()

    # should resolve to A.foo
    return b.foo(1)


cdef cypclass C:
    int a

    __init__(self, int a):
        self.a = a

    C foo(self, int other):
        return C(a + other)

cdef cypclass D(C):
    int b

    __init__(self, int b):
        self.b = 10 + b

    D foo(self, int other):
        return D(b + other)

def test_resolve_overriden_method():
    """
    >>> test_resolve_overriden_method()
    21
    """
    cdef D d1 = D(0)

    # should not resolve to D.foo
    cdef D d2 = d1.foo(1)

    return d2.b

cdef cypclass Left:
    int foo(self):
        return 1

cdef cypclass Right:
    int foo(self):
        return 2

cdef cypclass Derived(Left, Right):
    pass

def test_resolve_multiple_inherited_methods():
    """
    >>> test_resolve_multiple_inherited_methods()
    1
    """

    cdef Derived d = Derived()

    # should resolve to Left.foo
    cdef int r = d.foo()

    return r

cdef cypclass Top:
    int foo(self, int a, int b):
        return 1

cdef cypclass Middle(Top):
    int foo(self):
        return 2

cdef cypclass Bottom(Middle):
    int foo(self, int a):
        return a + 10

def test_inherited_overloaded_method():
    """
    >>> test_inherited_overloaded_method()
    2
    """

    cdef Bottom b = Bottom()

    # should resolve to Middle.foo
    cdef int r = b.foo()

    return r
