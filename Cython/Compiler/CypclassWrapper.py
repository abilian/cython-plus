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


from __future__ import absolute_import

import cython
cython.declare(Naming=object, Options=object, PyrexTypes=object, TypeSlots=object,
               error=object, warning=object, py_object_type=object, cy_object_type=object, UtilityCode=object,
               EncodedString=object, re=object)

from collections import defaultdict
import json
import operator
import os
import re

from .PyrexTypes import CPtrType
from . import Future
from . import Annotate
from . import Code
from . import CypclassWrapper
from . import Naming
from . import Nodes
from . import Options
from . import TypeSlots
from . import PyrexTypes
from . import Pythran

from .Errors import error, warning
from .PyrexTypes import py_object_type, cy_object_type
from ..Utils import open_new_file, replace_suffix, decode_filename, build_hex_version
from .Code import UtilityCode, IncludeCode
from .StringEncoding import EncodedString
from .Pythran import has_np_pythran
from .Visitor import VisitorTransform, CythonTransform


#
#   Utilities for cypclasses
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

def cypclass_iter_scopes(scope):
    """
        Recursively iterate over nested cypclasses and their associated scope
    """

    for entry in scope.cypclass_entries:
        cypclass_scope = entry.type.scope
        yield entry, cypclass_scope
        if cypclass_scope:
            for e, s in cypclass_iter_scopes(cypclass_scope):
                yield e, s

# cypclass entries that take on a special name: reverse mapping
cycplass_special_entry_names = {
    "<init>": "__init__"
}

underlying_name = EncodedString("nogil_cyobject")

#
#   Visitor for wrapper cclass injection
#
#   - Insert additional cclass wrapper nodes by returning lists of nodes
#       => must run after NormalizeTree (otherwise single statements might not be held in a list)
#
class CypclassWrapperInjection(VisitorTransform):
    """
        Synthesize and insert a wrapper c class at the module level for each cypclass that supports it.
        - Even nested cypclasses have their wrapper at the module level.
        - Must run after NormalizeTree.
    """
    def __call__(self, root):
        self.cypclass_wrappers_stack = []
        self.nesting_stack = []
        return super(CypclassWrapperInjection, self).__call__(root)

    def visit_Node(self, node):
        self.visitchildren(node)
        return node

    # TODO: can cypclasses be nested in something other than this ?
    # can cypclasses even be nested in non-cypclass cpp classes, or structs ?
    def visit_CStructOrUnionDefNode(self, node):
        self.nesting_stack.append(node)
        self.visitchildren(node)
        self.nesting_stack.pop()
        top_level = not self.nesting_stack
        if top_level:
            return_nodes = [node]
            for wrapper in self.cypclass_wrappers_stack:
                return_nodes.append(wrapper)
            self.cypclass_wrappers_stack.clear()
            return return_nodes
        return node

    def visit_CppClassNode(self, node):
        if node.cypclass:
            wrapper = self.synthesize_wrapper_cclass(node)
            if wrapper is not None:
                self.cypclass_wrappers_stack.append(wrapper)
        # visit children and return all wrappers when at the top level
        return self.visit_CStructOrUnionDefNode(node)

    def find_module_scope(self, scope):
        module_scope = scope
        while module_scope and not module_scope.is_module_scope:
            module_scope = module_scope.outer_scope
        return module_scope
    
    def iter_wrapper_methods(self, wrapper_cclass):
        for node in wrapper_cclass.body.stats:
            if isinstance(node, Nodes.DefNode):
                yield node
    
    def synthesize_wrapper_cclass(self, node):
        if node.templates:
            # Python wrapper for templated cypclasses not supported yet
            # this is signaled to the compiler by not doing what is below
            return None

        # whether the is declared with ':' and a suite, or just a forward declaration
        node_has_suite = node.attributes is not None

        if not node_has_suite:
            return None
        
        # TODO: take nesting into account for the name
        cclass_name = EncodedString("%s_cyp_wrapper" % node.name)

        from .ExprNodes import TupleNode
        cclass_bases = TupleNode(node.pos, args=[])

        # the underlying cyobject must come first thing after PyObject_HEAD in the memory layout
        # long term, only the base class will declare the underlying attribute
        underlying_cyobject = self.synthesize_underlying_cyobject_attribute(node)
        stats = [underlying_cyobject]
        cclass_body = Nodes.StatListNode(pos=node.pos, stats=stats)
        cclass_doc = EncodedString("Python Object wrapper for underlying cypclass %s" % node.name)

        wrapper = Nodes.CClassDefNode(
            node.pos,
            visibility = 'private',
            typedef_flag = 0,
            api = 0,
            module_name = "",
            class_name = cclass_name,
            as_name = cclass_name,
            bases = cclass_bases,
            objstruct_name = None,
            typeobj_name = None,
            check_size = None,
            in_pxd = node.in_pxd,
            doc = cclass_doc,
            body = cclass_body,
            is_cyp_wrapper = 1
        )

        node.cyp_wrapper = wrapper
        return wrapper
    
    def synthesize_underlying_cyobject_attribute(self, node):
        nested_names = [node.name for node in self.nesting_stack]

        underlying_base_type = Nodes.CSimpleBaseTypeNode(
            node.pos,
            name = node.name,
            module_path = nested_names,
            is_basic_c_type = 0,
            signed = 1,
            complex = 0,
            longness = 0,
            is_self_arg = 0,
            templates = None
        )

        underlying_name_declarator = Nodes.CNameDeclaratorNode(node.pos, name=underlying_name, cname=None)

        underlying_cyobject = Nodes.CVarDefNode(
            pos = node.pos,
            visibility = 'private',
            base_type = underlying_base_type,
            declarators = [underlying_name_declarator],
            in_pxd = node.in_pxd,
            doc = None,
            api = 0,
            modifiers = [],
            overridable = 0
        )

        return underlying_cyobject

#
#   Post declaration analysis visitor for wrapped cypclasses
#
#   - Associate the type of the wrapper cclass to the wrapped type
#       => must run after AnalyseDeclarationsTransform
#
class CypclassPostDeclarationsVisitor(CythonTransform):
    """
        Associate the type of each wrapper cclass to the wrapped type.
        - Must run after the declarations analysis phase.
    """
    # associate the type of the wrapper cclass to the type of the wrapped cypclass
    def visit_CppClassNode(self, node):
        if node.cypclass and node.cyp_wrapper:
            node.entry.type.wrapper_type = node.cyp_wrapper.entry.type
        self.visitchildren(node)
        return node




#
#   Cypclass code generation
#
#   - originally authored by Gwenaël Samain
#   - moved here from ModuleNode.py
#

def generate_cyp_class_deferred_definitions(env, code, definition):
    """
        Generate all cypclass method definitions, deferred till now
    """

    for entry, scope in cypclass_iter_scopes(env):
        if definition or entry.defined_in_pxd:
            if entry.type.activable:
                # Generate acthon-specific classes
                generate_cyp_class_reifying_entries(entry, code)
                generate_cyp_class_activated_class(entry, code)
                generate_cyp_class_activate_function(entry, code)
            # Generate cypclass attr destructor
            generate_cyp_class_attrs_destructor_definition(entry, code)
            # Generate wrapper constructor
            wrapper = scope.lookup_here("<constructor>")
            constructor = scope.lookup_here("<init>")
            new = scope.lookup_here("__new__")
            alloc = scope.lookup_here("<alloc>")
            for wrapper_entry in wrapper.all_alternatives():
                generate_cyp_class_wrapper_definition(entry.type, wrapper_entry, constructor, new, alloc, code)

def generate_cyp_class_attrs_destructor_definition(entry, code):
    """
        Generate destructor definition for the given cypclass entry
    """

    scope = entry.type.scope
    cypclass_attrs = [e for e in scope.var_entries
                    if e.type.is_cyp_class and not e.name == "this"
                    and not e.is_type]
    if cypclass_attrs:
        cypclass_attrs_destructor_name = "%s__cypclass_attrs_destructor__%s" % (Naming.func_prefix, entry.name)
        destructor_with_namespace = "void %s::%s()" % (entry.type.empty_declaration_code(), cypclass_attrs_destructor_name)
        code.putln(destructor_with_namespace)
        code.putln("{")
        for attr in cypclass_attrs:
            code.putln("Cy_XDECREF(this->%s);" % attr.cname)
        code.putln("}")


def generate_cyp_class_activate_function(entry, code):
    """
        Generate activate function for activable cypclass entries
    """

    active_self_entry = entry.type.scope.lookup_here("<active_self>")
    dunder_activate_entry = entry.type.scope.lookup_here("__activate__")
    # Here we generate the function header like Nodes.CFuncDefNode would do,
    # but we streamline the process because we know the exact prototype.
    dunder_activate_arg = dunder_activate_entry.type.op_arg_struct.declaration_code(Naming.optional_args_cname)
    dunder_activate_entity = dunder_activate_entry.type.function_header_code(dunder_activate_entry.func_cname, dunder_activate_arg)
    dunder_activate_header = dunder_activate_entry.type.return_type.declaration_code(dunder_activate_entity)
    code.putln("%s {" % dunder_activate_header)
    code.putln("%s;" % dunder_activate_entry.type.return_type.declaration_code("activated_instance"))
    code.putln('if (%s) {' % Naming.optional_args_cname)
    activated_class_constructor_optargs_list = ["this"]
    activated_class_constructor_defaultargs_list = ["this->_active_queue_class", "this->_active_result_class"]
    for i, arg in enumerate(dunder_activate_entry.type.args):
        code.putln("if (%s->%sn <= %s) {" %
                    (Naming.optional_args_cname,
                    Naming.pyrex_prefix, i))
        code.putln("activated_instance = new %s::Activated(%s);" %
                    (entry.type.empty_declaration_code(),
                    ", ".join(activated_class_constructor_optargs_list + activated_class_constructor_defaultargs_list[i:])))
        code.putln("} else {")
        activated_class_constructor_optargs_list.append("%s->%s" %
                                                        (Naming.optional_args_cname,
                                                        dunder_activate_entry.type.opt_arg_cname(arg.name)))
    # We're in the final else clause, corresponding to all optional arguments specified)
    code.putln("activated_instance = new %s::Activated(%s);" %
                (entry.type.empty_declaration_code(),
                ", ".join(activated_class_constructor_optargs_list)))
    for _ in dunder_activate_entry.type.args:
        code.putln("}")
    code.putln("}")
    code.putln("else {")
    code.putln("if (this->%s == NULL) {" % active_self_entry.cname)
    code.putln("this->%s = new %s::Activated(this, %s);" %
                (active_self_entry.cname,
                entry.type.empty_declaration_code(),
                ", ".join(activated_class_constructor_defaultargs_list))
                )
    code.putln("}")
    code.putln("Cy_INCREF(this->%s);" % active_self_entry.cname)
    code.putln("activated_instance = this->%s;" % active_self_entry.cname)
    code.putln("}")
    code.putln("return activated_instance;")
    code.putln("}")


def generate_cyp_class_activated_class(entry, code):
    """
        Generate activated class
    """

    from . import Builtin
    sync_interface_type = Builtin.acthon_sync_type
    result_interface_type = Builtin.acthon_result_type
    queue_interface_type = Builtin.acthon_queue_type

    result_attr_cname = "_active_result_class"
    queue_attr_cname = "_active_queue_class"
    passive_self_attr_cname = Naming.builtin_prefix + entry.type.empty_declaration_code().replace('::', '__') + "_passive_self"

    activable_bases_cnames = [base.cname for base in entry.type.base_classes if base.activable]
    activable_bases_inheritance_list = ["public %s::Activated" % cname for cname in activable_bases_cnames]
    if activable_bases_cnames:
        base_classes_code = ", ".join(activable_bases_inheritance_list)
        initialize_code = ", ".join([
            "%s::Activated(passive_object, active_queue, active_result_constructor)" % cname
            for cname in activable_bases_cnames
        ])
    else:
        base_classes_code = "public ActhonActivableClass"
        initialize_code = "ActhonActivableClass(active_queue, active_result_constructor)"
    code.putln("struct %s::Activated : %s {" % (entry.type.empty_declaration_code(), base_classes_code))
    code.putln("%s;" % entry.type.declaration_code(passive_self_attr_cname))
    code.putln(("Activated(%s * passive_object, %s, %s)"
                ": %s, %s(passive_object){} // Used by _passive_self.__activate__()"
                % (
                    entry.type.empty_declaration_code(),
                    queue_interface_type.declaration_code("active_queue"),
                    entry.type.scope.lookup_here("__activate__").type.args[1].type.declaration_code("active_result_constructor"),
                    initialize_code,
                    passive_self_attr_cname
                    )
    ))
    for reifying_class_entry in entry.type.scope.reifying_entries:
        reified_function_entry = reifying_class_entry.reified_entry
        code.putln("// generating reified of %s" % reified_function_entry.name)
        reified_arg_cname_list = []
        reified_arg_decl_list = []

        for i in range(len(reified_function_entry.type.args)-reified_function_entry.type.optional_arg_count):
            arg = reified_function_entry.type.args[i]
            reified_arg_cname_list.append(arg.cname)
            reified_arg_decl_list.append(arg.type.declaration_code(arg.cname))

        if reified_function_entry.type.optional_arg_count:
            opt_cname = Naming.optional_args_cname
            reified_arg_cname_list.append(opt_cname)
            reified_arg_decl_list.append(reified_function_entry.type.op_arg_struct.declaration_code(opt_cname))

        activated_method_arg_decl_code = ", ".join([sync_interface_type.declaration_code("sync_object")] + reified_arg_decl_list)
        function_header = reified_function_entry.type.function_header_code(reified_function_entry.cname, activated_method_arg_decl_code)
        function_code = result_interface_type.declaration_code(function_header)
        code.putln("%s {" % function_code)
        code.putln("%s = this->%s();" % (result_interface_type.declaration_code("result_object"), result_attr_cname))

        message_constructor_args_list = ["this->%s" % passive_self_attr_cname, "sync_object", "result_object"] + reified_arg_cname_list
        message_constructor_args_code = ", ".join(message_constructor_args_list)
        code.putln("%s = new %s(%s);" % (
            reifying_class_entry.type.declaration_code("message"),
            reifying_class_entry.type.empty_declaration_code(),
            message_constructor_args_code
        ))

        code.putln("/* Push message in the queue */")
        code.putln("if (this->%s != NULL) {" % queue_attr_cname)
        code.putln("Cy_WLOCK(%s);" % queue_attr_cname)
        code.putln("this->%s->push(message);" % queue_attr_cname)
        code.putln("Cy_UNLOCK(%s);" % queue_attr_cname)
        code.putln("} else {")
        code.putln("/* We should definitely shout here */")
        code.putln('fprintf(stderr, "Acthon error: No queue to push to for %s remote call !\\n");' % reified_function_entry.name)
        code.putln("}")
        code.putln("Cy_DECREF(message);")
        code.putln("/* Return result object */")
        code.putln("return result_object;")
        code.putln("}")
    code.putln("};")

def generate_cyp_class_reifying_entries(entry, code):
    """
        Generate code to reify the cypclass entry ? -> TODO what does this do exactly ?
    """

    target_object_type = entry.type
    target_object_cname = Naming.builtin_prefix + "target_object"
    target_object_code = target_object_type.declaration_code(target_object_cname)
    sync_arg_name = "sync_method"
    result_arg_name = "result_object"

    from . import Builtin
    message_base_type = Builtin.acthon_message_type
    sync_type = Builtin.acthon_sync_type
    result_type = Builtin.acthon_result_type

    sync_attr_cname = message_base_type.scope.lookup_here("_sync_method").cname
    result_attr_cname = message_base_type.scope.lookup_here("_result").cname

    def put_cypclass_op_on_narg_optarg(op_lbda, func_type, opt_arg_name, code):
        opt_arg_count = func_type.optional_arg_count
        narg_count = len(func_type.args) - opt_arg_count
        for narg in func_type.args[:narg_count]:
            if narg.type.is_cyp_class:
                code.putln("%s(this->%s);" % (op_lbda(narg), narg.cname))

        if opt_arg_count:
            opt_arg_guard = code.insertion_point()
            code.increase_indent()
            num_if = 0
            for opt_idx, optarg in enumerate(func_type.args[narg_count:]):
                if optarg.type.is_cyp_class:
                    code.putln("if (this->%s->%sn > %s) {" %
                                    (opt_arg_name,
                                    Naming.pyrex_prefix,
                                    opt_idx
                    ))
                    code.putln("%s(this->%s->%s);" %
                                    (op_lbda(optarg),
                                    opt_arg_name,
                                    func_type.opt_arg_cname(optarg.name)
                    ))
                    num_if += 1
            for _ in range(num_if):
                code.putln("}")
            if num_if:
                opt_arg_guard.putln("if (this->%s != NULL) {" % opt_arg_name)
                code.putln("}")
            else:
                code.decrease_indent()

    for reifying_class_entry in entry.type.scope.reifying_entries:
        reified_function_entry = reifying_class_entry.reified_entry
        reifying_class_full_name = reifying_class_entry.type.empty_declaration_code()
        class_name = reifying_class_full_name.split('::')[-1]
        code.putln("struct %s : public %s {" % (reifying_class_full_name, message_base_type.empty_declaration_code()))
        # Declaring target object & reified method arguments
        code.putln("%s;" % target_object_code)
        constructor_args_decl_list = [
            target_object_code,
            sync_type.declaration_code(sync_arg_name),
            result_type.declaration_code(result_arg_name)
        ]
        initialized_args_list = [target_object_cname]
        opt_arg_count = reified_function_entry.type.optional_arg_count

        for i in range(len(reified_function_entry.type.args) - opt_arg_count):
            arg = reified_function_entry.type.args[i]
            arg_cname_code = arg.type.declaration_code(arg.cname)
            code.putln("%s;" % arg_cname_code)
            constructor_args_decl_list.append(arg_cname_code)
            initialized_args_list.append(arg.cname)

        if opt_arg_count:
            # We cannot initialize the struct before allocating memory, so
            # it must be handled in constructor body, not initializer list
            opt_decl_code = reified_function_entry.type.op_arg_struct.declaration_code(Naming.optional_args_cname)
            code.putln("%s;" % opt_decl_code)
            constructor_args_decl_list.append(opt_decl_code)

        # Putting them into constructor
        constructor_args_decl_code = ", ".join(constructor_args_decl_list)
        initializer_list = ["%s(%s)" % (name, name) for name in initialized_args_list]
        initializer_list_code = ", ".join(initializer_list)

        code.putln("%s(%s) : %s(%s, %s), %s {" % (
            class_name,
            constructor_args_decl_code,
            message_base_type.empty_declaration_code(),
            sync_arg_name,
            result_arg_name,
            initializer_list_code
        ))
        if opt_arg_count:
            mem_size = "sizeof(%s)" % reified_function_entry.type.op_arg_struct.base_type.empty_declaration_code()
            code.putln("if (%s != NULL) {" % Naming.optional_args_cname)
            code.putln("this->%s = (%s) malloc(%s);" % (
                Naming.optional_args_cname,
                reified_function_entry.type.op_arg_struct.empty_declaration_code(),
                mem_size
            ))
            code.putln("memcpy(this->%s, %s, %s);" % (
                Naming.optional_args_cname,
                Naming.optional_args_cname,
                mem_size
            ))
            code.putln("} else {")
            code.putln("this->%s = NULL;" % Naming.optional_args_cname)
            code.putln("}")

        # Acquire a ref on CyObject, as we don't know when the message will be processed
        put_cypclass_op_on_narg_optarg(lambda _: "Cy_INCREF", reified_function_entry.type, Naming.optional_args_cname, code)
        code.putln("Cy_INCREF(this->%s);" % target_object_cname)
        code.putln("}")
        code.putln("int activate() {")
        sync_result = "sync_result"
        code.putln("int %s = 0;" % sync_result)
        code.putln("/* Activate only if its sync object agrees to do so */")
        code.putln("if (this->%s != NULL) {" % sync_attr_cname)
        code.putln("if (!Cy_TRYRLOCK(this->%s)) {" % sync_attr_cname)
        code.putln("%s = this->%s->isActivable();" % (sync_result, sync_attr_cname))
        code.putln("Cy_UNLOCK(this->%s);" % sync_attr_cname)
        code.putln("}")
        code.putln("if (%s == 0) return 0;" % sync_result)
        code.putln("}")
        result_assignment = ""

        # Drop the target_object argument to perform the actual method call
        reified_call_args_list = initialized_args_list[1:]
        if opt_arg_count:
            reified_call_args_list.append(Naming.optional_args_cname)

        # Locking CyObjects
        # Here we completely ignore the lock mode (nolock/checklock/autolock)
        # because the mode is used for direct calls, when the user have the possibility
        # to manually lock or let the compiler handle it.
        # Here, the user cannot lock manually, so we're taking the lock automatically.
        #put_cypclass_op_on_narg_optarg(lambda arg: "Cy_RLOCK" if arg.type.is_const else "Cy_WLOCK",
        #                               reified_function_entry.type, Naming.optional_args_cname, code)

        func_type = reified_function_entry.type
        opt_arg_name = Naming.optional_args_cname
        trylock_result = "trylock_result"
        failed_trylock = "failed_trylock"
        code.putln("int %s = 0;" % trylock_result)
        code.putln("int %s = 0;" % failed_trylock)
        opt_arg_count = func_type.optional_arg_count
        narg_count = len(func_type.args) - opt_arg_count
        num_trylock = 1

        op = "Cy_TRYRLOCK" if reified_function_entry.type.is_const_method else "Cy_TRYWLOCK"
        code.putln("%s = %s(this->%s) != 0;" % (failed_trylock, op, target_object_cname))
        code.putln("if (!%s) {" % failed_trylock)
        code.putln("++%s;" % trylock_result)

        for i, narg in enumerate(func_type.args[:narg_count]):
            if narg.type.is_cyp_class:
                try_op = "Cy_TRYRLOCK" if narg.type.is_const else "Cy_TRYWLOCK"
                code.putln("%s = %s(this->%s) != 0;" % (failed_trylock, try_op, narg.cname))
                code.putln("if (!%s) {" % failed_trylock)
                code.putln("++%s;" % trylock_result)
                num_trylock += 1

        num_optional_if = 0
        if opt_arg_count:
            opt_arg_guard = code.insertion_point()
            code.increase_indent()
            for opt_idx, optarg in enumerate(func_type.args[narg_count:]):
                if optarg.type.is_cyp_class:
                    try_op = "Cy_TRYRLOCK" if optarg.type.is_const else "Cy_TRYWLOCK"
                    code.putln("if (this->%s->%sn > %s) {" %
                                    (opt_arg_name,
                                    Naming.pyrex_prefix,
                                    opt_idx,
                    ))
                    code.putln("%s = %s(this->%s->%s) != 0;" % (
                                failed_trylock,
                                try_op,
                                opt_arg_name,
                                func_type.opt_arg_cname(optarg.name)
                    ))
                    code.putln("if (!%s) {" % failed_trylock)
                    code.putln("++%s;" % trylock_result)
                    num_optional_if += 1
                    num_trylock += 1
            for _ in range(num_optional_if):
                code.putln("}")
            if num_optional_if > 0:
                opt_arg_guard.putln("if (this->%s != NULL) {" % opt_arg_name)
                code.putln("}") # The check for optional_args != NULL
            else:
                code.decrease_indent()
        for _ in range(num_trylock):
            code.putln("}")

        if num_trylock:
            # If there is any lock failure, we unlock all and return 0
            code.putln("if (%s) {" % failed_trylock)
            num_unlock = 0
            # Target object first, then arguments
            code.putln("if (%s > %s) {" % (trylock_result, num_unlock))
            code.putln("Cy_UNLOCK(this->%s);" % target_object_cname)
            num_unlock += 1
            for i, narg in enumerate(func_type.args[:narg_count]):
                if narg.type.is_cyp_class:
                    code.putln("if (%s > %s) {" % (trylock_result, num_unlock))
                    code.putln("Cy_UNLOCK(this->%s);" % narg.cname)
                    num_unlock += 1
            if opt_arg_count and num_optional_if:
                code.putln("if (this->%s != NULL) {" % opt_arg_name)
                for opt_idx, optarg in enumerate(func_type.args[narg_count:]):
                    if optarg.type.is_cyp_class:
                        code.putln("if (%s > %s) {" % (trylock_result, num_unlock))
                        code.putln("Cy_UNLOCK(this->%s->%s);" % (opt_arg_name, func_type.opt_arg_cname(optarg.name)))
                        num_unlock += 1
                # Note: we do not respect the semantic order of end-blocks here for simplification purpose.
                # This one is for the "not NULL opt arg" check
                code.putln("}")
            # These ones are all the checks for mandatory and optional arguments
            for _ in range(num_unlock):
                code.putln("}")
            code.putln("return 0;")
            code.putln("}")

        does_return = reified_function_entry.type.return_type is not PyrexTypes.c_void_type
        if does_return:
            result_assignment = "%s = " % reified_function_entry.type.return_type.declaration_code("result")
        code.putln("%sthis->%s->%s(%s);" % (
            result_assignment,
            target_object_cname,
            reified_function_entry.cname,
            ", ".join("this->%s" % arg_cname for arg_cname in reified_call_args_list)
            )
        )
        code.putln("Cy_UNLOCK(this->%s);" % target_object_cname)
        put_cypclass_op_on_narg_optarg(lambda _: "Cy_UNLOCK", reified_function_entry.type, Naming.optional_args_cname, code)
        code.putln("/* Push result in the result object */")
        if does_return:
            code.putln("Cy_WLOCK(this->%s);" % result_attr_cname)
            if reified_function_entry.type.return_type is PyrexTypes.c_int_type:
                code.putln("this->%s->pushIntResult(result);" % result_attr_cname)
            else:
                code.putln("this->%s->pushVoidStarResult((void*)result);" % result_attr_cname)
            code.putln("Cy_UNLOCK(this->%s);" % result_attr_cname)
        code.putln("return 1;")
        code.putln("}")

        # Destructor
        code.putln("virtual ~%s() {" % class_name)
        code.putln("Cy_DECREF(this->%s);" % target_object_cname)
        put_cypclass_op_on_narg_optarg(lambda _: "Cy_DECREF", reified_function_entry.type, Naming.optional_args_cname, code)
        if opt_arg_count:
            code.putln("free(this->%s);" % Naming.optional_args_cname)
        code.putln("}")
        code.putln("};")

def generate_cyp_class_wrapper_definition(type, wrapper_entry, constructor_entry, new_entry, alloc_entry, code):
    """
        Generate cypclass constructor wrapper ? -> TODO what does this do exactly ?
    """

    if type.templates:
            code.putln("template <typename %s>" % ", class ".join(
                [T.empty_declaration_code() for T in type.templates]))

    init_entry = constructor_entry
    self_type = wrapper_entry.type.return_type.declaration_code('')
    type_string = type.empty_declaration_code()
    class_name = type.name
    wrapper_cname = "%s::%s__constructor__%s" % (type_string, Naming.func_prefix, class_name)
    wrapper_type = wrapper_entry.type

    arg_decls = []
    arg_names = []
    for arg in wrapper_type.args[:len(wrapper_type.args)-wrapper_type.optional_arg_count]:
        arg_decl = arg.declaration_code()
        arg_decls.append(arg_decl)
        arg_names.append(arg.cname)

    if wrapper_type.optional_arg_count:
        arg_decls.append(wrapper_type.op_arg_struct.declaration_code(Naming.optional_args_cname))
        arg_names.append(Naming.optional_args_cname)
    if wrapper_type.has_varargs:
        # We can't safely handle varargs because we need
        # to know where the size argument is to start a va_list
        error(wrapper_entry.pos,
        "Cypclass cannot handle variable arguments constructors, but you can use optional arguments (arg=some_value)")
    if not arg_decls:
        arg_decls = ["void"]

    decl_arg_string = ', '.join(arg_decls)
    code.putln("%s %s(%s)" % (self_type, wrapper_cname, decl_arg_string))
    code.putln("{")

    wrapper_arg_types = [arg.type for arg in wrapper_entry.type.args]
    pos = wrapper_entry.pos or type.entry.pos

    if new_entry:
        alloc_type = alloc_entry.type
        new_arg_types = [alloc_type] + wrapper_arg_types

        new_entry = PyrexTypes.best_match(new_arg_types,
            new_entry.all_alternatives(), pos)

        if new_entry:
            alloc_call_string = "(" + new_entry.type.original_alloc_type.type.declaration_code("") + ") %s" % alloc_entry.func_cname
            new_arg_names = [alloc_call_string] + arg_names
            new_arg_string = ', '.join(new_arg_names)
            code.putln("%s self =(%s) %s(%s);" % (self_type, self_type, new_entry.func_cname, new_arg_string))
    else:
        code.putln("%s self = %s();" % (self_type, alloc_entry.func_cname))

    # __new__ can be defined by user and return another type
    is_new_return_type = not new_entry or new_entry.type.return_type == type

    # initialise PyObject fields
    if is_new_return_type and type.wrapper_type:
        objstruct_cname = type.wrapper_type.objstruct_cname
        code.putln("if(self) {")
        code.putln("%s * wrapper = new %s();" % (objstruct_cname, objstruct_cname))
        code.putln("wrapper->nogil_cyobject = self;")
        code.putln("PyObject * wrapper_as_py = (PyObject *) wrapper;")
        code.putln("wrapper_as_py->ob_refcnt = 0;")
        code.putln("wrapper_as_py->ob_type = %s;" % type.wrapper_type.typeptr_cname)
        code.putln("self->cy_pyobject = wrapper_as_py;")
        code.putln("}")

    if init_entry:
        init_entry = PyrexTypes.best_match(wrapper_arg_types,
        init_entry.all_alternatives(), None)
    if init_entry and (is_new_return_type):
        # Calling __init__

        max_init_nargs = len(init_entry.type.args)
        min_init_nargs = max_init_nargs - init_entry.type.optional_arg_count
        max_wrapper_nargs = len(wrapper_entry.type.args)
        min_wrapper_nargs =  max_wrapper_nargs - wrapper_entry.type.optional_arg_count

        if min_init_nargs == min_wrapper_nargs:
            # The optional arguments begin at the same rank for both function
            # => just pass the wrapper opt args structure, and everything will be fine.
            if max_wrapper_nargs > min_wrapper_nargs:
                # The wrapper has optional args
                arg_names[-1] = "(%s) %s" % (init_entry.type.op_arg_struct.declaration_code(''), arg_names[-1])
            elif max_init_nargs > min_init_nargs:
                # The wrapper has no optional args but the __init__ function does
                arg_names.append("(%s) NULL" % init_entry.type.op_arg_struct.declaration_code(''))
            # else, neither __init__ nor __new__ have optional arguments, nothing to do
        elif min_wrapper_nargs < min_init_nargs:
            # It means some args from the wrapper should be at
            # their default values, which we cannot know from here,
            # so shout and stop, sadly.
            error(init_entry.pos, "Could not call this __init__ function because the corresponding __new__ wrapper isn't aware of default values")
            error(wrapper_entry.pos, "Wrapped __new__ is here (some args passed to __init__ could be at their default values)")
        elif min_wrapper_nargs > min_init_nargs:
            # Here, the __init__ optional arguments start before
            # the __new__ ones. We have to unpack the __new__ opt args struct
            # in some variables and then repack in the __init__ opt args struct.

            init_opt_args_name_list = [arg.cname for arg in wrapper_entry.type.args[min_init_nargs:]]

            # The first __init__ optional arguments are mandatory
            # in the __new__ signature, so they will always appear
            # in the __init__ optional arguments structure
            init_opt_args_number = "init_opt_n"
            code.putln("int %s = %s;" % (init_opt_args_number, min_wrapper_nargs - min_init_nargs))

            if wrapper_entry.type.optional_arg_count:
                for i, arg in enumerate(wrapper_entry.type.args[min_wrapper_nargs:]):
                    # It's an opt arg => it's not declared in the (c++) function scope => declare a variable for it
                    arg_name = arg.cname
                    code.putln("%s;" % arg.type.declaration_code(arg_name))

                # Arguments unpacking
                optional_struct_name = arg_names.pop()
                code.putln("if (%s) {" % optional_struct_name)

                # This is necessary to keep __init__ informed of
                # how many optional arguments were explicitely given
                code.putln("%s += %s->%sn;" % (init_opt_args_number, optional_struct_name, Naming.pyrex_prefix))

                braces_number = 1 + max_wrapper_nargs - min_wrapper_nargs
                for i, arg in enumerate(wrapper_entry.type.args[min_wrapper_nargs:]):
                    code.putln("if(%s->%sn > %s) {" % (optional_struct_name, Naming.pyrex_prefix, i))
                    code.putln("%s = %s->%s;" % (
                        arg.cname,
                        optional_struct_name,
                        wrapper_entry.type.op_arg_struct.base_type.scope.var_entries[i+1].cname
                    ))
                for _ in range(braces_number):
                    code.putln('}')

            # Arguments packing
            init_opt_args_struct_name = "init_opt_args"
            code.putln("%s;" % init_entry.type.op_arg_struct.base_type.declaration_code(init_opt_args_struct_name))
            code.putln("%s.%sn = %s;" % (init_opt_args_struct_name, Naming.pyrex_prefix, init_opt_args_number))
            for i, arg_name in enumerate(init_opt_args_name_list):
                # The second tuple member is a bit tricky.
                # Actually, the only way we have to precisely know the attribute cname
                # which corresponds to the argument in the opt args struct
                # is to rely on the declaration order in the struct scope.
                # FuncDefNode doesn't do this because it has it's declarator node,
                # which is not our case here.
                code.putln("%s.%s = %s;" % (
                    init_opt_args_struct_name,
                    init_entry.type.opt_arg_cname(init_entry.type.args[min_init_nargs+i].name),
                    arg_name
                ))
            arg_names = arg_names[:min_init_nargs] + ["&"+init_opt_args_struct_name]

        init_arg_string = ','.join(arg_names)
        code.putln("self->%s(%s);" % (init_entry.cname, init_arg_string))
    code.putln("return self;")
    code.putln("}")

