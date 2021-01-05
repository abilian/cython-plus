# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass Error:
    locked Error prohibited_field_type

    locked Error forward_prohibited_return_type(self)

    locked Error prohibited_return_type(self):
        pass

cdef locked Error prohibited_global_variable


cdef cypclass A:
    void f(locked self):
        pass

    void g(self, locked A other):
        pass

    void h(self, A other):
        cdef locked A a


def test_aliasing():
    cdef locked A locked_a
    cdef lock A lock_a

    lock_a = locked_a

    locked_a = lock_a

    lock_a.f()

    A().g(locked_a)

    A().g(lock_a)


_ERRORS = u'''
6:4: 'locked' variables are only allowed inside a function
8:47: Function cannot return a 'locked' cypclass instance
10:39: Function cannot return a 'locked' cypclass instance
13:5: 'locked' variables are only allowed inside a function
33:15: Cannot assign type 'lock A' to 'locked A'
39:10: Cannot assign type 'lock A' to 'locked A'
'''
