# mode: run
# tag: cpp, cpp11

cdef int raises(int success) nogil except ~:
    if not success:
        with gil:
            raise ValueError("wrong value")
    else:
        return success

def test_caught_exception():
    """
    >>> test_caught_exception()
    1
    """
    cdef int r1
    try:
        with nogil:
            r1 = raises(0)
    except ValueError as e:
        return 1
    return 0

def test_no_exception():
    """
    >>> test_no_exception()
    1
    """
    cdef int r1
    try:
        with nogil:
            r1 = raises(1)
    except ValueError as e:
        return 0
    return r1


cdef void void_raises(int success) nogil except ~:
    if not success:
        with gil:
            raise ValueError("wrong value")

def test_void_return_exception():
    """
    >>> test_void_return_exception()
    1
    """
    try:
        void_raises(0)
        return 0
    except ValueError as e:
        return 1


cdef cypclass Raises:
    int raises(self, int success) nogil except ~:
        if not success:
            with gil:
                raise ValueError("wrong value")
        else:
            return success

def test_method_exception():
    """
    >>> test_method_exception()
    1
    """
    cdef int r1
    r = Raises()
    try:
        with nogil:
            r1 = r.raises(0)
    except ValueError as e:
        return 1
    return r1
