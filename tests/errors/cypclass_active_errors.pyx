# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A activable:
    void f(self, A other):
        pass

    void f_iso(self, iso A other):
        pass

    void f_lock(self, lock A other):
        pass

    void f_active(self, active A other):
        pass


def test_aliasing():
    cdef active A active_a

    # Aliasing from active
    cdef iso A iso_a
    iso_a = active_a

    cdef lock A lock_a
    lock_a = active_a

    cdef A ref_a
    ref_a = active_a

    # Aliasing to active
    cdef active A active_b
    active_b = A()

    cdef active A active_c
    active_c = consume A()

    cdef active A active_d
    active_d = <lock A> consume A()


def test_calling():
    a = activate(consume A())

    a.f(NULL, A())

    a.f(NULL, consume A())

    cdef iso A iso_a
    a.f_iso(NULL, consume iso_a)

    cdef lock A lock_a
    a.f_lock(NULL, lock_a)

    cdef active A active_a
    a.f_active(NULL, active_a)


def test_typecast():
    cdef active A active_a

    # Casting from active
    cdef iso A iso_a
    iso_a = consume <iso A> active_a

    cdef lock A lock_a
    lock_a = <lock A> active_a

    cdef A ref_a
    ref_a = <A> active_a

    # Casting to active
    cdef active A active_b
    active_b = <active A> A()

    cdef active A active_c
    active_c = <active A> <iso A> consume A()

    cdef active A active_d
    active_d = <active A> <lock A> consume A()


_ERRORS = u'''
24:12: Cannot assign type 'active A' to 'iso A'
27:13: Cannot assign type 'active A' to 'lock A'
30:12: Cannot assign type 'active A' to 'A'
34:16: Cannot assign type 'A' to 'active A'
40:15: Cannot assign type 'lock A' to 'active A'
46:15: Cannot assign type 'A' to 'iso-> A'
65:20: Cannot cast 'active A' to 'iso A'
68:13: Cannot cast 'active A' to 'lock A'
71:12: Cannot cast 'active A' to 'A'
75:15: Cannot cast 'A' to 'active A'
78:15: Cannot cast 'iso A' to 'active A'
81:15: Cannot cast 'lock A' to 'active A'
'''
