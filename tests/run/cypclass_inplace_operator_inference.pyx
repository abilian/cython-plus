# mode: run
# tag: cpp, cpp11
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A:
    int val
    __init__(self, int a):
        self.val = a

    A __iadd__(self, A other):
        self.val += (other.val + 1)

cdef cypclass B(A):
    B __iadd__(self, A other):
        self.val += (other.val + 10)

    int is_inferred_as_B(self):
        return 1

def test_inplace_operator_inference():
    """
    >>> test_inplace_operator_inference()
    (11, 1)
    """
    a = A(0)
    b = B(0)

    # at this point, the types are unambiguous and the following assignments should not cause them to infer as another type.

    a += b  # should add 1

    # before it being fixed, 'b += a' where 'a' is of type A caused 'b' to be inferred as type A instead of B.

    b += a  # should add 10

    # since all cypclass methods are virtual, 'b' being erroneously inferred as type A would cause a compilation error
    # when calling 'b.is_inferred_as_B()'.

    r = b.is_inferred_as_B()

    return b.val, r
