# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Base:
    __dealloc__(self) with gil:
        print("Base destroyed")

cdef cypclass Derived(Base):
    __dealloc__(self) with gil:
        print("Derived destroyed")


def test_upcast_name():
    """
    >>> test_upcast_name()
    Derived destroyed
    Base destroyed
    0
    """
    d = Derived()

    b = <Base> d
    if Cy_GETREF(d) != 3:
        return -1

    del b
    if Cy_GETREF(d) != 2:
        return -2

    return 0

def test_upcast_and_drop_name():
    """
    >>> test_upcast_and_drop_name()
    Derived destroyed
    Base destroyed
    0
    """
    d = Derived()

    <Base> d
    if Cy_GETREF(d) != 2:
        return -1

    return 0

def test_upcast_constructed():
    """
    >>> test_upcast_constructed()
    Derived destroyed
    Base destroyed
    0
    """
    d = <Base> Derived()
    if Cy_GETREF(d) != 2:
        return -1

    return 0

def test_upcast_and_drop_constructed():
    """
    >>> test_upcast_and_drop_constructed()
    Derived destroyed
    Base destroyed
    0
    """
    <Base> Derived()

    return 0


def test_downcast_name():
    """
    >>> test_downcast_name()
    Derived destroyed
    Base destroyed
    0
    """
    b = <Base> Derived()

    d = <Derived> b
    if Cy_GETREF(b) != 3:
        return -1

    del b
    if Cy_GETREF(d) != 2:
        return -2

    return 0

def test_downcast_and_drop_name():
    """
    >>> test_downcast_and_drop_name()
    Derived destroyed
    Base destroyed
    0
    """
    b = <Base> Derived()

    <Derived> b
    if Cy_GETREF(b) != 2:
        return -1

    return 0

def test_downcast_constructed():
    """
    >>> test_downcast_constructed()
    Derived destroyed
    Base destroyed
    0
    """
    d = <Derived> <Base> Derived()
    if Cy_GETREF(d) != 2:
        return -1

    return 0

def test_downcast_and_drop_constructed():
    """
    >>> test_downcast_and_drop_constructed()
    Derived destroyed
    Base destroyed
    0
    """
    <Derived> <Base> Derived()

    return 0

def test_failed_downcast():
    """
    >>> test_failed_downcast()
    Base destroyed
    0
    """
    d = <Derived> Base()
    if d is not NULL:
        return -1

    return 0


cdef cypclass Convertible:
    Derived __Derived__(self) with gil:
        print("Convertible -> Derived")
        return Derived()
    __dealloc__(self) with gil:
        print("Convertible destroyed")

def test_convert_name():
    """
    >>> test_convert_name()
    Convertible -> Derived
    Convertible destroyed
    Derived destroyed
    Base destroyed
    0
    """
    c = Convertible()

    d = <Derived> c
    if Cy_GETREF(c) != 2:
        return -1
    if Cy_GETREF(d) != 2:
        return -2

    del c
    return 0

def test_convert_and_drop_name():
    """
    >>> test_convert_and_drop_name()
    Convertible -> Derived
    Derived destroyed
    Base destroyed
    converted
    Convertible destroyed
    0
    """
    c = Convertible()

    <Derived> c
    print("converted")
    if Cy_GETREF(c) != 2:
        return -1

    return 0

def test_convert_constructed():
    """
    >>> test_convert_constructed()
    Convertible -> Derived
    Convertible destroyed
    converted
    Derived destroyed
    Base destroyed
    0
    """
    d = <Derived> Convertible()
    print("converted")
    if Cy_GETREF(d) != 2:
        return -1

    return 0

def test_convert_and_drop_constructed():
    """
    >>> test_convert_and_drop_constructed()
    Convertible -> Derived
    Convertible destroyed
    Derived destroyed
    Base destroyed
    converted
    0
    """
    <Derived> Convertible()
    print("converted")

    return 0


cdef cypclass DerivedConvertible(Base):
    Base __Base__(self) with gil:
        print("DerivedConvertible -> Base")
        return Base()

    __dealloc__(self) with gil:
        print("DerivedConvertible destroyed")

def test_overloaded_upcast():
    """
    >>> test_overloaded_upcast()
    DerivedConvertible -> Base
    converted
    DerivedConvertible destroyed
    Base destroyed
    Base destroyed
    0
    """
    d = DerivedConvertible()

    b = <Base> d
    print("converted")
    if Cy_GETREF(d) != 2:
        return -1
    if Cy_GETREF(b) != 2:
        return -2

    del d
    return 0


cdef cypclass BaseConvertible

cdef cypclass DerivedConverted(BaseConvertible):
    __dealloc__(self) with gil:
        print("DerivedConverted destroyed")

cdef cypclass BaseConvertible:
    DerivedConverted __DerivedConverted__(self) with gil:
        print("BaseConvertible -> DerivedConverted")
        return DerivedConverted()

    __dealloc__(self) with gil:
        print("BaseConvertible destroyed")

def test_overloaded_downcast():
    """
    >>> test_overloaded_downcast()
    BaseConvertible -> DerivedConverted
    converted
    BaseConvertible destroyed
    DerivedConverted destroyed
    BaseConvertible destroyed
    0
    """
    b = BaseConvertible()

    d = <DerivedConverted> b
    print("converted")
    if Cy_GETREF(d) != 2:
        return -1
    if Cy_GETREF(b) != 2:
        return -2

    del b
    return 0
