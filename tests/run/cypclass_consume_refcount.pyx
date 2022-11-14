# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2


cdef cypclass Refcounted:
    __dealloc__(self) with gil:
        print("Refcounted destroyed")


def test_consume_name():
    """
    >>> test_consume_name()
    Refcounted destroyed
    0
    """
    r0 = Refcounted()
    if Cy_GETREF(r0) != 2:
        return -1

    cdef Refcounted r1 = consume r0
    if r0 is not NULL:
        return -2
    if Cy_GETREF(r1) != 2:
        return -3

    return 0

def test_consume_iso_name():
    """
    >>> test_consume_iso_name()
    Refcounted destroyed
    0
    """
    cdef iso Refcounted r0 = consume Refcounted()

    cdef Refcounted r1 = consume r0
    if r0 is not NULL:
        return -2
    if Cy_GETREF(r1) != 2:
        return -3

    return 0

def test_consume_and_drop_name():
    """
    >>> test_consume_and_drop_name()
    Refcounted destroyed
    consumed
    0
    """
    r = Refcounted()
    if Cy_GETREF(r) != 2:
        return -1

    consume r
    print("consumed")

    if r is not NULL:
        return -2

    return 0

def test_consume_constructed():
    """
    >>> test_consume_constructed()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume Refcounted()
    if Cy_GETREF(r) != 2:
        return -1

    return 0

def test_consume_iso_constructed():
    """
    >>> test_consume_iso_constructed()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume new Refcounted()
    if Cy_GETREF(r) != 2:
        return -1

    return 0

def test_consume_and_drop_constructed():
    """
    >>> test_consume_and_drop_constructed()
    Refcounted destroyed
    consumed
    0
    """
    consume Refcounted()
    print("consumed")

    return 0

cdef cypclass Origin:
    Refcounted field

    __init__(self):
        self.field = Refcounted()

cdef cypclass OriginIso:
    iso Refcounted field

    __init__(self):
        self.field = consume Refcounted()

def test_consume_field():
    """
    >>> test_consume_field()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume Origin().field
    if Cy_GETREF(r) != 2:
        return -1

    return 0

def test_consume_iso_field():
    """
    >>> test_consume_iso_field()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume OriginIso().field
    if Cy_GETREF(r) != 2:
        return -1

    return 0

def test_consume_and_drop_field():
    """
    >>> test_consume_and_drop_field()
    Refcounted destroyed
    consumed
    0
    """
    consume Origin().field
    print("consumed")

    return 0

def test_consume_cast_name():
    """
    >>> test_consume_cast_name()
    Refcounted destroyed
    0
    """
    r0 = Refcounted()
    if Cy_GETREF(r0) != 2:
        return -1

    cdef Refcounted r1 = consume <Refcounted> r0
    if r0 is not NULL:
        return -2
    if Cy_GETREF(r1) != 2:
        return -3

    return 0

def test_consume_cast_constructed():
    """
    >>> test_consume_cast_constructed()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume <Refcounted> Refcounted()
    if Cy_GETREF(r) != 2:
        return -1

    return 0

def test_consume_cast_field():
    """
    >>> test_consume_cast_field()
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume <Refcounted> Origin().field
    if Cy_GETREF(r) != 2:
        return -1

    return 0

cdef cypclass Convertible:
    Refcounted __Refcounted__(self):
        return Refcounted()
    __dealloc__(self) with gil:
        print("Convertible destroyed")

def test_consume_converted_name():
    """
    >>> test_consume_converted_name()
    Convertible destroyed
    Refcounted destroyed
    0
    """
    c = Convertible()
    if Cy_GETREF(c) != 2:
        return -1

    cdef Refcounted r = consume <Refcounted> c
    if c is NULL:
        return -2
    if Cy_GETREF(c) != 2:
        return -3
    if Cy_GETREF(r) != 2:
        return -4

    del c
    return 0

def test_consume_converted_constructed():
    """
    >>> test_consume_converted_constructed()
    Convertible destroyed
    Refcounted destroyed
    0
    """
    cdef Refcounted r = consume <Refcounted> Convertible()
    if Cy_GETREF(r) != 2:
        return -1

    return 0

cdef cypclass OriginConvertible:
    Convertible field

    __init__(self):
        self.field = Convertible()


def test_consume_converted_field():
    """
    >>> test_consume_converted_field()
    Convertible destroyed
    Refcounted destroyed
    0
    """
    o = OriginConvertible()
    if Cy_GETREF(o.field) != 2:
        return -1

    cdef Refcounted r = consume <Refcounted> o.field
    if o.field is NULL:
        return -2
    if Cy_GETREF(o.field) != 2:
        return -3
    if Cy_GETREF(r) != 2:
        return -4

    return 0
