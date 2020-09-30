# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Base:
    pass

cdef cypclass Derived(Base):
    pass

def test_insinstanceof():
    """
    >>> test_insinstanceof()
    (1, 1, 1, 0, 1, 1)
    """
    cdef Base base = Base()
    cdef Base derived_as_base = Derived()
    cdef Derived derived = Derived()

    cdef int r1 = isinstanceof[Base](base)
    cdef int r2 = isinstanceof[Base](derived_as_base)
    cdef int r3 = isinstanceof[Base](derived)

    cdef int r4 = isinstanceof[Derived](base)
    cdef int r5 = isinstanceof[Derived](derived_as_base)
    cdef int r6 = isinstanceof[Derived](derived)

    print(r1, r2, r3, r4, r5, r6)

def test_const_insinstanceof():
    """
    >>> test_const_insinstanceof()
    (1, 1, 1, 0, 1, 1)
    """
    cdef const Base base = Base()
    cdef const Base derived_as_base = Derived()
    cdef const Derived derived = Derived()

    cdef int r1 = isinstanceof[Base](base)
    cdef int r2 = isinstanceof[Base](derived_as_base)
    cdef int r3 = isinstanceof[Base](derived)

    cdef int r4 = isinstanceof[Derived](base)
    cdef int r5 = isinstanceof[Derived](derived_as_base)
    cdef int r6 = isinstanceof[Derived](derived)

    print(r1, r2, r3, r4, r5, r6)
