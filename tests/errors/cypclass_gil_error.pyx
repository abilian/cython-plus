# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

def GILHoldingFunction():
  pass

cdef class GILHoldingClass:
    pass

cdef GILHoldingClass gil_holding_object

cdef cypclass NoGILClass:
    return_type(self):
        pass

    void call(self):
        GILHoldingFunction()

    void access(self):
        o = gil_holding_object

_ERRORS = u'''
21:8: Assignment of Python object not allowed without gil
14:4: Function with Python return type cannot be declared nogil
18:26: Discarding owned Python object not allowed without gil
18:26: Calling gil-requiring function not allowed without gil
18:8: Accessing Python global or builtin not allowed without gil
18:26: Constructing Python tuple not allowed without gil
20:4: Function declared nogil has Python locals or temporaries
'''