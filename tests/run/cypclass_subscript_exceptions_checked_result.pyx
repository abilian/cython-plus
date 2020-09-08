# mode: run
# tag: cpp, cpp11, pthread
# cython: experimental_cpp_class_def=True, language_level=2

from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair
from libcpp.vector cimport vector
cimport cython.operator.dereference as deref


cdef cypclass SingleInsertionDict[K, V]:
    """
    A key-value container that treats inserting an already contained value as an exception.
    """
    ctypedef (K, V) item_type
    ctypedef vector[item_type].size_type size_type

    vector[item_type] _items
    unordered_map[K, size_type] _indices

    void __setitem__(self, K key, V value) except ~:
        it = self._indices.find(key)
        end = self._indices.end()

        if it == end:
            self._indices[key] = self._items.size()
            self._items.push_back((key, value))
        else:
            with gil:
                raise KeyError("Setting an index that is already contained")

    V __getitem__(self, const K key) except ~:
        it = self._indices.find(key)
        end = self._indices.end()
        if it == end:
            with gil:
                raise KeyError("Getting the value for an uncontained index")
        else:
            return self._items[deref(it).second][1]

    void __delitem__(self, K key) except ~:
        it = self._indices.find(key)
        end = self._indices.end()

        if it != end:
            index = deref(it).second
            self._indices.erase(it)
            if index < self._items.size() - 1:
                self._items[index] = self._items[self._indices.size() - 1]
            self._items.pop_back()
        else:
            with gil:
                raise KeyError("Deleting the value for an uncontained index")

cdef cypclass Value:
    pass

cdef cypclass Index:
    pass

def test_setting_twice():
    """
    >>> test_setting_twice()
    'Setting an index that is already contained'
    1
    """
    d = SingleInsertionDict[Index, Value]()
    i = Index()
    v = Value()
    try:
        with nogil:
            d[i] = v
    except KeyError as e:
        print(e)
        return 0
    try:
        with nogil:
            d[i] = v
    except KeyError as e:
        print(e)
        return 1
    return 0


def test_getting_uncontained():
    """
    >>> test_getting_uncontained()
    'Getting the value for an uncontained index'
    1
    """
    d = SingleInsertionDict[Index, Value]()
    try:
        with nogil:
            v = d[Index()]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1

def test_getting_contained():
    """
    >>> test_getting_contained()
    1
    """
    d = SingleInsertionDict[Index, Value]()
    v = Value()
    i = Index()
    d[i] = v
    try:
        with nogil:
            v2 = d[i]
            if v2 is v:
                with gil:
                    return 1
            else:
                with gil:
                    return 0
    except KeyError as e:
        print(e)
        return 0

def test_deleting_uncontained():
    """
    >>> test_deleting_uncontained()
    'Deleting the value for an uncontained index'
    1
    """
    d = SingleInsertionDict[Index, Value]()
    try:
        with nogil:
            del d[Index()]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1

def test_deleting_twice():
    """
    >>> test_deleting_twice()
    'Deleting the value for an uncontained index'
    1
    """
    d = SingleInsertionDict[Index, Value]()
    v = Value()
    i = Index()
    d[i] = v
    try:
        with nogil:
            del d[i]
    except KeyError as e:
        print(e)
        return 0
    try:
        with nogil:
            del d[i]
            with gil:
                return 0
    except KeyError as e:
        print(e)
        return 1