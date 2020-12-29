# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A activable:
    void f(self, A other):
        pass

    void f_iso(self, iso A other):
        pass

    void f_locked(self, locked A other):
        pass

    void f_active(self, active A other):
        pass


def test_aliasing():
    cdef active A active_a

    cdef iso A iso_a
    iso_a = active_a

    cdef locked A locked_a
    locked_a = active_a

    cdef A ref_a
    ref_a = active_a

def test_calling():
    a = activate(consume A())

    a.f(NULL, A())

    a.f(NULL, consume A())

    cdef iso A iso_a
    a.f_iso(NULL, consume iso_a)

    cdef locked A locked_a
    a.f_locked(NULL, locked_a)

    cdef active A active_a
    a.f_active(NULL, active_a)


_ERRORS = u'''
23:12: Cannot assign type 'active A' to 'iso A'
26:15: Cannot assign type 'active A' to 'locked A'
29:12: Cannot assign type 'active A' to 'A'
34:15: Cannot assign type 'A' to 'iso-> A'
'''
