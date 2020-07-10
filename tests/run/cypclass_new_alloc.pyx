# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2


cdef cypclass Singleton

cdef int allocated = 0
cdef Singleton ptr

cdef cypclass Singleton:
    Singleton __new__(alloc):
        global allocated
        global ptr
        if not allocated:
            ptr = alloc()
            allocated = 1
        return ptr

def test_singleton():
    """
    >>> test_singleton()
    True
    """
    cdef Singleton s1 = Singleton()
    cdef Singleton s2 = Singleton()
    print s1 is s2

cdef cypclass Base:
    double value

    __init__(self, int a, double b):
        self.value = (<double> a)*b

    __init__(self, double b):
        self.value = b

    Base __new__(alloc, int a, double b):
        return alloc()

cdef cypclass Derived(Base):
    Derived __new__(alloc, double b):
        return alloc()

def test_changing_init_choice():
    """
    >>> test_changing_init_choice()
    6.0
    5.0
    """
    cdef Base base = Base(5, 1.2)
    cdef Derived derived = Derived(5)
    print base.value
    print derived.value

cdef cypclass NoisyConstruction:
    __init__(self) with gil:
        print "I'm a noisy constructor"

    NoisyConstruction __new__(alloc):
        return alloc()

def test_direct_new_call():
    """
    >>> test_direct_new_call()
    Noisy construction
    I'm a noisy constructor
    Silent direct __new__ call
    """
    print "Noisy construction"
    cdef NoisyConstruction obj1 = NoisyConstruction()
    print "Silent direct __new__ call"
    cdef NoisyConstruction obj2 = NoisyConstruction.__new__(NoisyConstruction.__alloc__)

cdef cypclass Multiply:
    int __new__(unused, int a, int b):
        return a*b

def test_non_class_return_new():
    """
    >>> test_non_class_return_new()
    6
    """
    cdef int obj = Multiply(2, 3)
    print obj

cdef cypclass SomeArgUnpacking:
  int a
  int b

  SomeArgUnpacking __new__(alloc, int a, int b = 31):
    return alloc()

  void __init__(self, int a = 0, int b = 32):
    self.a = a
    self.b = b

def test_new_args_unpacking():
    """
    >>> test_new_args_unpacking()
    1
    2
    1
    32
    """
    cdef SomeArgUnpacking obj1 = SomeArgUnpacking(1, 2)
    cdef SomeArgUnpacking obj2 = SomeArgUnpacking(1)
    print obj1.a
    print obj1.b
    print obj2.a
    print obj2.b
