#
#   Cypclass transforms
#


from __future__ import absolute_import

import cython
cython.declare(Naming=object, PyrexTypes=object, EncodedString=object, error=object)

from collections import defaultdict

from . import Naming
from . import Nodes
from . import PyrexTypes
from . import ExprNodes
from . import Visitor
from . import TreeFragment

from .StringEncoding import EncodedString
from .ParseTreeTransforms import NormalizeTree, InterpretCompilerDirectives, DecoratorTransform, AnalyseDeclarationsTransform
from .Errors import error

#
#   Visitor for wrapper cclass injection
#
#   - Insert additional cclass wrapper nodes by returning lists of nodes
#       => must run after NormalizeTree (otherwise single statements might not be held in a list)
#
class CypclassWrapperInjection(Visitor.CythonTransform):
    """
        Synthesize and insert a wrapper c class at the module level for each cypclass that supports it.
        - Even nested cypclasses have their wrapper at the module level.
        - Must run after NormalizeTree.
        - The root node passed when calling this visitor should not be lower than a ModuleNode.
    """

    # property templates
    property_template = TreeFragment.TreeFragment(u"""
property NAME:
    def __get__(self):
        OBJ = <TYPE> self
        return OBJ.ATTR
    def __set__(self, value):
        OBJ = <TYPE> self
        OBJ.ATTR = value
    """, level='c_class', pipeline=[NormalizeTree(None)])

    # method wrapper templates
    method_template = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    return OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    method_no_return_template = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    # static method wrapper templates
    static_template = TreeFragment.TreeFragment(u"""
@staticmethod
def NAME(ARGDECLS):
    return TYPE_NAME.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    static_no_return_template = TreeFragment.TreeFragment(u"""
@staticmethod
def NAME(ARGDECLS):
    TYPE_NAME.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    def __call__(self, root):
        self.pipeline = [
            InterpretCompilerDirectives(self.context, self.context.compiler_directives),
            DecoratorTransform(self.context),
            AnalyseDeclarationsTransform(self.context)
        ]
        return super(CypclassWrapperInjection, self).__call__(root)

    def visit_ExprNode(self, node):
        # avoid visiting sub expressions
        return node

    def visit_ModuleNode(self, node):
        self.collected_cypclasses = []
        self.wrappers = []
        self.type_to_names = {}
        self.base_type_to_deferred = defaultdict(list)
        self.synthesized = set()
        self.nesting_stack = []
        self.module_scope = node.scope
        self.visitchildren(node)
        self.inject_cypclass_wrappers(node)
        return node

    # TODO: can cypclasses be nested in something other than this ?
    # can cypclasses even be nested in non-cypclass cpp classes, or structs ?
    def visit_CStructOrUnionDefNode(self, node):
        self.nesting_stack.append(node)
        self.visitchildren(node)
        self.nesting_stack.pop()
        return node

    def visit_CppClassNode(self, node):
        if node.cypclass:
            self.collect_cypclass(node)
        # visit children and keep track of nesting
        return self.visit_CStructOrUnionDefNode(node)

    def collect_cypclass(self, node):
        if node.templates:
            # Python wrapper for templated cypclasses not supported yet
            return

        if node.attributes is None:
            # skip forward declarations
            return

        if node.entry.defined_in_pxd:
            # Skip cypclasses defined in a pxd file
            return

        new_entry = node.scope.lookup_here("__new__")
        if new_entry and new_entry.type.return_type is not node.entry.type:
            # skip cypclasses that don't instanciate their own type
            return

        # indicate that the cypclass will have a wrapper
        node.entry.type.support_wrapper = True

        self.derive_names(node)
        self.collected_cypclasses.append(node)

    def create_unique_name(self, name, entries=None):
        # output: name(_u_*)?
        # guarantees:
        # - different inputs always result in different outputs
        # - the output is not among the given entries
        # if entries is None, the module scope entries are used
        unique_name = name
        entries = self.module_scope.entries if entries is None else entries
        if unique_name in entries:
            unique_name = "%s_u" % unique_name
        while unique_name in entries:
            unique_name = "%s_" % unique_name
        return EncodedString(unique_name)

    def derive_names(self, node):
        nested_names = [node.name for node in self.nesting_stack]
        nested_names.append(node.name)

        qualified_name = ".".join(nested_names)
        qualified_name = EncodedString(qualified_name)

        nested_name = "_".join(nested_names)

        cclass_name = self.create_unique_name("%s_cyp_cclass_wrapper" % nested_name)

        self.type_to_names[node.entry.type] = qualified_name, cclass_name

    def inject_cypclass_wrappers(self, module_node):
        for collected in self.collected_cypclasses:
            self.synthesize_wrappers(collected)

        # only a shallow copy: retains the same scope etc
        fake_module_node = module_node.clone_node()
        fake_module_node.body = Nodes.StatListNode(
            module_node.body.pos,
            stats = self.wrappers
        )

        for phase in self.pipeline:
            fake_module_node = phase(fake_module_node)

        module_node.body.stats.extend(fake_module_node.body.stats)

    def synthesize_wrappers(self, node):
        node_type = node.entry.type

        for wrapped_base_type in node_type.iter_wrapped_base_types():
            if wrapped_base_type not in self.synthesized:
                self.base_type_to_deferred[wrapped_base_type].append(lambda: self.synthesize_wrappers(node))
                return

        qualified_name, cclass_name = self.type_to_names[node_type]

        cclass = self.synthesize_wrapper_cclass(node, cclass_name, qualified_name)

        # mark this cypclass as having synthesized wrappers
        self.synthesized.add(node_type)

        # forward declare the cclass wrapper
        cclass.declare(self.module_scope)

        self.wrappers.append(cclass)

        # synthesize deferred dependent subclasses
        for thunk in self.base_type_to_deferred[node_type]:
            thunk()

    def synthesize_base_tuple(self, node):
        node_type = node.entry.type

        bases_args = []

        for base in node_type.iter_wrapped_base_types():
            bases_args.append(ExprNodes.NameNode(node.pos, name=base.wrapper_type.name))

        return ExprNodes.TupleNode(node.pos, args=bases_args)

    def synthesize_wrapper_cclass(self, node, cclass_name, qualified_name):

        cclass_bases = self.synthesize_base_tuple(node)

        stats = []

        # insert method wrappers in the statement list
        self.insert_cypclass_method_wrappers(node, cclass_name, stats)

        cclass_body = Nodes.StatListNode(pos=node.pos, stats=stats)

        cclass_doc = EncodedString("Python Object wrapper for underlying cypclass %s" % qualified_name)

        wrapper = Nodes.CypclassWrapperDefNode(
            node.pos,
            visibility = 'private',
            typedef_flag = 0,
            api = 0,
            module_name = "",
            class_name = cclass_name,
            as_name = cclass_name,
            bases = cclass_bases,
            objstruct_name = Naming.cypclass_wrapper_layout_type,
            typeobj_name = None,
            check_size = None,
            in_pxd = node.in_pxd,
            doc = cclass_doc,
            body = cclass_body,
            wrapped_cypclass = node,
            wrapped_nested_name = qualified_name
        )

        return wrapper

    def insert_cypclass_method_wrappers(self, node, cclass_name, stats):
        for attr in node.scope.entries.values():

            if attr.is_cfunction:
                alternatives = attr.all_alternatives()

                # > consider the alternatives that are actually defined in this wrapped cypclass
                local_alternatives = [e for e in alternatives if e.mro_index == 0]
                if len(local_alternatives) == 0:
                    # all alternatives are inherited, skip this method
                    continue

                if len(alternatives) > 1:
                    py_args_alternatives = [e for e in local_alternatives if all(arg.type.is_pyobject for arg in e.type.args)]
                    if len(py_args_alternatives) == 1:
                        # if there is a single locally defined method with all-python arguments, use that one
                        attr = py_args_alternatives[0]
                    else:
                        # else skip overloaded method for now
                        continue

                py_method_wrapper = self.synthesize_cypclass_method_wrapper(node, cclass_name, attr)
                if py_method_wrapper:
                    stats.append(py_method_wrapper)

            elif attr.is_variable and attr.name != "this":
                property = self.synthesize_property(attr, node.entry)
                if property:
                    stats.append(property)

    def synthesize_property(self, attr_entry, node_entry):
        if not attr_entry.type.can_coerce_to_pyobject(self.module_scope):
            return None
        if not attr_entry.type.can_coerce_from_pyobject(self.module_scope):
            return None
        template = self.property_template
        underlying_name = EncodedString("o")
        property = template.substitute({
            "ATTR": attr_entry.name,
            "TYPE": node_entry.type,
            "OBJ": ExprNodes.NameNode(attr_entry.pos, name=underlying_name),
        }, pos=attr_entry.pos).stats[0]
        property.name = attr_entry.name
        property.doc = attr_entry.doc
        return property

    def synthesize_cypclass_method_wrapper(self, node, cclass_name, method_entry):
        if method_entry.type.is_static_method and method_entry.static_cname is None:
            # for now skip static methods, except when they are wrapped by a virtual method
            return

        if method_entry.name in ("<del>", "<alloc>", "__new__", "<constructor>"):
            # skip special methods that should not be wrapped
            return

        method_type = method_entry.type

        if method_type.self_qualifier:
            # skip methods with qualified self
            return

        if method_type.optional_arg_count:
            # for now skip methods with optional arguments
            return

        return_type = method_type.return_type

        # we pass the global scope as argument, should not affect the result (?)
        if not return_type.can_coerce_to_pyobject(self.module_scope):
            # skip c methods with Python-incompatible return types
            return

        for argtype in method_type.args:
            if not argtype.type.can_coerce_from_pyobject(self.module_scope):
                # skip c methods with Python-incompatible argument types
                return

        # > name of the wrapping method: same name as in the original code
        method_name = method_entry.original_name
        if method_name is None:
            # skip methods that don't have an original name
            return

        py_name = method_name

        # > all arguments of the wrapper method declaration
        py_args_decls = []
        for arg in method_type.args:
            arg_base_type = Nodes.CSimpleBaseTypeNode(
                method_entry.pos,
                name = None,
                module_path = [],
                is_basic_c_type = 0,
                signed = 0,
                complex = 0,
                longness = 0,
                is_self_arg = 0,
                templates = None
            )
            arg_declarator = Nodes.CNameDeclaratorNode(
                method_entry.pos,
                name=arg.name,
                cname=None
            )
            arg_decl = Nodes.CArgDeclNode(
                method_entry.pos,
                base_type = arg_base_type,
                declarator = arg_declarator,
                not_none = 0,
                or_none = 0,
                default = None,
                annotation = None,
                kw_only = 0
            )
            py_args_decls.append(arg_decl)

        # > same docstring
        py_doc = method_entry.doc

        # > names of the arguments passed when calling the underlying method; self not included
        arg_objs = [ExprNodes.NameNode(arg.pos, name=arg.name) for arg in method_type.args]

        # > access the underlying attribute
        underlying_type = node.entry.type

        # > select the appropriate template and create the wrapper defnode
        need_return = not return_type.is_void

        if method_entry.type.is_static_method:
            template = self.static_template if need_return else self.static_no_return_template

            method_wrapper = template.substitute({
                "NAME": method_name,
                "ARGDECLS": py_args_decls,
                "TYPE_NAME": ExprNodes.NameNode(method_entry.pos, name=node.name),
                "ARGS": arg_objs
            }).stats[0]

        else:
            template = self.method_template if need_return else self.method_no_return_template

            # > derive a unique name that doesn't collide with the arguments
            underlying_name = self.create_unique_name("o", entries=[arg.name for arg in arg_objs])

            # > instanciate the wrapper from the template
            method_wrapper = template.substitute({
                "NAME": method_name,
                "ARGDECLS": py_args_decls,
                "TYPE": underlying_type,
                "OBJ": ExprNodes.NameNode(method_entry.pos, name=underlying_name),
                "ARGS": arg_objs
            }).stats[0]

        method_wrapper.doc = py_doc

        return method_wrapper


class CypclassLockTransform(Visitor.EnvTransform):
    """
        Acquire cypclass locks where required.
    """

    def __call__(self, root):
        self.writing = False
        return super(CypclassLockTransform, self).__call__(root)

    def visit_AttributeNode(self, node):
        obj = node.obj
        objtype = obj.type
        nodetype = node.type
        if objtype is None or nodetype is None:
            self.visitchildren(node)
            return node
        field_access = node.entry and not node.entry.is_type and not nodetype.is_cfunction
        method_call = nodetype.is_cfunction and not nodetype.is_static_method and node.is_called
        # The 'const' annotation is only sufficient to infer
        # that the receiver object will only be read, not that
        # __all__ the reachable subobjects will only be read.
        locally_writing = (field_access and node.is_target) or method_call
        if objtype.is_qualified_cyp_class and objtype.qualifier == 'lock':
            old_writing = self.writing
            self.writing = locally_writing
            self.visitchildren(node)
            if field_access or (method_call and not nodetype.self_qualifier == 'lock'):
                node.obj = ExprNodes.CoerceToLockedNode(node.obj, exclusive=self.writing)
            self.writing = old_writing
        elif objtype.is_cyp_class:
            old_writing = self.writing
            self.writing |= locally_writing
            self.visitchildren(node)
            self.writing = old_writing
        return node
