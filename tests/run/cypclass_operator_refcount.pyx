# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

from libc.stdio cimport printf

cdef cypclass Value:
    __dealloc__(self) with gil:
        print("Value destroyed")

cdef cypclass Arg:
    __dealloc__(self) with gil:
        print("Arg destroyed")

cdef cypclass Binop:
    Value __add__(self, Arg a):
        return Value()
    
def test_binop():
    """
    >>> test_binop()
    Arg destroyed
    Value destroyed
    """
    cdef Value r0
    with nogil:
        bin = Binop()
        r0 = bin + Arg()


cdef cypclass Cmp:
    Value __eq__(self, Arg a):
        return Value()

def test_cmp():
    """
    >>> test_cmp()
    Arg destroyed
    Value destroyed
    """
    cdef Value r0

    with nogil:
        cmp = Cmp()
        r0 = cmp == Arg()

    return


cdef cypclass InplaceOps:
    Value val

    InplaceOps __iadd__(self, Arg a):
        self.val = Value()

def test_inplace_ops():
    """
    >>> test_inplace_ops()
    Arg destroyed
    Value destroyed
    """
    cdef Value r0

    with nogil:
        iop = InplaceOps()
        iop += Arg()
        r0 = iop.val

    return


cdef cypclass Call:
    Value __call__(self):
        return Value()

    Value __call__(self, Arg a):
        return Value()

def test_call():
    """
    >>> test_call()
    Arg destroyed
    Value destroyed
    Value destroyed
    """
    cdef Value r0, r1

    with nogil:
        call = Call()
        r0 = call()
        r1 = call(Arg())

    return


cdef cypclass Index:
    __dealloc__(self) with gil:
        print("Index destroyed")

cdef cypclass Subscript:
    Value value
    Index index

    __init__(self):
        self.value = NULL
        self.index = NULL

    Value __getitem__(const self, Index index):
        if self.index is index:
            return value
        return NULL

    void __setitem__(self, Index index, Value value):
        self.index = index
        self.value = value

def test_subscript():
    """
    >>> test_subscript()
    Index destroyed
    Value destroyed
    """
    cdef Value r0

    with nogil:
        s = Subscript()
        index = Index()
        value = Value()
        s[index] = value

    return

cdef cypclass Unop:

    Value __pos__(self):
        return Value()

def test_unop():
    """
    >>> test_unop()
    Value destroyed
    """

    cdef Value r0

    with nogil:
        un = Unop()
        r0 = +un

    return

def test_typecast():
    """
    >>> test_typecast()
    Value destroyed
    """

    with nogil:
        r1 = <cyobject> Value()

    return