# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A checklock:
    int a
    int getter(self) const:
        return self.a
    void setter(self, int a):
        self.a = a

cdef void take_write_locked(A obj):
    pass

cdef int take_read_locked(const A obj):
    return 3

def incorrect_locks():
    obj = A()
    obj.a = 3
    obj.getter()
    with rlocked obj:
        obj.setter(42)
        take_write_locked(obj)
    obj.a
    take_read_locked(obj)

_ERRORS = u"""
20:4: This expression is not correctly locked (write lock needed)
21:4: This expression is not correctly locked (read lock needed)
23:8: This expression is not correctly locked (write lock needed)
24:26: This expression is not correctly locked (write lock needed)
25:4: This expression is not correctly locked (read lock needed)
26:21: This expression is not correctly locked (read lock needed)
"""
