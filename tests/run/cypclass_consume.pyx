# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcythonplus.dict cimport cypdict
from libcythonplus.list cimport cyplist
from libcythonplus.set cimport cypset


cdef cypclass Leaf activable:
    int value

def test_consume_isolated_leaf():
    """
    >>> test_consume_isolated_leaf()
    0
    """
    try:
        l = consume Leaf()
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_isolated_named_leaf():
    """
    >>> test_consume_isolated_named_leaf()
    0
    """
    leaf = Leaf()
    try:
        l = consume leaf
        if leaf is not NULL:
            return -1
        return 0
    except TypeError as e:
        print(e)
        return -2

def test_consume_aliased_leaf():
    """
    >>> test_consume_aliased_leaf()
    'consume' operand is not isolated
    0
    """
    leaf = Leaf()
    leaf2 = leaf
    try:
        l = consume leaf
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_nogil_consume_isolated_leaf():
    """
    >>> test_nogil_consume_isolated_leaf()
    0
    """
    try:
        with nogil:
            l = consume Leaf()
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_nogil_consume_aliased_leaf():
    """
    >>> test_nogil_consume_aliased_leaf()
    'consume' operand is not isolated
    0
    """
    leaf = Leaf()
    leaf2 = leaf
    try:
        with nogil:
            l = consume leaf
        return -1
    except TypeError as e:
        print(e)
        return 0


cdef cypclass Convertible:
    Leaf __Leaf__(self):
        return Leaf()

def test_consume_isolated_cast_named_leaf():
    """
    >>> test_consume_isolated_cast_named_leaf()
    0
    """
    leaf = Leaf()
    try:
        l = consume <Leaf> leaf
        if leaf is not NULL:
            return -1
        return 0
    except TypeError as e:
        print(e)
        return -2

def test_consume_isolated_cast_converted_leaf():
    """
    >>> test_consume_isolated_cast_converted_leaf()
    0
    """
    try:
        l = consume <Leaf> Convertible()
        return 0
    except TypeError as e:
        print(e)
        return -2

cdef cypclass Field:
    Field foo(self, Field other):
        return other

cdef cypclass Origin:
    Field field

    __init__(self):
        self.field = Field()

def test_consume_isolated_origin():
    """
    >>> test_consume_isolated_origin()
    0
    """
    try:
        o = consume Origin()
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_origin_with_aliased_field():
    """
    >>> test_consume_origin_with_aliased_field()
    'consume' operand is not isolated
    0
    """
    origin = Origin()
    field = origin.field
    try:
        o = consume origin
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_consume_field():
    """
    >>> test_consume_field()
    0
    """
    origin = Origin()
    try:
        f = consume origin.field
        if origin.field is not NULL:
            return -1
        return 0
    except TypeError as e:
        print(e)
        return -2

def test_consume_field_from_temporary_origin():
    """
    >>> test_consume_field_from_temporary_origin()
    0
    """
    try:
        f = consume Origin().field
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_aliased_field():
    """
    >>> test_consume_aliased_field()
    'consume' operand is not isolated
    0
    """
    origin = Origin()
    field = origin.field
    try:
        f = consume origin.field
        return -1
    except TypeError as e:
        print(e)
        return 0


cdef cypclass DoubleOrigin(Origin):
    Field field2

    __init__(self):
        self.field2 = self.field = Field()


def test_consume_isolated_double_origin():
    """
    >>> test_consume_isolated_double_origin()
    0
    """
    try:
        o = consume DoubleOrigin()
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_double_origin_with_aliased_field():
    """
    >>> test_consume_double_origin_with_aliased_field()
    'consume' operand is not isolated
    0
    """
    origin = DoubleOrigin()
    field = origin.field
    try:
        o = consume origin
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_consume_field_from_double_origin():
    """
    >>> test_consume_field_from_double_origin()
    'consume' operand is not isolated
    0
    """
    try:
        f = consume DoubleOrigin().field
        return -1
    except TypeError as e:
        print(e)
        return 0


cdef cypclass Cycle:
    Cycle field

    __init__(self):
        self.field = self

def test_consume_isolated_cycle():
    """
    >>> test_consume_isolated_cycle()
    0
    """
    try:
        c = consume Cycle()
        return 0
    except TypeError as e:
        print(e)
        return -1


cdef iso Leaf consume_arg(Leaf arg) except NULL:
    return consume arg

def test_consume_isolated_arg():
    """
    >>> test_consume_isolated_arg()
    0
    """
    try:
        l = consume_arg(Leaf())
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_aliased_arg():
    """
    >>> test_consume_aliased_arg()
    'consume' operand is not isolated
    0
    """
    leaf = Leaf()
    try:
        l = consume_arg(leaf)
        return -1
    except TypeError as e:
        print(e)
        return 0


def test_consume_isolated_leaf_list():
    """
    >>> test_consume_isolated_leaf_list()
    0
    """
    leaflist = cyplist[Leaf]()
    for i in range(5):
        leaflist.append(Leaf())

    try:
        l = consume leaflist
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_leaf_list_with_aliased_element():
    """
    >>> test_consume_leaf_list_with_aliased_element()
    'consume' operand is not isolated
    0
    """
    leaflist = cyplist[Leaf]()
    for i in range(5):
        leaflist.append(Leaf())
    leaf = leaflist[0]

    try:
        l = consume leaflist
        return -1
    except TypeError as e:
        print(e)
        return 0


def test_consume_isolated_leaf_set():
    """
    >>> test_consume_isolated_leaf_set()
    0
    """
    leafset = cypset[Leaf]()
    for i in range(5):
        leafset.add(Leaf())

    try:
        s = consume leafset
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_leaf_set_with_aliased_element():
    """
    >>> test_consume_leaf_set_with_aliased_element()
    'consume' operand is not isolated
    0
    """
    leafset = cypset[Leaf]()
    for i in range(4):
        leafset.add(Leaf())
    leaf = Leaf()
    leafset.add(leaf)

    try:
        s = consume leafset
        return -1
    except TypeError as e:
        print(e)
        return 0


def test_consume_isolated_leaf_dict():
    """
    >>> test_consume_isolated_leaf_set()
    0
    """
    leafdict = cypdict[Leaf, Leaf]()
    for i in range(5):
        leafdict[Leaf()] = Leaf()

    try:
        d = consume leafdict
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_leaf_dict_with_aliased_key():
    """
    >>> test_consume_leaf_dict_with_aliased_key()
    'consume' operand is not isolated
    0
    """
    leafdict = cypdict[Leaf, Leaf]()
    for i in range(5):
        leafdict[Leaf()] = Leaf()
    leaf = Leaf()
    leafdict[leaf] = Leaf()

    try:
        d = consume leafdict
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_consume_leaf_dict_with_aliased_value():
    """
    >>> test_consume_leaf_dict_with_aliased_value()
    'consume' operand is not isolated
    0
    """
    leafdict = cypdict[Leaf, Leaf]()
    for i in range(5):
        leafdict[Leaf()] = Leaf()
    leaf = Leaf()
    leafdict[Leaf()] = leaf

    try:
        d = consume leafdict
        return -1
    except TypeError as e:
        print(e)
        return 0


def test_consume_isolated_nested_container():
    """
    >>> test_consume_isolated_nested_container()
    0
    """
    nestedlist = cyplist[cyplist[Leaf]]()
    for i in range(5):
        innerlist = cyplist[Leaf]()
        for i in range(5):
            innerlist.append(Leaf())
        nestedlist.append(innerlist)
        del innerlist

    try:
        l = consume nestedlist
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_nested_container_with_aliased_leaf():
    """
    >>> test_consume_nested_container_with_aliased_leaf()
    'consume' operand is not isolated
    0
    """
    nestedlist = cyplist[cyplist[Leaf]]()
    for i in range(5):
        innerlist = cyplist[Leaf]()
        for i in range(5):
            innerlist.append(Leaf())
        nestedlist.append(innerlist)
    leaf = nestedlist[0][0]

    try:
        l = consume nestedlist
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_consume_nested_container_with_aliased_list():
    """
    >>> test_consume_nested_container_with_aliased_list()
    'consume' operand is not isolated
    0
    """
    nestedlist = cyplist[cyplist[Leaf]]()
    for i in range(5):
        innerlist = cyplist[Leaf]()
        for i in range(5):
            innerlist.append(Leaf())
        nestedlist.append(innerlist)
    leaflist = nestedlist[0]

    try:
        l = consume nestedlist
        return -1
    except TypeError as e:
        print(e)
        return 0


cdef cypclass Template[T]:
    T field

def test_consume_isolated_template():
    """
    >>> test_consume_isolated_template()
    0
    """
    template = Template[Leaf]()
    template.field = Leaf()

    try:
        t = consume template
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_template_with_aliased_field():
    """
    >>> test_consume_template_with_aliased_field()
    'consume' operand is not isolated
    0
    """
    template = Template[Leaf]()
    leaf = Leaf()
    template.field = leaf

    try:
        t = consume template
        return -1
    except TypeError as e:
        print(e)
        return 0

def test_consume_template_with_aliased_lock_field():
    """
    >>> test_consume_template_with_aliased_lock_field()
    0
    """
    template = <Template[lock Leaf]> new Template[lock Leaf]()
    leaf = <lock Leaf> consume Leaf()
    template.field = leaf

    try:
        t = consume template
        return 0
    except TypeError as e:
        print(e)
        return -1

def test_consume_template_with_aliased_active_field():
    """
    >>> test_consume_template_with_aliased_active_field()
    0
    """
    template = <Template[active Leaf]> new Template[active Leaf]()
    leaf = activate(consume Leaf())
    template.field = leaf

    try:
        t = consume template
        return 0
    except TypeError as e:
        print(e)
        return -1

