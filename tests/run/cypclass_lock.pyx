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
    with rlocked container:
        contained = container.object
        with wlocked contained:
            argument_recursivity(contained, n)
            print contained.getter()

cdef Container global_container

cdef int non_const_aliasing(const A a):
    global global_container
    global_container = Container()
    global_container.object = a
    b = global_container.object
    with wlocked b:
        b.setter(42)
        return b.getter()

def test_non_const_aliasing():
    """
    >>> test_non_const_aliasing()
    42
    """
    a = A()
    with rlocked a:
        return non_const_aliasing(a)

cdef A global_a

cdef int non_const_global_aliasing(const A a):
    global global_a
    global_a = a
    b = global_a
    with wlocked b:
        b.setter(42)
        return b.getter()

def test_non_const_global_aliasing():
    """
    >>> test_non_const_global_aliasing()
    42
    """
    global global_a
    a = A()
    with rlocked a:
        return non_const_global_aliasing(a)
