#cython: language_level = 3
from libc.stdio cimport printf
"""
    GOAL: implement nogil option in cdef class (extension types)
    and native memory manager (refcount based) that does not
    depend on cpython's memory manager and that does not require GIL.
    
    HINT: look at C++ standard library (that works very nicely with Cython)

    Cython documentation if here: http://docs.cython.org/en/latest/
    
    Basic usage: http://docs.cython.org/en/latest/src/quickstart/build.html
    
    Tutorial: http://docs.cython.org/en/latest/src/tutorial/cython_tutorial.html
    
    Language: http://docs.cython.org/en/latest/src/userguide/language_basics.html
    
    Extension types: http://docs.cython.org/en/latest/src/userguide/extension_types.html
        
        Extension Types are the "pure cython" classes that I want to be able to
        use without depending on cpython GIL (and in essence runtime, memory manager, etc.)
        
    Cython memory allocation: http://docs.cython.org/en/latest/src/tutorial/memory_allocation.html
    
    Parallelism: http://docs.cython.org/en/latest/src/userguide/parallelism.html
    
        Explains how nogil is posisble in cython for anything that
        only relies on C libraries that are multi-threaded
"""



# cdef class SomeMemory:
cdef class SomeMemory nogil:
  """
  This is a cdef class which is also called
  a extensino type. It is a kind of C struct
  that also acts as a python object.
  
  We would like to be able to define "nogil"
  extension types:
  
  cdef class SomeMemory nogil:
  
  where all methods are "nogil" and memory
  allocation does not depend on python runtime
  """
  cdef double a;
  cdef double b;
    
  cdef void foo(self) nogil:
    """
    It is possible to define native C/Cython methods
    that release the GIL (cool...)
    """
    self.a = self.b
    
  cdef void foo1(self, int a) nogil:
    """
    It is possible to define native C/Cython methods
    that release the GIL (cool...)
    """
    self.a = a

  cdef void foo3(self) nogil:
    """
    It is possible to define native C/Cython methods
    that release the GIL (cool...)
    """
    pass
  # Not allowed to define pure Python function in the extension type with nogil option now
  # since we want this extension type is CPython free
  # def baz(self):
  #  """
  #  It is also possible to define standard python
  #  methods
  #  """
  #  pass
    
    
# cdef bar(): # it is currently impossible to release GIL
cdef int bar() nogil: # yet this is what we would like to
    """
    This is a pure "cython method" which we would like to
    be able to declare with nogil option but this requires
    to first introduce the concept of nogil in cdef class
    """
    cdef SomeMemory o = SomeMemory(42.0, 3.14) # for this we need class allocation to handle memory without libpython
    o.foo() # and we need method selection to be independent of libpython
    o.foo1(2)
    o.a = 1.0
    return 0
    
cpdef baz():
    """
    This method is both callable from python and pure "cython".
    It can call both cdef methods and usual python functions
    """
    bar()
    
    
# We call here a cpdef function, which calls a def function
# which then allocates cdef class SomeMemory
baz()
print("done")
