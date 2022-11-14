#
#   Builtin Definitions
#

from __future__ import absolute_import

from .Symtab import BuiltinScope, StructOrUnionScope, CppClassScope
from .Code import UtilityCode
from .TypeSlots import Signature
from . import PyrexTypes
from . import Options


# C-level implementations of builtin types, functions and methods

iter_next_utility_code = UtilityCode.load("IterNext", "ObjectHandling.c")
getattr_utility_code = UtilityCode.load("GetAttr", "ObjectHandling.c")
getattr3_utility_code = UtilityCode.load("GetAttr3", "Builtins.c")
pyexec_utility_code = UtilityCode.load("PyExec", "Builtins.c")
pyexec_globals_utility_code = UtilityCode.load("PyExecGlobals", "Builtins.c")
globals_utility_code = UtilityCode.load("Globals", "Builtins.c")

builtin_utility_code = {
    'StopAsyncIteration': UtilityCode.load_cached("StopAsyncIteration", "Coroutine.c"),
}


# mapping from builtins to their C-level equivalents

class _BuiltinOverride(object):
    def __init__(self, py_name, args, ret_type, cname, py_equiv="*",
                 utility_code=None, sig=None, func_type=None,
                 is_strict_signature=False, builtin_return_type=None,
                 nogil=None):
        self.py_name, self.cname, self.py_equiv = py_name, cname, py_equiv
        self.args, self.ret_type = args, ret_type
        self.func_type, self.sig = func_type, sig
        self.builtin_return_type = builtin_return_type
        self.is_strict_signature = is_strict_signature
        self.utility_code = utility_code
        self.nogil = nogil

    def build_func_type(self, sig=None, self_arg=None):
        if sig is None:
            sig = Signature(self.args, self.ret_type, nogil=self.nogil)
            sig.exception_check = False  # not needed for the current builtins
        func_type = sig.function_type(self_arg)
        if self.is_strict_signature:
            func_type.is_strict_signature = True
        if self.builtin_return_type:
            func_type.return_type = builtin_types[self.builtin_return_type]
        return func_type


class BuiltinAttribute(object):
    def __init__(self, py_name, cname=None, field_type=None, field_type_name=None):
        self.py_name = py_name
        self.cname = cname or py_name
        self.field_type_name = field_type_name  # can't do the lookup before the type is declared!
        self.field_type = field_type

    def declare_in_type(self, self_type):
        if self.field_type_name is not None:
            # lazy type lookup
            field_type = builtin_scope.lookup(self.field_type_name).type
        else:
            field_type = self.field_type or PyrexTypes.py_object_type
        entry = self_type.scope.declare(self.py_name, self.cname, field_type, None, 'private')
        entry.is_variable = True


class BuiltinFunction(_BuiltinOverride):
    def declare_in_scope(self, scope):
        func_type, sig = self.func_type, self.sig
        if func_type is None:
            func_type = self.build_func_type(sig)
        scope.declare_builtin_cfunction(self.py_name, func_type, self.cname,
                                        self.py_equiv, self.utility_code)


class BuiltinMethod(_BuiltinOverride):
    def declare_in_type(self, self_type):
        method_type, sig = self.func_type, self.sig
        if method_type is None:
            # override 'self' type (first argument)
            self_arg = PyrexTypes.CFuncTypeArg("", self_type, None)
            self_arg.not_none = True
            self_arg.accept_builtin_subtypes = True
            method_type = self.build_func_type(sig, self_arg)
        self_type.scope.declare_builtin_cfunction(
            self.py_name, method_type, self.cname, utility_code=self.utility_code)


builtin_function_table = [
    # name,        args,   return,  C API func,           py equiv = "*"
    BuiltinFunction('abs',        "d",    "d",     "fabs",
                    is_strict_signature=True, nogil=True),
    BuiltinFunction('abs',        "f",    "f",     "fabsf",
                    is_strict_signature=True, nogil=True),
    BuiltinFunction('abs',        "i",    "i",     "abs",
                    is_strict_signature=True, nogil=True),
    BuiltinFunction('abs',        "l",    "l",     "labs",
                    is_strict_signature=True, nogil=True),
    BuiltinFunction('abs',        None,    None,   "__Pyx_abs_longlong",
                utility_code = UtilityCode.load("abs_longlong", "Builtins.c"),
                func_type = PyrexTypes.CFuncType(
                    PyrexTypes.c_longlong_type, [
                        PyrexTypes.CFuncTypeArg("arg", PyrexTypes.c_longlong_type, None)
                        ],
                    is_strict_signature = True, nogil=True)),
    ] + list(
        BuiltinFunction('abs',        None,    None,   "/*abs_{0}*/".format(t.specialization_name()),
                    func_type = PyrexTypes.CFuncType(
                        t,
                        [PyrexTypes.CFuncTypeArg("arg", t, None)],
                        is_strict_signature = True, nogil=True))
                            for t in (PyrexTypes.c_uint_type, PyrexTypes.c_ulong_type, PyrexTypes.c_ulonglong_type)
             ) + list(
        BuiltinFunction('abs',        None,    None,   "__Pyx_c_abs{0}".format(t.funcsuffix),
                    func_type = PyrexTypes.CFuncType(
                        t.real_type, [
                            PyrexTypes.CFuncTypeArg("arg", t, None)
                            ],
                            is_strict_signature = True, nogil=True))
                        for t in (PyrexTypes.c_float_complex_type,
                                  PyrexTypes.c_double_complex_type,
                                  PyrexTypes.c_longdouble_complex_type)
                        ) + [
    BuiltinFunction('abs',        "O",    "O",     "__Pyx_PyNumber_Absolute",
                    utility_code=UtilityCode.load("py_abs", "Builtins.c")),
    #('all',       "",     "",      ""),
    #('any',       "",     "",      ""),
    #('ascii',     "",     "",      ""),
    #('bin',       "",     "",      ""),
    BuiltinFunction('callable',   "O",    "b",     "__Pyx_PyCallable_Check",
                    utility_code = UtilityCode.load("CallableCheck", "ObjectHandling.c")),
    #('chr',       "",     "",      ""),
    #('cmp', "",   "",     "",      ""), # int PyObject_Cmp(PyObject *o1, PyObject *o2, int *result)
    #('compile',   "",     "",      ""), # PyObject* Py_CompileString(    char *str, char *filename, int start)
    BuiltinFunction('delattr',    "OO",   "r",     "PyObject_DelAttr"),
    BuiltinFunction('dir',        "O",    "O",     "PyObject_Dir"),
    BuiltinFunction('divmod',     "OO",   "O",     "PyNumber_Divmod"),
    BuiltinFunction('exec',       "O",    "O",     "__Pyx_PyExecGlobals",
                    utility_code = pyexec_globals_utility_code),
    BuiltinFunction('exec',       "OO",   "O",     "__Pyx_PyExec2",
                    utility_code = pyexec_utility_code),
    BuiltinFunction('exec',       "OOO",  "O",     "__Pyx_PyExec3",
                    utility_code = pyexec_utility_code),
    #('eval',      "",     "",      ""),
    #('execfile',  "",     "",      ""),
    #('filter',    "",     "",      ""),
    BuiltinFunction('getattr3',   "OOO",  "O",     "__Pyx_GetAttr3",     "getattr",
                    utility_code=getattr3_utility_code),  # Pyrex legacy
    BuiltinFunction('getattr',    "OOO",  "O",     "__Pyx_GetAttr3",
                    utility_code=getattr3_utility_code),
    BuiltinFunction('getattr',    "OO",   "O",     "__Pyx_GetAttr",
                    utility_code=getattr_utility_code),
    BuiltinFunction('hasattr',    "OO",   "b",     "__Pyx_HasAttr",
                    utility_code = UtilityCode.load("HasAttr", "Builtins.c")),
    BuiltinFunction('hash',       "O",    "h",     "PyObject_Hash"),
    #('hex',       "",     "",      ""),
    #('id',        "",     "",      ""),
    #('input',     "",     "",      ""),
    BuiltinFunction('intern',     "O",    "O",     "__Pyx_Intern",
                    utility_code = UtilityCode.load("Intern", "Builtins.c")),
    BuiltinFunction('isinstance', "OO",   "b",     "PyObject_IsInstance"),
    BuiltinFunction('issubclass', "OO",   "b",     "PyObject_IsSubclass"),
    BuiltinFunction('iter',       "OO",   "O",     "PyCallIter_New"),
    BuiltinFunction('iter',       "O",    "O",     "PyObject_GetIter"),
    BuiltinFunction('len',        "O",    "z",     "PyObject_Length"),
    BuiltinFunction('locals',     "",     "O",     "__pyx_locals"),
    #('map',       "",     "",      ""),
    #('max',       "",     "",      ""),
    #('min',       "",     "",      ""),
    BuiltinFunction('next',       "O",    "O",     "__Pyx_PyIter_Next",
                    utility_code = iter_next_utility_code),   # not available in Py2 => implemented here
    BuiltinFunction('next',      "OO",    "O",     "__Pyx_PyIter_Next2",
                    utility_code = iter_next_utility_code),  # not available in Py2 => implemented here
    #('oct',       "",     "",      ""),
    #('open',       "ss",   "O",     "PyFile_FromString"),   # not in Py3
] + [
    BuiltinFunction('ord',        None,    None,   "__Pyx_long_cast",
                    func_type=PyrexTypes.CFuncType(
                        PyrexTypes.c_long_type, [PyrexTypes.CFuncTypeArg("c", c_type, None)],
                        is_strict_signature=True))
    for c_type in [PyrexTypes.c_py_ucs4_type, PyrexTypes.c_py_unicode_type]
] + [
    BuiltinFunction('ord',        None,    None,   "__Pyx_uchar_cast",
                    func_type=PyrexTypes.CFuncType(
                        PyrexTypes.c_uchar_type, [PyrexTypes.CFuncTypeArg("c", c_type, None)],
                        is_strict_signature=True))
    for c_type in [PyrexTypes.c_char_type, PyrexTypes.c_schar_type, PyrexTypes.c_uchar_type]
] + [
    BuiltinFunction('ord',        None,    None,   "__Pyx_PyObject_Ord",
                    utility_code=UtilityCode.load_cached("object_ord", "Builtins.c"),
                    func_type=PyrexTypes.CFuncType(
                        PyrexTypes.c_long_type, [
                            PyrexTypes.CFuncTypeArg("c", PyrexTypes.py_object_type, None)
                        ],
                        exception_value="(long)(Py_UCS4)-1")),
    BuiltinFunction('pow',        "OOO",  "O",     "PyNumber_Power"),
    BuiltinFunction('pow',        "OO",   "O",     "__Pyx_PyNumber_Power2",
                    utility_code = UtilityCode.load("pow2", "Builtins.c")),
    #('range',     "",     "",      ""),
    #('raw_input', "",     "",      ""),
    #('reduce',    "",     "",      ""),
    BuiltinFunction('reload',     "O",    "O",     "PyImport_ReloadModule"),
    BuiltinFunction('repr',       "O",    "O",     "PyObject_Repr"),  # , builtin_return_type='str'),  # add in Cython 3.1
    #('round',     "",     "",      ""),
    BuiltinFunction('setattr',    "OOO",  "r",     "PyObject_SetAttr"),
    #('sum',       "",     "",      ""),
    #('sorted',    "",     "",      ""),
    #('type',       "O",    "O",     "PyObject_Type"),
    BuiltinFunction('unichr',     "l",    "O",      "PyUnicode_FromOrdinal", builtin_return_type='unicode'),
    #('unicode',   "",     "",      ""),
    #('vars',      "",     "",      ""),
    #('zip',       "",     "",      ""),
    #  Can't do these easily until we have builtin type entries.
    #('typecheck',  "OO",   "i",     "PyObject_TypeCheck", False),
    #('issubtype',  "OO",   "i",     "PyType_IsSubtype",   False),

    # Put in namespace append optimization.
    BuiltinFunction('__Pyx_PyObject_Append', "OO",  "O",     "__Pyx_PyObject_Append"),

    # This is conditionally looked up based on a compiler directive.
    BuiltinFunction('__Pyx_Globals',    "",     "O",     "__Pyx_Globals",
                    utility_code=globals_utility_code),
]


# Builtin types
#  bool
#  buffer
#  classmethod
#  dict
#  enumerate
#  file
#  float
#  int
#  list
#  long
#  object
#  property
#  slice
#  staticmethod
#  super
#  str
#  tuple
#  type
#  xrange

builtin_types_table = [

    ("type",    "PyType_Type",     []),

# This conflicts with the C++ bool type, and unfortunately
# C++ is too liberal about PyObject* <-> bool conversions,
# resulting in unintuitive runtime behavior and segfaults.
#    ("bool",    "PyBool_Type",     []),

    ("int",     "PyInt_Type",      []),
    ("long",    "PyLong_Type",     []),
    ("float",   "PyFloat_Type",    []),

    ("complex", "PyComplex_Type",  [BuiltinAttribute('cval', field_type_name = 'Py_complex'),
                                    BuiltinAttribute('real', 'cval.real', field_type = PyrexTypes.c_double_type),
                                    BuiltinAttribute('imag', 'cval.imag', field_type = PyrexTypes.c_double_type),
                                    ]),

    ("basestring", "PyBaseString_Type", [
                                    BuiltinMethod("join",  "TO",   "T", "__Pyx_PyBaseString_Join",
                                                  utility_code=UtilityCode.load("StringJoin", "StringTools.c")),
                                    ]),
    ("bytearray", "PyByteArray_Type", [
                                    ]),
    ("bytes",   "PyBytes_Type",    [BuiltinMethod("__contains__",  "TO",   "b", "PySequence_Contains"),
                                    BuiltinMethod("join",  "TO",   "O", "__Pyx_PyBytes_Join",
                                                  utility_code=UtilityCode.load("StringJoin", "StringTools.c")),
                                    ]),
    ("str",     "PyString_Type",   [BuiltinMethod("__contains__",  "TO",   "b", "PySequence_Contains"),
                                    BuiltinMethod("join",  "TO",   "O", "__Pyx_PyString_Join",
                                                  builtin_return_type='basestring',
                                                  utility_code=UtilityCode.load("StringJoin", "StringTools.c")),
                                    ]),
    ("unicode", "PyUnicode_Type",  [BuiltinMethod("__contains__",  "TO",   "b", "PyUnicode_Contains"),
                                    BuiltinMethod("join",  "TO",   "T", "PyUnicode_Join"),
                                    ]),

    ("tuple",   "PyTuple_Type",    [BuiltinMethod("__contains__",  "TO",   "b", "PySequence_Contains"),
                                    ]),

    ("list",    "PyList_Type",     [BuiltinMethod("__contains__",  "TO",   "b", "PySequence_Contains"),
                                    BuiltinMethod("insert",  "TzO",  "r", "PyList_Insert"),
                                    BuiltinMethod("reverse", "T",    "r", "PyList_Reverse"),
                                    BuiltinMethod("append",  "TO",   "r", "__Pyx_PyList_Append",
                                                  utility_code=UtilityCode.load("ListAppend", "Optimize.c")),
                                    BuiltinMethod("extend",  "TO",   "r", "__Pyx_PyList_Extend",
                                                  utility_code=UtilityCode.load("ListExtend", "Optimize.c")),
                                    ]),

    ("dict",    "PyDict_Type",     [BuiltinMethod("__contains__",  "TO",   "b", "PyDict_Contains"),
                                    BuiltinMethod("has_key",       "TO",   "b", "PyDict_Contains"),
                                    BuiltinMethod("items",  "T",   "O", "__Pyx_PyDict_Items",
                                                  utility_code=UtilityCode.load("py_dict_items", "Builtins.c")),
                                    BuiltinMethod("keys",   "T",   "O", "__Pyx_PyDict_Keys",
                                                  utility_code=UtilityCode.load("py_dict_keys", "Builtins.c")),
                                    BuiltinMethod("values", "T",   "O", "__Pyx_PyDict_Values",
                                                  utility_code=UtilityCode.load("py_dict_values", "Builtins.c")),
                                    BuiltinMethod("iteritems",  "T",   "O", "__Pyx_PyDict_IterItems",
                                                  utility_code=UtilityCode.load("py_dict_iteritems", "Builtins.c")),
                                    BuiltinMethod("iterkeys",   "T",   "O", "__Pyx_PyDict_IterKeys",
                                                  utility_code=UtilityCode.load("py_dict_iterkeys", "Builtins.c")),
                                    BuiltinMethod("itervalues", "T",   "O", "__Pyx_PyDict_IterValues",
                                                  utility_code=UtilityCode.load("py_dict_itervalues", "Builtins.c")),
                                    BuiltinMethod("viewitems",  "T",   "O", "__Pyx_PyDict_ViewItems",
                                                  utility_code=UtilityCode.load("py_dict_viewitems", "Builtins.c")),
                                    BuiltinMethod("viewkeys",   "T",   "O", "__Pyx_PyDict_ViewKeys",
                                                  utility_code=UtilityCode.load("py_dict_viewkeys", "Builtins.c")),
                                    BuiltinMethod("viewvalues", "T",   "O", "__Pyx_PyDict_ViewValues",
                                                  utility_code=UtilityCode.load("py_dict_viewvalues", "Builtins.c")),
                                    BuiltinMethod("clear",  "T",   "r", "__Pyx_PyDict_Clear",
                                                  utility_code=UtilityCode.load("py_dict_clear", "Optimize.c")),
                                    BuiltinMethod("copy",   "T",   "T", "PyDict_Copy")]),

    ("slice",   "PySlice_Type",    [BuiltinAttribute('start'),
                                    BuiltinAttribute('stop'),
                                    BuiltinAttribute('step'),
                                    ]),
#    ("file",    "PyFile_Type",     []),  # not in Py3

    ("set",       "PySet_Type",    [BuiltinMethod("__contains__",  "TO",   "b", "PySequence_Contains"),
                                    BuiltinMethod("clear",   "T",  "r", "PySet_Clear"),
                                    # discard() and remove() have a special treatment for unhashable values
                                    BuiltinMethod("discard", "TO", "r", "__Pyx_PySet_Discard",
                                                  utility_code=UtilityCode.load("py_set_discard", "Optimize.c")),
                                    BuiltinMethod("remove",  "TO", "r", "__Pyx_PySet_Remove",
                                                  utility_code=UtilityCode.load("py_set_remove", "Optimize.c")),
                                    # update is actually variadic (see Github issue #1645)
#                                    BuiltinMethod("update",     "TO", "r", "__Pyx_PySet_Update",
#                                                  utility_code=UtilityCode.load_cached("PySet_Update", "Builtins.c")),
                                    BuiltinMethod("add",     "TO", "r", "PySet_Add"),
                                    BuiltinMethod("pop",     "T",  "O", "PySet_Pop")]),
    ("frozenset", "PyFrozenSet_Type", []),
    ("Exception", "((PyTypeObject*)PyExc_Exception)[0]", []),
    ("StopAsyncIteration", "((PyTypeObject*)__Pyx_PyExc_StopAsyncIteration)[0]", []),
]


types_that_construct_their_instance = set([
    # some builtin types do not always return an instance of
    # themselves - these do:
    'type', 'bool', 'long', 'float', 'complex',
    'bytes', 'unicode', 'bytearray',
    'tuple', 'list', 'dict', 'set', 'frozenset'
    # 'str',             # only in Py3.x
    # 'file',            # only in Py2.x
])


builtin_structs_table = [
    ('Py_buffer', 'Py_buffer',
     [("buf",        PyrexTypes.c_void_ptr_type),
      ("obj",        PyrexTypes.py_object_type),
      ("len",        PyrexTypes.c_py_ssize_t_type),
      ("itemsize",   PyrexTypes.c_py_ssize_t_type),
      ("readonly",   PyrexTypes.c_bint_type),
      ("ndim",       PyrexTypes.c_int_type),
      ("format",     PyrexTypes.c_char_ptr_type),
      ("shape",      PyrexTypes.c_py_ssize_t_ptr_type),
      ("strides",    PyrexTypes.c_py_ssize_t_ptr_type),
      ("suboffsets", PyrexTypes.c_py_ssize_t_ptr_type),
      ("smalltable", PyrexTypes.CArrayType(PyrexTypes.c_py_ssize_t_type, 2)),
      ("internal",   PyrexTypes.c_void_ptr_type),
      ]),
    ('Py_complex', 'Py_complex',
     [('real', PyrexTypes.c_double_type),
      ('imag', PyrexTypes.c_double_type),
      ])
]

# inject cyobject
def inject_cy_object(self):
    global cy_object_type
    def init_scope(scope):
        scope.is_cpp_class_scope = 1
        scope.is_cyp_class_scope = 1
        scope.inherited_var_entries = []
        scope.inherited_type_entries = []

    cy_object_scope = CppClassScope("CyObject", self, None)
    init_scope(cy_object_scope)
    cy_object_type = PyrexTypes.cy_object_type
    cy_object_scope.type = PyrexTypes.cy_object_type
    cy_object_type.set_scope(cy_object_scope)
    cy_object_entry = self.declare("CyObject", "CyObject", cy_object_type, None, "extern")
    cy_object_entry.is_type = 1

# inject acthon interfaces
def inject_acthon_interfaces(self):
    global acthon_result_type, acthon_message_type, acthon_sync_type, acthon_queue_type, acthon_activable_type
    def init_scope(scope):
        scope.is_cpp_class_scope = 1
        scope.is_cyp_class_scope = 1
        scope.inherited_var_entries = []
        scope.inherited_type_entries = []

    # cypclass ActhonResultInterface(CyObject):
    #     void pushVoidStarResult(void* result){}
    #     void* getVoidStarResult(){}
    #     void pushIntResult(int result){}
    #     int getIntResult(){}
    #     operator int() { return this->getIntResult(); }

    result_scope = CppClassScope("ActhonResultInterface", self, None)
    init_scope(result_scope)
    acthon_result_type = result_type = PyrexTypes.CypClassType(
                "ActhonResultInterface", result_scope, "ActhonResultInterface", (PyrexTypes.cy_object_type,),
                activable=False)
    result_scope.type = result_type
    #result_type.set_scope is required because parent_type is used when doing scope inheritance
    result_type.set_scope(result_scope)
    result_entry = self.declare("ActhonResultInterface", "ActhonResultInterface", result_type, None, "extern")
    result_entry.is_type = 1

    result_pushVoidStar_arg_type = PyrexTypes.CFuncTypeArg("result", PyrexTypes.c_void_ptr_type, None)
    result_pushVoidStar_type = PyrexTypes.CFuncType(PyrexTypes.c_void_type, [result_pushVoidStar_arg_type], nogil = 1)
    result_pushVoidStar_entry = result_scope.declare("pushVoidStarResult", "pushVoidStarResult",
        result_pushVoidStar_type, None, "extern")
    result_pushVoidStar_entry.is_cfunction = 1
    result_pushVoidStar_entry.is_variable = 1
    result_scope.var_entries.append(result_pushVoidStar_entry)

    result_getVoidStar_type = PyrexTypes.CFuncType(PyrexTypes.c_void_ptr_type, [], nogil = 1)
    result_getVoidStar_type.is_const_method = 1
    result_getVoidStar_entry = result_scope.declare("getVoidStarResult", "getVoidStarResult",
        result_getVoidStar_type, None, "extern")
    result_getVoidStar_entry.is_cfunction = 1
    result_getVoidStar_entry.is_variable = 1
    result_scope.var_entries.append(result_getVoidStar_entry)

    result_pushInt_arg_type = PyrexTypes.CFuncTypeArg("result", PyrexTypes.c_int_type, None)
    result_pushInt_type = PyrexTypes.CFuncType(PyrexTypes.c_void_type, [result_pushInt_arg_type], nogil = 1)
    result_pushInt_entry = result_scope.declare("pushIntResult", "pushIntResult",
        result_pushInt_type, None, "extern")
    result_pushInt_entry.is_cfunction = 1
    result_pushInt_entry.is_variable = 1
    result_scope.var_entries.append(result_pushInt_entry)

    result_getInt_type = PyrexTypes.CFuncType(PyrexTypes.c_int_type, [], nogil = 1)
    result_getInt_type.is_const_method = 1
    result_getInt_entry = result_scope.declare("getIntResult", "getIntResult",
        result_getInt_type, None, "extern")
    result_getInt_entry.is_cfunction = 1
    result_getInt_entry.is_variable = 1
    result_scope.var_entries.append(result_getInt_entry)

    result_int_typecast_type = PyrexTypes.CFuncType(PyrexTypes.c_int_type, [], nogil = 1)
    result_int_typecast_entry = result_scope.declare("operator int", "operator int",
        result_int_typecast_type, None, "extern")
    result_int_typecast_entry.is_cfunction = 1
    result_int_typecast_entry.is_variable = 1
    result_scope.var_entries.append(result_int_typecast_entry)

    result_voidStar_typecast_type = PyrexTypes.CFuncType(PyrexTypes.c_void_ptr_type, [], nogil = 1)
    result_voidStar_typecast_entry = result_scope.declare("operator void *", "operator void *",
        result_voidStar_typecast_type, None, "extern")
    result_voidStar_typecast_entry.is_cfunction = 1
    result_voidStar_typecast_entry.is_variable = 1
    result_scope.var_entries.append(result_voidStar_typecast_entry)

    # cypclass ActhonMessageInterface

    message_scope = CppClassScope("ActhonMessageInterface", self, None)
    init_scope(message_scope)
    acthon_message_type = message_type = PyrexTypes.CypClassType(
                "ActhonMessageInterface", message_scope, "ActhonMessageInterface", (PyrexTypes.cy_object_type,),
                activable=False)
    message_type.set_scope(message_scope)
    message_scope.type = message_type

    # cypclass ActhonSyncInterface(CyObject):
    #     bool isActivable(){}
    #     bool isCompleted(){}
    #     void insertActivity(ActhonMessageInterface msg){}
    #     void removeActivity(ActhonMessageInterface msg){}

    sync_scope = CppClassScope("ActhonSyncInterface", self, None)
    init_scope(sync_scope)
    acthon_sync_type = sync_type = PyrexTypes.CypClassType(
                "ActhonSyncInterface", sync_scope, "ActhonSyncInterface", (PyrexTypes.cy_object_type,),
                activable=False)
    sync_type.set_scope(sync_scope)
    sync_scope.type = sync_type
    sync_entry = self.declare("ActhonSyncInterface", "ActhonSyncInterface", sync_type, None, "extern")
    sync_entry.is_type = 1

    sync_isActivable_type = PyrexTypes.CFuncType(PyrexTypes.c_bint_type, [], nogil = 1)
    sync_isActivable_type.is_const_method = 1
    sync_isActivable_entry = sync_scope.declare("isActivable", "isActivable",
        sync_isActivable_type, None, "extern")
    sync_isActivable_entry.is_cfunction = 1
    sync_isActivable_entry.is_variable = 1
    sync_scope.var_entries.append(sync_isActivable_entry)

    sync_isCompleted_type = PyrexTypes.CFuncType(PyrexTypes.c_bint_type, [], nogil = 1)
    sync_isCompleted_type.is_const_method = 1
    sync_isCompleted_entry = sync_scope.declare("isCompleted", "isCompleted",
        sync_isCompleted_type, None, "extern")
    sync_isCompleted_entry.is_cfunction = 1
    sync_isCompleted_entry.is_variable = 1
    sync_scope.var_entries.append(sync_isCompleted_entry)

    sync_insertActivity_type = PyrexTypes.CFuncType(PyrexTypes.c_void_type, [], nogil = 1)
    sync_removeActivity_type = PyrexTypes.CFuncType(PyrexTypes.c_void_type, [], nogil = 1)
    sync_insertActivity_entry = sync_scope.declare("insertActivity", "insertActivity",
        sync_insertActivity_type, None, "extern")
    sync_insertActivity_entry.is_cfunction = 1
    sync_insertActivity_entry.is_variable = 1
    sync_scope.var_entries.append(sync_insertActivity_entry)
    sync_removeActivity_entry = sync_scope.declare("removeActivity", "removeActivity",
        sync_removeActivity_type, None, "extern")
    sync_removeActivity_entry.is_cfunction = 1
    sync_removeActivity_entry.is_variable = 1
    sync_scope.var_entries.append(sync_removeActivity_entry)

    # cypclass ActhonMessageInterface(CyObject):
    #     ActhonSyncInterface _sync_method
    #     ActhonResultInterface _result
    #     bool activate(){}

    message_entry = self.declare("ActhonMessageInterface", "ActhonMessageInterface", message_type, None, "extern")
    message_entry.is_type = 1

    message_sync_attr_entry = message_scope.declare("_sync_method", "_sync_method",
        PyrexTypes.cyp_class_qualified_type(sync_type, 'lock'), None, "extern")
    message_sync_attr_entry.is_variable = 1
    message_scope.var_entries.append(message_sync_attr_entry)

    message_result_attr_entry = message_scope.declare("_result", "_result",
        PyrexTypes.cyp_class_qualified_type(result_type, 'lock'), None, "extern")
    message_result_attr_entry.is_variable = 1
    message_scope.var_entries.append(message_result_attr_entry)

    message_activate_type = PyrexTypes.CFuncType(PyrexTypes.c_bint_type, [], nogil = 1)
    message_activate_entry = message_scope.declare("activate", "activate",
        message_activate_type, None, "extern")
    message_activate_entry.is_cfunction = 1
    message_activate_entry.is_variable = 1
    message_scope.var_entries.append(message_activate_entry)

    # cypclass ActhonQueueInterface(CyObject):
    #     void push(ActhonMessageInterface message){}
    #     bool activate(){}

    queue_scope = CppClassScope("ActhonQueueInterface", self, None)
    init_scope(queue_scope)
    acthon_queue_type = queue_type = PyrexTypes.CypClassType(
                "ActhonQueueInterface", queue_scope, "ActhonQueueInterface", (PyrexTypes.cy_object_type,),
                activable=False)
    queue_type.set_scope(queue_scope)
    queue_scope.type = queue_type
    queue_entry = self.declare("ActhonQueueInterface", "ActhonQueueInterface", queue_type, self, "extern")
    queue_entry.is_type = 1

    queue_msg_arg = PyrexTypes.CFuncTypeArg("msg", message_type, None)
    queue_push_type = PyrexTypes.CFuncType(PyrexTypes.c_void_type, [queue_msg_arg], nogil = 1, self_qualifier = 'locked')
    queue_push_entry = queue_scope.declare("push", "push", queue_push_type,
        None, "extern")
    queue_push_entry.is_cfunction = 1
    queue_push_entry.is_variable = 1
    queue_scope.var_entries.append(queue_push_entry)

    queue_activate_type = PyrexTypes.CFuncType(PyrexTypes.c_bint_type, [], nogil = 1)
    queue_activate_entry = queue_scope.declare("activate", "activate",
        queue_activate_type, None, "extern")
    queue_activate_entry.is_cfunction = 1
    queue_activate_entry.is_variable = 1
    queue_scope.var_entries.append(queue_activate_entry)

    queue_is_empty_type = PyrexTypes.CFuncType(PyrexTypes.c_bint_type, [], nogil = 1)
    queue_is_empty_type.is_const_method = 1
    queue_is_empty_entry = queue_scope.declare("is_empty", "is_empty",
        queue_is_empty_type, None, "extern")
    queue_is_empty_entry.is_cfunction = 1
    queue_is_empty_entry.is_variable = 1
    queue_scope.var_entries.append(queue_is_empty_entry)

    # cdef cypclass ActivableClass:
    #     ResultInterface (*_active_result_class)()
    #     QueueInterface _active_queue_class

    activable_scope = CppClassScope("ActhonActivableClass", self, None)
    init_scope(activable_scope)
    acthon_activable_type = activable_type = PyrexTypes.CypClassType(
                "ActhonActivableClass", activable_scope, "ActhonActivableClass", (PyrexTypes.cy_object_type,),
                activable=False)
    activable_type.set_scope(activable_scope)
    activable_entry = self.declare("ActhonActivableClass", None, activable_type, "ActhonActivableClass", "extern")
    activable_entry.is_type = 1

    activable_result_attr_type = PyrexTypes.CPtrType(PyrexTypes.CFuncType(result_entry.type, []))
    activable_result_attr_entry = activable_scope.declare("_active_result_class", "_active_result_class",
        activable_result_attr_type, None, "extern")
    activable_result_attr_entry.is_variable = 1
    activable_scope.var_entries.append(activable_result_attr_entry)

    activable_queue_attr_entry = activable_scope.declare("_active_queue_class", "_active_queue_class",
        PyrexTypes.cyp_class_qualified_type(queue_type, 'lock'), None, "extern")
    activable_queue_attr_entry.is_variable = 1
    activable_scope.var_entries.append(activable_queue_attr_entry)


# set up builtin scope

builtin_scope = BuiltinScope()

def init_builtin_funcs():
    for bf in builtin_function_table:
        bf.declare_in_scope(builtin_scope)

builtin_types = {}

def init_builtin_types():
    global builtin_types
    for name, cname, methods in builtin_types_table:
        utility = builtin_utility_code.get(name)
        if name == 'frozenset':
            objstruct_cname = 'PySetObject'
        elif name == 'bytearray':
            objstruct_cname = 'PyByteArrayObject'
        elif name == 'bool':
            objstruct_cname = None
        elif name == 'Exception':
            objstruct_cname = "PyBaseExceptionObject"
        elif name == 'StopAsyncIteration':
            objstruct_cname = "PyBaseExceptionObject"
        else:
            objstruct_cname = 'Py%sObject' % name.capitalize()
        the_type = builtin_scope.declare_builtin_type(name, cname, utility, objstruct_cname)
        builtin_types[name] = the_type
        for method in methods:
            method.declare_in_type(the_type)

def init_builtin_structs():
    for name, cname, attribute_types in builtin_structs_table:
        scope = StructOrUnionScope(name)
        for attribute_name, attribute_type in attribute_types:
            scope.declare_var(attribute_name, attribute_type, None,
                              attribute_name, allow_pyobject=True)
        builtin_scope.declare_struct_or_union(
            name, "struct", scope, 1, None, cname = cname)

def inject_cypclass_refcount_macros():
    incref_type = PyrexTypes.CFuncType(
        PyrexTypes.c_void_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.const_cy_object_type, None)
        ],
        nogil = 1)

    decref_type = PyrexTypes.CFuncType(
        PyrexTypes.c_void_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.CReferenceType(PyrexTypes.const_cy_object_type), None)
        ],
        nogil = 1)

    getref_type = PyrexTypes.CFuncType(
        PyrexTypes.c_int_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.const_cy_object_type, None)
        ],
        nogil = 1)

    for macro, macro_type in [("Cy_INCREF", incref_type), ("Cy_DECREF", decref_type), ("Cy_XDECREF", decref_type), ("Cy_GETREF", getref_type)]:
        builtin_scope.declare_builtin_cfunction(macro, macro_type, macro)

def inject_cypclass_lock_macros():
    blocking_macro_type = PyrexTypes.CFuncType(
        PyrexTypes.c_void_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.const_cy_object_type, None)
        ],
        nogil = 1)
    for macro in ("Cy_RLOCK", "Cy_WLOCK", "Cy_UNWLOCK", "Cy_UNRLOCK"):
        builtin_scope.declare_builtin_cfunction(macro, blocking_macro_type, macro)

    nonblocking_macro_type = PyrexTypes.CFuncType(PyrexTypes.c_int_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.const_cy_object_type, None)
        ],
        nogil = 1)
    for macro in ("Cy_TRYRLOCK", "Cy_TRYWLOCK"):
        builtin_scope.declare_builtin_cfunction(macro, nonblocking_macro_type, macro)

def inject_cypclass_typecheck_functions():
    template_placeholder_type = PyrexTypes.TemplatePlaceholderType("T")
    isinstanceof_type = PyrexTypes.CFuncType(
        PyrexTypes.c_int_type,
        [
            PyrexTypes.CFuncTypeArg("obj", PyrexTypes.const_cy_object_type, None),
            PyrexTypes.CFuncTypeArg("type", template_placeholder_type, None)
        ],
        nogil = 1,
        templates = [template_placeholder_type]
    )
    builtin_scope.declare_builtin_cfunction("isinstanceof", isinstanceof_type, "isinstanceof")

def init_builtins():
    init_builtin_structs()
    init_builtin_types()
    init_builtin_funcs()

    builtin_scope.declare_var(
        '__debug__', PyrexTypes.c_const_type(PyrexTypes.c_bint_type),
        pos=None, cname='(!Py_OptimizeFlag)', is_cdef=True)

    global list_type, tuple_type, dict_type, set_type, frozenset_type
    global bytes_type, str_type, unicode_type, basestring_type, slice_type
    global float_type, bool_type, type_type, complex_type, bytearray_type
    type_type  = builtin_scope.lookup('type').type
    list_type  = builtin_scope.lookup('list').type
    tuple_type = builtin_scope.lookup('tuple').type
    dict_type  = builtin_scope.lookup('dict').type
    set_type   = builtin_scope.lookup('set').type
    frozenset_type = builtin_scope.lookup('frozenset').type
    slice_type   = builtin_scope.lookup('slice').type
    bytes_type = builtin_scope.lookup('bytes').type
    str_type   = builtin_scope.lookup('str').type
    unicode_type = builtin_scope.lookup('unicode').type
    basestring_type = builtin_scope.lookup('basestring').type
    bytearray_type = builtin_scope.lookup('bytearray').type
    float_type = builtin_scope.lookup('float').type
    bool_type  = builtin_scope.lookup('bool').type
    complex_type  = builtin_scope.lookup('complex').type
    inject_cypclass_refcount_macros()
    inject_cypclass_lock_macros()
    inject_cypclass_typecheck_functions()
    inject_acthon_interfaces(builtin_scope)
    inject_cy_object(builtin_scope)


init_builtins()
