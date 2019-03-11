# distutils: language = c++

#cdef class biniou:
#    cdef int a
#
#cdef void genial(biniou arg):
#    o = arg.a
#    return

cdef extern from "unistd.h" nogil:
    unsigned int sleep(unsigned int seconds)

cdef cypclass Rectangle:
    int a
    void test():
        this.a += 3
    void test(int a):
        this.a += a
    void Rectangle(int a):
        this.a = a
    void Rectangle():
        this.a = 3
    Rectangle __iadd__(Rectangle other) nogil:
#        sleep(3)
        return this

    Rectangle __le__(Rectangle other) nogil:
        return other
#    void __dealloc__():
#        sleep(5)

cdef cypclass Carre(Rectangle):
    int b
    void __dealloc__():
        sleep(3)
    void __init__(int a):
        Rectangle.__init__(a)

cdef Rectangle retour() nogil:
    cdef Rectangle o = Rectangle(12)
    # o = Rectangle(12)
    return o

cdef void mange(Rectangle o) nogil:
    cdef int a = o.a
    return

cdef int tipo() nogil:
    #cdef Rectangle c
    cdef Rectangle o = Rectangle(32)
    #o = Rectangle(32)
    c = o
    c = Rectangle(3)
    c += o
    return c.a

def toto():
    print(tipo())

#cdef void Rectangle::test() nogil:
#    this.a += 3
#
#cdef void Rectangle::test(int a) nogil:
#    this.a += a
