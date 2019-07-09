# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A checklock:
    int a
    __init__(self):
        self.a = 0
    int getter(self) const:
        return self.a
    void setter(self, int a):
        self.a = a

def test_basic_locking():
    """
    >>> test_basic_locking()
    0
    """
    obj = A()
    with rlocked obj:
        print obj.getter()

cdef argument_recursivity(A obj, int arg):
    if arg > 0:
        obj.setter(obj.getter() + 1)
        argument_recursivity(obj, arg - 1)

def test_argument_recursivity(n):
    """
    >>> test_argument_recursivity(42)
    42
    """
    obj = A()
    with wlocked obj:
        argument_recursivity(obj, n)
        print obj.a

cdef A global_cyobject

cdef init_global_cyobject():
    global global_cyobject
    global_cyobject = A()

cdef void recursive_lock_taking(int arg):
    global global_cyobject
    if arg > 0:
        with wlocked global_cyobject:
            global_cyobject.setter(global_cyobject.getter() + 1)
            recursive_lock_taking(arg - 1)

def test_recursive_side_effect_locking(n):
    """
    >>> test_recursive_side_effect_locking(42)
    42
    """
    init_global_cyobject()
    recursive_lock_taking(42)
    with rlocked global_cyobject:
        print global_cyobject.getter()

cdef cypclass Container:
    A object
    __init__(self):
        self.object = A()

def test_lock_traversal(n):
    """
    >>> test_lock_traversal(42)
    42
    """
    container = Container()
    with rlocked container, wlocked container.object:
        argument_recursivity(container.object, n)
        print container.object.getter()
