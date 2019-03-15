# distutils: language = c++

#cdef extern from "unistd.h" nogil:
#    unsigned int sleep(unsigned int seconds)

cdef cppclass Rectangle nogil:
    int a

    void test():
        this.a += 3

    void test(int a):
        this.a += a

    void Rectangle(int a):
        this.a = a

    void Rectangle():
        this.a = 5

cdef cypclass Rectangle_wrapper(Rectangle):

    Rectangle_wrapper __iadd__(Rectangle_wrapper other):
        return this

    Rectangle_wrapper __le__(Rectangle_wrapper other):
        return other


cdef cypclass Carre(Rectangle_wrapper):
    int b

    void __dealloc__():
        pass

    void __init__(int a):
        Rectangle.__init__(a)

    void test():
        this.a += 5


cdef cypclass Truc(Rectangle_wrapper):
    Carre c

    void __init__(int a=1):
        # Rectangle.__init__() is always called
        this.c = Carre(a)

    void __dealloc__():
        del this.c

cdef cppclass SomeMemory(Truc) nogil:
    int d

cdef int tipo() nogil:
    cdef Carre c = Carre(32)
    cdef Truc truc = Truc()

    truc += c

    truc.c.Rectangle.test()
    #truc.c.test()

    return truc.c.a

def toto():
    print(tipo())
