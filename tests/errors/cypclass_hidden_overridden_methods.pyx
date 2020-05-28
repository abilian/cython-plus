# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A:
    void foo(self, int a):
        pass
    
cdef cypclass B(A):
    void foo(self, int a, int b):
        pass

def test_hidden_overridden_methods():
    cdef B b = B()

    # A.foo is hidden by B.foo, regardless of signature
    b.foo(1)

_ERRORS = u"""
17:9: Call with wrong number of arguments (expected 2, got 1)
"""