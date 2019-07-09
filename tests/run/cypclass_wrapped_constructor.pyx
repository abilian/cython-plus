# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Default:
    int a

def test_default():
    """
    >>> test_default()
    3
    """
    cdef Default o = Default()
    o.a = 3
    print o.a

cdef cypclass OverloadedConstructor:
    int a
    void __init__(self, int a):
        self.a = a
    void __init__(self, int a, int b):
        self.a = a*b

cdef cypclass Derived(OverloadedConstructor):
    __init__(self, int a, int b):
        self.a = a+b

def test_overloaded_constructor():
    """
    >>> test_overloaded_constructor()
    3
    14
    9
    """
    cdef OverloadedConstructor o1 = OverloadedConstructor(3)
    print o1.a

    cdef OverloadedConstructor o2 = OverloadedConstructor(2, 7)
    print o2.a

    cdef Derived o3 = Derived(2, 7)
    print o3.a

cdef cypclass OptionalArgsConstructor:
  int a
  void __init__(self, int a, int b=1, int c=0):
    this.a = a*b + c

def test_mandatory_only_arg_constructor():
    """
    >>> test_mandatory_only_arg_constructor()
    3
    """
    cdef OptionalArgsConstructor o = OptionalArgsConstructor(3)
    print o.a

def test_some_optional_arguments():
    """
    >>> test_some_optional_arguments()
    14
    """
    cdef OptionalArgsConstructor o = OptionalArgsConstructor(2, 7)
    print o.a

def test_all_optional_arguments():
    """
    >>> test_all_optional_arguments()
    15
    """
    cdef OptionalArgsConstructor o = OptionalArgsConstructor(2, 7, 1)
    print o.a
