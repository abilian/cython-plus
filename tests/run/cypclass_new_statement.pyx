# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Nothing:
    pass

cdef cypclass Init:
    __init__(self) with gil:
        print "__init__ called"

cdef cypclass New:
    New __new__(alloc):
        obj = alloc()
        with gil:
            print "__new__ called"

def test_new_on_Nothing():
    """
    >>> test_new_on_Nothing()
    Nothing shouldn't shout with new
    """
    cdef Nothing o = new Nothing()
    print "Nothing shouldn't shout with new"

def test_normal_Nothing_allocation():
    """
    >>> test_normal_Nothing_allocation()
    Nothing shouldn't shout with constructor wrapper
    """
    cdef Nothing o = Nothing()
    print "Nothing shouldn't shout with constructor wrapper"

def test_new_on_Init():
    """
    >>> test_new_on_Init()
    Init shouldn't shout with new
    """
    cdef Init o = new Init()
    print "Init shouldn't shout with new"

def test_normal_Init_allocation():
    """
    >>> test_normal_Init_allocation()
    __init__ called
    Init should shout with constructor wrapper
    """
    cdef Init o = Init()
    print "Init should shout with constructor wrapper"

def test_new_on_New():
    """
    >>> test_new_on_New()
    New shouldn't shout with new
    """
    cdef New o = new New()
    print "New shouldn't shout with new"

def test_normal_New_allocation():
    """
    >>> test_normal_New_allocation()
    __new__ called
    New should shout with constructor wrapper
    """
    cdef New o = New()
    print "New should shout with constructor wrapper"
