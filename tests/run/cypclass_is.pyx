# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass LeftBase:
    pass

cdef cypclass RightBase:
    pass

cdef cypclass Derived(LeftBase, RightBase):
    pass

def test_is_cypclass():
    """
    >>> test_is_cypclass()
    (True, True, True, True)
    """
    d = Derived()
    l = <LeftBase> d
    r = <RightBase> d

    return d is d, l is d, r is d, l is r

def test_is_cypclass_const():
    """
    >>> test_is_cypclass_const()
    (True, True, True, True)
    """
    cdef const Derived d = Derived()
    cdef const LeftBase l = <LeftBase> d
    cdef const RightBase r = <RightBase> d

    return d is d, l is d, r is d, l is r
