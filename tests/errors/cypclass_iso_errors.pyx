# mode: error
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass A activable:
    pass

def test_name_aliasing():
    cdef iso A iso_a
    iso_a = consume A()

    # Aliasing to iso
    cdef iso A iso_b
    iso_b = iso_a

    cdef iso A iso_c
    iso_c = A()

    cdef iso A iso_d
    iso_d = activate(consume A())

    cdef iso A iso_e
    iso_e = <object> A()

    # Aliasing iso
    cdef iso A iso_f
    iso_f = iso_a

    cdef active A active_a
    active_a = iso_a

    cdef A ref_a
    ref_a = iso_a

    cdef object py_a
    py_a = iso_a


cdef cypclass Field:
    Field foo(self, Field other):
        return other

cdef cypclass Origin:
    Field field

    __init__(self):
        self.field = Field()

    Field bar(self, Field other):
        return other

def test_field_aliasing():
    cdef iso Origin o = consume Origin()
    cdef object py_field

    # OK - can pass consumed arguments
    o.bar(consume Field()).foo(consume Field())

    # ERR - aliasing field of iso to pyobject
    py_field = o.field

    # ERR - pyobject to field of iso
    o.field = py_field

    # ERR - aliasing field of iso
    field = o.field

    # ERR - consuming field of iso
    field2 = consume o.field

    # ERR - non_consumed argument
    o.bar(Field())

    # ERR - aliasing the returned reference
    c = o.bar(consume Field())


def test_typecast():
    cdef iso A iso_a
    iso_a = consume A()

    # Casting to iso
    cdef iso A iso_b
    iso_b = <iso A> A()

    cdef iso A iso_c
    iso_c = <iso A> activate(consume A())

    cdef iso A iso_d
    iso_d = <iso A> <object> A()

    # Casting from iso
    cdef active A active_a
    active_a = <active A> iso_a

    cdef A ref_a
    ref_a = <A> iso_a

    cdef object py_a
    py_a = <object> iso_a

    cdef iso A iso_e
    iso_e = <iso A> iso_a

    cdef iso A iso_f
    iso_f = consume <iso A> iso_a


_ERRORS = u'''
14:12: Cannot assign type 'iso A' to 'iso A'
17:13: Cannot assign type 'A' to 'iso A'
20:20: Cannot assign type 'active A' to 'iso A'
23:12: Cannot convert Python object to 'iso A'
27:12: Cannot assign type 'iso A' to 'iso A'
30:15: Cannot assign type 'iso A' to 'active A'
33:12: Cannot assign type 'iso A' to 'A'
36:11: Cannot convert 'iso A' to Python object
60:16: Cannot convert 'iso-> Field' to Python object
63:14: Cannot convert Python object to 'iso-> Field'
66:13: Cannot assign type 'iso-> Field' to 'iso-> Field'
72:15: Cannot assign type 'Field' to 'iso-> Field'
75:13: Cannot assign type 'iso-> Field' to 'iso-> Field'
84:12: Cannot assign type 'iso A' to 'iso A'
84:12: Cannot cast 'A' to 'iso A'
87:12: Cannot assign type 'iso A' to 'iso A'
87:12: Cannot cast 'active A' to 'iso A'
90:12: Cannot assign type 'iso A' to 'iso A'
94:15: Cannot cast 'iso A' to 'active A'
97:12: Cannot cast 'iso A' to 'A'
100:11: Cannot cast 'iso A' to 'Python object'
103:12: Cannot assign type 'iso A' to 'iso A'
'''
