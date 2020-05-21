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


def generate_cypclass_typeobj_declarations(env, code, definition):
    """
        Generate declarations of global pointers to the PyTypeObject for each cypclass
    """

    for entry in env.cypclass_entries:
        if definition or entry.defined_in_pxd:
            code.putln("static PyTypeObject *%s = 0;" % (
                entry.type.typeptr_cname))
        cyp_scope = entry.type.scope
        if cyp_scope:
            # generate declarations for nested cycplasses
            generate_cypclass_typeobj_declarations(cyp_scope, code, definition)

