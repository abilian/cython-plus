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

    void f_locked_self(locked self):
        cdef lock A l = self


def test_aliasing():
    cdef lock A lock_a

    # Aliasing from lock
    cdef iso A iso_a
    iso_a = lock_a

    cdef active A active_a
    active_a = lock_a

    cdef locked A locked_a
    locked_a = lock_a

    cdef A ref_a
    ref_a = lock_a

    # Aliasing to lock
    cdef lock A lock_b
    lock_b = A()

    cdef lock A lock_c
    lock_c = consume A()

    cdef lock A lock_d
    lock_d = <lock A> consume A()

    cdef lock A lock_e
    cdef locked A locked_b
    lock_e = locked_b


def test_calling():
    cdef lock A a

    a.f(A())

    a.f(consume A())

    a.f_locked_self()

    cdef iso A iso_a
    a.f_iso(consume iso_a)

    cdef lock A lock_a
    a.f_lock(lock_a)

    cdef active A active_a
    a.f_active(active_a)


def test_typecast():
    cdef lock A lock_a

    # Casting from lock
    cdef iso A iso_a
    iso_a = consume <iso A> lock_a

    cdef active A active_a
    active_a = <active A> lock_a

    cdef locked A locked_a
    locked_a = <locked A> lock_a

    cdef A ref_a
    ref_a = <A> lock_a

    # Casting to lock
    cdef lock A lock_b
    lock_b = <lock A> A()

    cdef lock A lock_c
    lock_c = <lock A> <iso A> consume A()

    cdef lock A lock_d
    lock_d = <lock A> activate(consume A())

    cdef lock A lock_e
    cdef locked A locked_b
    lock_e = <lock A> locked_b


_ERRORS = u'''
27:12: Cannot assign type 'lock A' to 'iso A'
30:15: Cannot assign type 'lock A' to 'active A'
33:15: Cannot assign type 'lock A' to 'locked A'
36:12: Cannot assign type 'lock A' to 'A'
40:14: Cannot assign type 'A' to 'lock A'
56:9: Cannot assign type 'A' to 'lock-> A'
77:20: Cannot cast 'lock A' to 'iso A'
80:15: Cannot cast 'lock A' to 'active A'
83:15: Cannot cast 'lock A' to 'locked A'
86:12: Cannot cast 'lock A' to 'A'
90:13: Cannot cast 'A' to 'lock A'
93:13: Cannot cast 'iso A' to 'lock A'
96:13: Cannot cast 'active A' to 'lock A'
'''
