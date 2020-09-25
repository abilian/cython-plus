# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Binop:
    int __sub__(self, int a):
        return 0

    int __add__(self, int a):
        return 1

    int __mul__(self, int a):
        return 2

    int __mod__(self, int a):
        return 3

    int __and__(self, int a):
        return 4

    int __xor__(self, int a):
        return 5

    int __or__(self, int a):
        return 6
    
def test_binop():
    """
    >>> test_binop()
    (0, 1, 2, 3, 4, 5, 6)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6

    with nogil:
        bin = Binop()
        r0 = bin - 1
        r1 = bin + 1
        r2 = bin * 1
        r3 = bin % 1
        r4 = bin & 1
        r5 = bin ^ 1
        r6 = bin | 1

    return (r0, r1, r2, r3, r4, r5, r6)


cdef cypclass Cmp:
    int __eq__(self, int a):
        return 0

    int __ne__(self, int a):
        return 1

    int __lt__(self, int a):
        return 2

    int __gt__(self, int a):
        return 3

    int __le__(self, int a):
        return 4

    int __ge__(self, int a):
        return 5

    int __contains__(self, int a):
        return a

def test_cmp():
    """
    >>> test_cmp()
    (0, 1, 2, 3, 4, 5, 6, 0)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6, r7

    with nogil:
        cmp = Cmp()
        r0 = cmp == 1
        r1 = cmp != 1
        r2 = cmp < 1
        r3 = cmp > 1
        r4 = cmp <= 1
        r5 = cmp >= 1
        r6 = 6 in cmp
        r7 = 7 not in cmp

    return (r0, r1, r2, r3, r4, r5, r6, r7)


cdef cypclass InplaceOps:
    int val

    InplaceOps __isub__(self, int a):
        self.val = 0 + a

    InplaceOps __iadd__(self, int a):
        self.val = 1 + a

    InplaceOps __imul__(self, int a):
        self.val = 2 + a

    InplaceOps __imod__(self, int a):
        self.val = 3 + a

    InplaceOps __iand__(self, int a):
        self.val = 4 + a

    InplaceOps __ixor__(self, int a):
        self.val = 5 + a

    InplaceOps __ior__(self, int a):
        self.val = 6 + a

def test_inplace_ops():
    """
    >>> test_inplace_ops()
    (1, 2, 3, 4, 5, 6, 7)
    """
    cdef int r0, r1, r2, r3, r4, r5, r6

    with nogil:
        iop = InplaceOps()
        iop -= 1
        r0 = iop.val
        iop += 1
        r1 = iop.val
        iop *= 1
        r2 = iop.val
        iop %= 1
        r3 = iop.val
        iop &= 1
        r4 = iop.val
        iop ^= 1
        r5 = iop.val
        iop |= 1
        r6 = iop.val

    return (r0, r1, r2, r3, r4, r5, r6)


cdef cypclass Call:
    int __call__(self):
        return 1

    int __call__(self, int a):
        return a

def test_call():
    """
    >>> test_call()
    (1, 2, 3)
    """
    cdef int r0, r1, r2

    with nogil:
        call = Call()
        r0 = call()
        r1 = call(2)
        r2 = call(3)

    return (r0, r1, r2)


cdef cypclass Index:
    pass

cdef cypclass Value:
    pass

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
    1
    """

    cdef int r0

    with nogil:
        s = Subscript()
        index = Index()
        value = Value()
        s[index] = value
        r0 = s[index] is value

    return r0

cdef cypclass Unop:

    int __neg__(self):
        return 1

    int __pos__(self):
        return 2

    int __invert__(self):
        return 3

    int __bool__(self):
        return 1

def test_unop():
    """
    >>> test_unop()
    (1, 2, 3, 0)
    """

    cdef int r0, r1, r2, r3

    with nogil:
        un = Unop()
        r0 = -un
        r1 = +un
        r2 = ~un
        r3 = not un

    return r0, r1, r2, r3