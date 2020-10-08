# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcpp.vector cimport vector

cdef cypclass Value:
    __dealloc__(self) with gil:
        print("Value destroyed")

cdef cypclass Stack:
    vector[Value] vec
    void push(self, Value v):
        self.vec.push_back(v)
    Value pop(self) except NULL:
        if self.vec.size() > 0:
            value = self.vec.back()
            self.vec.pop_back()
            return value
        else:
            with gil:
                raise IndexError("Stack is empty")
    vector[Value].iterator begin(self):
        return vec.begin()
    vector[Value].iterator end(self):
        return vec.end()

def test_value_refcount():
    """
    >>> test_value_refcount()
    Value destroyed
    0
    """
    v = Value()
    s = Stack()
    if Cy_GETREF(v) != 2:
        return -1
    s.push(v)
    if Cy_GETREF(v) != 3:
        return -2
    s.push(v)
    if Cy_GETREF(v) != 4:
        return -3
    s.push(v)
    if Cy_GETREF(v) != 5:
        return -4
    v2 = s.pop()
    if Cy_GETREF(v) != 5:
        return -5
    del v2
    if Cy_GETREF(v) != 4:
        return -5
    v2 = s.pop()
    del v2
    if Cy_GETREF(v) != 3:
        return -6
    v2 = s.pop()
    if Cy_GETREF(v) != 3:
        return -7
    del v2
    if Cy_GETREF(v) != 2:
        return -8
    try:
        v2 = s.pop()
        return -9
    except IndexError as e:
        pass
    return 0

cdef Stack pass_along(Stack s):
    return s

def test_stack_refcount():
    """
    >>> test_stack_refcount()
    0
    """
    s = Stack()
    if Cy_GETREF(s) != 2:
        return -1

    for key in s:
        pass

    if Cy_GETREF(s) != 2:
        return -2

    for key in pass_along(s):
        pass

    if Cy_GETREF(s) != 2:
        return -3

    return 0

def test_loop_variable_refcount():
    """
    >>> test_loop_variable_refcount()
    Value destroyed
    0
    """
    s = Stack()
    s.push(Value())

    for val in s:
        refcnt = Cy_GETREF(val)
        if refcnt != 3:
            print(refcnt)
            return -1

    for val in s:
        refcnt = Cy_GETREF(val)
        if refcnt != 3:
            print(refcnt)
            return -1

    return 0
