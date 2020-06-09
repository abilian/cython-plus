# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Base:
    int base
    __init__(self, int arg):
        self.base = arg

cdef cypclass InplaceAddition(Base):
    __init__(self, int arg):
        Base.__init__(self, arg)

    InplaceAddition __iadd__(self, InplaceAddition other):
        self.base += other.base

    void print_IA_base(self) with gil:
        print self.base

cdef cypclass InplaceSubstraction(Base):
    __init__(self, int arg):
        Base.__init__(self, arg)

    InplaceSubstraction __isub__(self, InplaceSubstraction other):
        self.base -= other.base

    void print_IS_base(self) with gil:
        print self.base

cdef cypclass Diamond(InplaceAddition, InplaceSubstraction):
    __init__(self, int a, int b):
        InplaceAddition.__init__(self, a)
        InplaceSubstraction.__init__(self, b)

# def test_non_virtual_inheritance():
#     """
#     >>> test_non_virtual_inheritance()
#     1
#     2
#     3
#     0
#     """
#     cdef Diamond diamond = Diamond(1, 2)
# 
#     diamond.print_IA_base()
#     diamond.print_IS_base()
# 
#     cdef InplaceAddition iadd_obj = InplaceAddition(2)
#     cdef InplaceSubstraction isub_obj = InplaceSubstraction(2)
# 
#     diamond += iadd_obj
#     diamond -= isub_obj
# 
#     diamond.print_IA_base()
#     diamond.print_IS_base()


def test_virtual_inheritance():
    """
    >>> test_virtual_inheritance()
    2
    2
    2
    2
    """
    cdef Diamond diamond = Diamond(1, 2)

    diamond.print_IA_base()
    diamond.print_IS_base()

    cdef InplaceAddition iadd_obj = InplaceAddition(2)
    cdef InplaceSubstraction isub_obj = InplaceSubstraction(2)

    diamond += iadd_obj
    diamond -= isub_obj

    diamond.print_IA_base()
    diamond.print_IS_base()
