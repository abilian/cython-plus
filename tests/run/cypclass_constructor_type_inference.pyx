# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

cdef cypclass SomeMemory:
    void print_class(self) with gil:
        print "SomeMemory"

cdef cypclass SomeSubMemory(SomeMemory):
    void print_class(self) with gil:
        print "SomeSubMemory"

def test_constructor_type_inference():
    """
    >>> test_constructor_type_inference()
    SomeMemory
    SomeSubMemory
    """
    foo = SomeMemory()
    foo.print_class()
    bar = SomeSubMemory()
    bar.print_class()
