# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A nolock:
    int val
    __init__(self, int a):
        self.val = a
    
    A __iadd__(self, A other):
        self.val += (other.val + 1)

cdef cypclass B(A) nolock:
    B __iadd__(self, A other):
        self.val += (other.val + 10)

    B __iadd__(self, B other):
        self.val += (other.val + 100)

def test_inplace_operator_inference():
    """
    >>> test_inplace_operator_inference()
    111
    """
    a = A(0)
    b0 = B(0)
    b1 = B(0)

    # at this point, the types are unambiguous and the following assignments should not cause them to infer as another type.

    a += b0 # should add 1

    # before it being fixed, 'b0 += a' where 'a' is of type A caused 'b0' to be inferred as type A instead of B.
    
    b0 += a # should add 10

    # since all cypclass methods are virtual, 'b0' being erroneously inferred as type A would cause 
    # 'b0 += b1' to call 'B __iadd__(self, A other)' instead of 'B __iadd__(self, B other)'.

    b0 += b1 # should add 100

    return b0.val
