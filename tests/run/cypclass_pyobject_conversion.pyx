# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

# import this module itself to access exactly what is exposed to Python
import cypclass_pyobject_conversion as lib

cdef cypclass Add:
    int val

    __init__(self, int val):
        self.val = val

    Add __add__(self, Add other):
        return Add(self.val + other.val)


def test_add_cypclass():
    """
    >>> test_add_cypclass()
    5
    """
    a = lib.Add(2) + lib.Add(3)
    return a.val


cdef cypclass Base:
    int base(self):
        return 0

cdef cypclass Left(Base):
    int left(self):
        return 1

cdef cypclass Right(Base):
    int right(self):
        return 2

cdef cypclass Diamond(Left, Right):
    int diamond(self):
        return 3


def test_diamond_inheritance():
    """
    >>> test_diamond_inheritance()
    (True, True, True, True, True)
    """
    base = lib.Base()
    left = lib.Left()
    right = lib.Right()
    diamond = lib.Diamond()

    r1 = isinstance(left, lib.Base)
    r2 = isinstance(right, lib.Base)
    r3 = isinstance(diamond, lib.Left)
    r4 = isinstance(diamond, lib.Right)
    r5 = isinstance(diamond, lib.Base)

    return (r1, r2, r3, r4, r5)


def test_diamond_inheritance_mro():
    """
    >>> test_diamond_inheritance_mro()
    True
    """
    diamond = lib.Diamond()

    mro = lib.Diamond.mro()

    return mro == [lib.Diamond, lib.Left, lib.Right, lib.Base, object]


def test_diamond_inheritance_methods():
    """
    >>> test_diamond_inheritance_methods()
    (0, 1, 2, 3)
    """
    diamond = lib.Diamond()

    r1 = diamond.base()
    r2 = diamond.left()
    r3 = diamond.right()
    r4 = diamond.diamond()

    return (r1, r2, r3, r4)


cdef cypclass HasAttribute:
    int value

    __init__(self, int value):
        self.value = value

def test_access_wrapper_attribute():
    """
    >>> test_access_wrapper_attribute()
    (1, 2, 5)
    """
    attr = lib.HasAttribute(1)
    first_value = attr.value

    attr.value = 2
    second_value = attr.value

    attr.value += 3
    third_value = attr.value

    return (first_value, second_value, third_value)


cdef cypclass Arg:
    int foo(self):
        return 1

cdef cypclass Caller:
    int f(self, Arg o):
        return o.foo()

def test_call_with_wrapped_argument():
    """
    >>> test_call_with_wrapped_argument()
    1
    """
    cdef Arg a = Arg()
    cdef Caller c = Caller()

    return c.f(a)


cdef cypclass Refcounted:
    void foo(self):
        pass

cdef object cyobject_to_pyobject(Refcounted r):
    return r

cdef Refcounted pyobject_to_cyobject(object o):
    return o

cdef void consume_cyobject(Refcounted r):
    pass

def consume_wrapped_cyobject(Refcounted r):
    pass

def wrapped_cyobject_to_pyobject(Refcounted r):
    return r

def consume_wrapped_cyobject_with_generic_args(Refcounted r, **kwargs):
    pass

def wrapped_cyobject_to_pyobject_with_generic_args(Refcounted r, dummy=2, unused="unused"):
    return r


def test_recfcount_round_trip_conversions():
    """
    >>> test_recfcount_round_trip_conversions()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        o = cyobject_to_pyobject(r)
        r = pyobject_to_cyobject(o)
        del o

    return Cy_GETREF(r)

def test_recfcount_consume_cyobject():
    """
    >>> test_recfcount_consume_cyobject()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        consume_cyobject(r)

    return Cy_GETREF(r)

def test_recfcount_consume_converted_cyobject():
    """
    >>> test_recfcount_consume_converted_cyobject()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        consume_cyobject(<object> r)

    return Cy_GETREF(r)

def test_recfcount_consume_wrapped_cyobject():
    """
    >>> test_recfcount_consume_wrapped_cyobject()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        consume_wrapped_cyobject(r)

    return Cy_GETREF(r)

def test_recfcount_convert_wrapped_cyobject():
    """
    >>> test_recfcount_convert_wrapped_cyobject()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        r = wrapped_cyobject_to_pyobject(r)

    return Cy_GETREF(r)

def test_recfcount_consume_wrapped_cyobject_with_generic_args():
    """
    >>> test_recfcount_consume_wrapped_cyobject_with_generic_args()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        consume_wrapped_cyobject_with_generic_args(r)

    return Cy_GETREF(r)

def test_recfcount_convert_wrapped_cyobject_with_generic_args():
    """
    >>> test_recfcount_convert_wrapped_cyobject_with_generic_args()
    2
    """
    cdef Refcounted r = Refcounted()

    for i in range(10):
        r = wrapped_cyobject_to_pyobject_with_generic_args(r)

    return Cy_GETREF(r)

def test_recfcount_wrapped_method_call():
    """
    >>> test_recfcount_wrapped_method_call()
    2
    """
    cdef Refcounted r = Refcounted()
    cdef object pyobj = r

    for i in range(10):
        pyobj.foo()

    del pyobj

    return Cy_GETREF(r)
