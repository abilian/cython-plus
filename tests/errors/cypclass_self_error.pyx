# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass MethodsWithoutSelf:
    void declared()
    void defined():
        pass

_ERRORS = u'''
6:4: Cypclass methods must have a self argument
7:4: Cypclass methods must have a self argument
'''