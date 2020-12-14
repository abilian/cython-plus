# tag: cpp
# mode: compile

cdef cypclass B:
    pass

cdef cypclass A[T]:
    T t
    B b
