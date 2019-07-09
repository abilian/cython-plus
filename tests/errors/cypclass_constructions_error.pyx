# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass UnknownNewOptionalArgs:
    """
    This will fail because the wrapper knows b (in __new__) is optional,
    but doesn't know its default value, so it cannot pass it to __init__
    """
    __init__(self, int a, double b, int c = 42):
        pass
    UnknownNewOptionalArgs __new__(alloc, int a, double b = 4.2, int c = 0):
        return alloc()

def test_new_unknown_optional_args():
    cdef UnknownNewOptionalArgs o = UnknownNewOptionalArgs(3, 2.1)

cdef cypclass VarArgsConstructor:
    __init__(self, int a, ...)

def test_varargs_constructor():
    cdef VarArgsConstructor o = VarArgsConstructor(1)

_ERRORS = u'''
10:4: Could not call this __init__ function because the corresponding __new__ wrapper isn't aware of default values
12:4: Wrapped __new__ is here (some args passed to __init__ could be at their default values)
19:13: Cypclass cannot handle variable arguments constructors, but you can use optional arguments (arg=some_value)
'''

