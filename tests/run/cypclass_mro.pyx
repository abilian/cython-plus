# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass LeftAdd:
    int __add__(self, int other):
        return 1

cdef cypclass RightAdd:
    int __add__(self, int other):
        return 0

cdef cypclass DerivedAdd(LeftAdd, RightAdd):
    pass

def test_binop_mro():
    """
    >>> test_binop_mro()
    (1, 1, 1)
    """

    d = DerivedAdd()
    cdef int r1 = d + 1

    cdef RightAdd r = DerivedAdd()
    cdef int r2 = r + 1

    cdef LeftAdd l = DerivedAdd()
    cdef int r3 = l + 1

    return (r1, r2, r3)


cdef cypclass BaseFoo:
    int foo(self):
        return 0

cdef cypclass InheritFoo(BaseFoo):
    pass

cdef cypclass OverrideFoo(BaseFoo):
    int foo(self):
        return 1

cdef cypclass MixinFoo(InheritFoo, OverrideFoo):
    pass

def test_mixin_mro():
    """
    >>> test_mixin_mro()
    (1, 1)
    """

    m = MixinFoo()
    cdef int r1 = m.foo()

    cdef InheritFoo i = MixinFoo()
    cdef int r2 = i.foo()

    return r1, r2


cdef cypclass LeftBar:
    int bar(self):
        return 1

cdef cypclass RightBar:
    int bar(self):
        return 0

cdef cypclass InheritBarTwice(LeftBar, RightBar):
    pass

def test_unrelated_mro():
    """
    >>> test_unrelated_mro()
    (1, 1, 1)
    """

    d = InheritBarTwice()
    cdef int r1 = d.bar()

    cdef RightBar r = InheritBarTwice()
    cdef int r2 = r.bar()

    cdef LeftBar l = InheritBarTwice()
    cdef int r3 = l.bar()

    return r1, r2, r3


cdef cypclass BaseStaticBaz:
    @staticmethod
    int baz():
        return 0

cdef cypclass InheritStaticBaz(BaseStaticBaz):
    pass

cdef cypclass OverloadStaticBaz(BaseStaticBaz):
    @staticmethod
    int baz():
        return 1

cdef cypclass MixinStaticBaz(InheritStaticBaz, OverloadStaticBaz):
    pass

def test_mixin_static_mro():
    """
    >>> test_mixin_static_mro()
    (1, 1)
    """

    m = MixinStaticBaz()
    cdef int r1 = m.baz()

    cdef InheritStaticBaz i = MixinStaticBaz()
    cdef int r2 = i.baz()

    return r1, r2


cdef cypclass LeftStaticFoobar:
    @staticmethod
    int foobar():
        return 1

cdef cypclass RightStaticFoobar:
    @staticmethod
    int foobar():
        return 0

cdef cypclass InheritStaticFoobarTwice(LeftStaticFoobar, RightStaticFoobar):
    pass

def test_unrelated_static_mro():
    """
    >>> test_unrelated_static_mro()
    (1, 1, 1)
    """

    d = InheritStaticFoobarTwice()
    cdef int r1 = d.foobar()

    cdef RightStaticFoobar r = InheritStaticFoobarTwice()
    cdef int r2 = r.foobar()

    cdef LeftStaticFoobar l = InheritStaticFoobarTwice()
    cdef int r3 = l.foobar()

    return r1, r2, r3