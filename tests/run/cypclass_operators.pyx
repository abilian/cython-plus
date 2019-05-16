# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass OverloadedOperators:
    int a

    __init__(self, int a):
        self.a = a

    OverloadedOperators __add__(self, OverloadedOperators other):
        return OverloadedOperators(self.a + other.a)

    OverloadedOperators __iadd__(self, OverloadedOperators other):
        self.a += other.a

    unsigned int __unsigned_int__(self):
        return <unsigned int> self.a

    int __int__(self):
        return self.a

    bint __bool__(self):
        return self.a < 0

cdef cypclass Wrapper:
    OverloadedOperators m

    void __init__(self, int a=0):
        self.m = OverloadedOperators(a)

    OverloadedOperators __OverloadedOperators__(self):
        return self.m

def test_overloaded_casts():
    """
    >>> test_overloaded_casts()
    -1
    4294967295
    True
    3
    False
    """
    cdef OverloadedOperators o = OverloadedOperators(-1)
    cdef Wrapper w = Wrapper(3)
    print str(<int> o) + '\n' + str(<unsigned int> o) + '\n' + str(<bint> o)\
        + '\n' + str(<int> <OverloadedOperators> w) + '\n' + str(<bint> <OverloadedOperators> w)

def test_overloaded_addition():
    """
    >>> test_overloaded_addition()
    True
    True
    True
    True
    True
    """
    cdef OverloadedOperators o1 = OverloadedOperators(2)
    cdef OverloadedOperators o2 = OverloadedOperators(3)
    cdef OverloadedOperators o1_second_ref = o1

    cdef OverloadedOperators o3 = o1 + o2
    o1 += o2
    print o3.a == o1.a
    print o3 is not o1
    print o3 is not o2
    print o1 is not o2
    print o1 is o1_second_ref