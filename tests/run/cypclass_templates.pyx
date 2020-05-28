# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass TemplatedBase[T, U]:
    T a
    U b
    __init__(self, T a, U b):
        self.a = a
        self.b = b

    T first(self):
        return self.a

    U second(self):
        return self.b

cdef cypclass TemplatedDerived[T](TemplatedBase[T, T]):
    T c
    __init__(self, T a, T b, T c):
        TemplatedBase[T, T].__init__(self, a, b)
        self.c = c

    T third(self):
        return self.c

def test_base_same_type_construction():
    """
    >>> test_base_same_type_construction()
    1
    2
    """
    cdef TemplatedBase[int, int] o = TemplatedBase[int, int](1, 2)
    print o.first()
    print o.second()

def test_base_different_type_construction():
    """
    >>> test_base_different_type_construction()
    1
    2.3
    """
    cdef TemplatedBase[int, double] o = TemplatedBase[int, double](1, 2.3)
    print o.first()
    print o.second()

def test_base_new_keyword():
    """
    >>> test_base_new_keyword()
    1
    2.3
    """
    cdef TemplatedBase[int, double] o = new TemplatedBase[int, double]()
    o.__init__(1, 2.3)
    print o.first()
    print o.second()

# def test_derived_twoargs_construction():
#     """
#     >>> test_derived_twoargs_construction()
#     42
#     4
#     """
#     cdef TemplatedDerived[int] o = TemplatedDerived[int](42, 4)
#     print o.first()
#     print o.second()

def test_derived_threeargs_construction():
    """
    >>> test_derived_threeargs_construction()
    1
    2
    3
    """
    cdef TemplatedDerived[int] o = TemplatedDerived[int](1, 2, 3)
    print o.first()
    print o.second()
    print o.third()
