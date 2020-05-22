#
#   Code generation for wrapping cypclass as a Python Extension Type
#
#   Will be generated:
#       - a PyTypeObject definition for each user defined cypclass
#       - Python wrappers for cypclass methods
#       - Python getters/setters for cypclass attributes
#       - Specific 'tp slots' for handling cycplass objects from Python:
#           . tp_new
#           . tp_init
#           . tp_dealloc
#           ...
#
#   Functions defined here will be called from ModuleNode.py
#
#   Reasons for using a separate file:
#       - avoid cluttering ModuleNode.py
#       - regroup common logic
#       - decouple the code generation process from that of 'cdef class'
#
#   Code generation for cypclass will be similar to code generation for 'cdef class' in ModuleNode.py,
#   but differences are significant enough that it is better to introduce some redundancy than try to
#   handle both 'cdef class' and 'cypclass' in ModuleNode.py.
#


def cypclass_iter(scope):
    """
        Recursively iterate over nested cypclasses
    """

    for entry in scope.cypclass_entries:
        yield entry
        cypclass_scope = entry.type.scope
        if cypclass_scope:
            for e in cypclass_iter(cypclass_scope):
                yield e

def generate_cypclass_typeobj_declarations(env, code, definition):
    """
        Generate declarations of global pointers to the PyTypeObject for each cypclass
    """

    for entry in cypclass_iter(env):
        if definition or entry.defined_in_pxd:
            code.putln("static PyTypeObject *%s = 0;" % (
                entry.type.typeptr_cname))

