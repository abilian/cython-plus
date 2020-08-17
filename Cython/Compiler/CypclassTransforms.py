#
#   Cypclass transforms
#


from __future__ import absolute_import

import cython
cython.declare(Naming=object, PyrexTypes=object, EncodedString=object, error=object)

from collections import defaultdict
from contextlib import ExitStack
from itertools import chain

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
    unlocked_property = TreeFragment.TreeFragment(u"""
property NAME:
    def __get__(self):
        OBJ = <TYPE> self
        return OBJ.ATTR
    def __set__(self, value):
        OBJ = <TYPE> self
        OBJ.ATTR = value
    """, level='c_class', pipeline=[NormalizeTree(None)])

    locked_property = TreeFragment.TreeFragment(u"""
property NAME:
    def __get__(self):
        OBJ = <TYPE> self
        with rlocked OBJ:
            value = OBJ.ATTR
        return value
    def __set__(self, value):
        OBJ = <TYPE> self
        with wlocked OBJ:
            OBJ.ATTR = value
    """, level='c_class', pipeline=[NormalizeTree(None)])

    # method wrapper templates
    unlocked_method = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    return OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    unlocked_method_no_return = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    rlocked_method = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    with rlocked OBJ:
        return OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    rlocked_method_no_return = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    with rlocked OBJ:
        OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    wlocked_method = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    with wlocked OBJ:
        return OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    wlocked_method_no_return = TreeFragment.TreeFragment(u"""
def NAME(self, ARGDECLS):
    OBJ = <TYPE> self
    with wlocked OBJ:
        OBJ.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    # static method wrapper templates
    static_method = TreeFragment.TreeFragment(u"""
@staticmethod
def NAME(ARGDECLS):
    return TYPE_NAME.NAME(ARGS)
    """, level='c_class', pipeline=[NormalizeTree(None)])

    static_method_no_return = TreeFragment.TreeFragment(u"""
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
            if not wrapped_base_type in self.synthesized:
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

            elif not attr.is_type:
                property = self.synthesize_property(attr, node.entry)
                if property:
                    stats.append(property)

    def synthesize_property(self, attr_entry, node_entry):
        if not attr_entry.type.can_coerce_to_pyobject(self.module_scope):
            return None
        if not attr_entry.type.can_coerce_from_pyobject(self.module_scope):
            return None
        if node_entry.type.lock_mode == 'checklock':
            template = self.locked_property
        else:
            template = self.unlocked_property
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
            template = self.static_method if need_return else self.static_method_no_return

            method_wrapper = template.substitute({
                "NAME": method_name,
                "ARGDECLS": py_args_decls,
                "TYPE_NAME": ExprNodes.NameNode(method_entry.pos, name=node.name),
                "ARGS": arg_objs
            }).stats[0]

        else:
            if node.lock_mode == 'checklock':
                need_wlock = not method_type.is_const_method
                if need_wlock:
                    template = self.wlocked_method if need_return else self.wlocked_method_no_return
                else:
                    template = self.rlocked_method if need_return else self.rlocked_method_no_return
            else:
                template = self.unlocked_method if need_return else self.unlocked_method_no_return

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
        Check that cypclass objects are properly locked and insert locks if required.
    """

    class StackLock:
        """
            Context manager for tracking nested locks.
        """

        def __init__(self, transform, obj_entry, state):
            self.transform = transform
            self.state = state
            self.entry = obj_entry

        def __enter__(self):
            state = self.state
            entry = self.entry
            self.old_rlocked = self.transform.rlocked[entry]
            self.old_wlocked = self.transform.wlocked[entry]
            if state == 'rlocked':
                self.transform.rlocked[entry] += 1
            elif state == 'wlocked':
                self.transform.wlocked[entry] += 1

        def __exit__(self, *args):
            entry = self.entry
            self.transform.rlocked[entry] = self.old_rlocked
            self.transform.wlocked[entry] = self.old_wlocked

    def stacklock(self, obj_entry, state):
        return self.StackLock(self, obj_entry, state)


    class AccessContext:
        """
            Context manager to track the kind of access (reading, writing ...).
        """

        def __init__(self, collector, reading=False, writing=False, deleting=False):
            self.collector = collector
            self.reading = reading
            self.writing = writing
            self.deleting = deleting

        def __enter__(self):
            self.reading, self.collector.reading = self.collector.reading, self.reading
            self.writing, self.collector.writing = self.collector.writing, self.writing
            self.deleting, self.collector.deleting = self.collector.deleting, self.deleting

        def __exit__(self, *args):
            self.collector.reading = self.reading
            self.collector.writing = self.writing
            self.collector.deleting = self.deleting

    def accesscontext(self, reading=False, writing=False, deleting=False):
        return self.AccessContext(self, reading=reading, writing=writing, deleting=deleting)


    def __call__(self, root):
        self.rlocked = defaultdict(int)
        self.wlocked = defaultdict(int)
        self.reading = False
        self.writing = False
        self.deleting = False
        return super(CypclassLockTransform, self).__call__(root)

    def reference_identifier(self, node):
        while isinstance(node, ExprNodes.CoerceToTempNode):  # works for CoerceToLockedTempNode as well
            node = node.arg
        if node.is_name:
            return node.entry
        return None

    def id_to_name(self, id):
        return id.name

    def lockcheck_on_context(self, node):
        if self.writing or self.deleting:
            return self.lockcheck_written(node)
        elif self.reading:
            return self.lockcheck_read(node)
        return node

    def lockcheck_read(self, read_node):
        lock_mode = read_node.type.lock_mode
        if lock_mode == "nolock":
            return read_node
        ref_id = self.reference_identifier(read_node)
        if ref_id:
            if not (self.rlocked[ref_id] > 0 or self.wlocked[ref_id] > 0):
                if lock_mode == "checklock":
                    error(read_node.pos, (
                            "Reference '%s' is not correctly locked in this expression (read lock required)"
                        ) % self.id_to_name(ref_id) )
                elif lock_mode == "autolock":
                    # for now, lock a temporary for each expression
                    return ExprNodes.CoerceToLockedTempNode(read_node, self.current_env(), rlock_only=True)
        else:
            if lock_mode == "checklock":
                error(read_node.pos, "This expression is not correctly locked (read lock required)")
            elif lock_mode == "autolock":
                if not isinstance(read_node, ExprNodes.CoerceToLockedTempNode):
                    return ExprNodes.CoerceToLockedTempNode(read_node, self.current_env(), rlock_only=True)
        return read_node

    def lockcheck_written(self, written_node):
        lock_mode = written_node.type.lock_mode
        if lock_mode == "nolock":
            return written_node
        ref_id = self.reference_identifier(written_node)
        if ref_id:
            if not self.wlocked[ref_id] > 0:
                if lock_mode == "checklock":
                    error(written_node.pos, (
                            "Reference '%s' is not correctly locked in this expression (write lock required)"
                        ) % self.id_to_name(ref_id) )
                elif lock_mode == "autolock":
                    # for now, lock a temporary for each expression
                    return ExprNodes.CoerceToLockedTempNode(written_node, self.current_env(), rlock_only=False)
        else:
            if lock_mode == "checklock":
                error(written_node.pos, "This expression is not correctly locked (write lock required)")
            elif lock_mode == "autolock":
                if isinstance(written_node, ExprNodes.CoerceToLockedTempNode):
                    written_node.rlock_only = False
                else:
                    return ExprNodes.CoerceToLockedTempNode(written_node, self.current_env())
        return written_node

    def lockcheck_written_or_read(self, node, reading=False):
        if reading:
            return self.lockcheck_read(node)
        else:
            return self.lockcheck_written(node)
        return node

    def lockcheck_if_subscript_rhs(self, lhs, rhs):
        if lhs.is_subscript and lhs.base.type.is_cyp_class:
            setitem = lhs.base.type.scope.lookup("__setitem__")
            if setitem and len(setitem.type.args) == 2:
                arg_type = setitem.type.args[1].type
                if arg_type.is_cyp_class:
                    return self.lockcheck_written_or_read(rhs, reading=arg_type.is_const)
            # else: should have caused a previous error
        return rhs

    def visit_CFuncDefNode(self, node):
        cyp_class_args = (e for e in node.local_scope.arg_entries if e.type.is_cyp_class)
        with ExitStack() as locked_args_stack:
            for arg in cyp_class_args:
                is_rlocked = arg.type.is_const or arg.is_self_arg and node.entry.type.is_const_method
                arg_id = arg
                # Mark each cypclass arguments as locked within the function body
                locked_args_stack.enter_context(self.stacklock(arg_id, "rlocked" if is_rlocked else "wlocked"))
            self.visit(node.body)
        return node

    def visit_LockCypclassNode(self, node):
        obj_ref_id = self.reference_identifier(node.obj)
        if not obj_ref_id:
            error(node.obj.pos, "Locking an unnamed reference")
            return node
        if not node.obj.type.is_cyp_class:
            error(node.obj.pos, "Locking non-cypclass reference")
            return node
        with self.stacklock(obj_ref_id, node.state):
            self.visit(node.body)
        return node

    def visit_Node(self, node):
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_DelStatNode(self, node):
        for arg in node.args:
            arg_ref_id = self.reference_identifier(arg)
            if self.rlocked[arg_ref_id] > 0 or self.wlocked[arg_ref_id] > 0:
                # Disallow unbinding a locked name
                error(arg.pos, "Deleting a locked cypclass reference")
                return node
        with self.accesscontext(deleting=True):
            self.visitchildren(node)
        return node

    def visit_SingleAssignmentNode(self, node):
        lhs_ref_id = self.reference_identifier(node.lhs)
        if self.rlocked[lhs_ref_id] > 0 or self.wlocked[lhs_ref_id] > 0:
            # Disallow re-binding a locked name
            error(node.lhs.pos, "Assigning to a locked cypclass reference")
            return node
        node.rhs = self.lockcheck_if_subscript_rhs(node.lhs, node.rhs)
        with self.accesscontext(writing=True):
            self.visit(node.lhs)
        with self.accesscontext(reading=True):
            self.visit(node.rhs)
        return node

    def visit_CascadedAssignmentNode(self, node):
        for lhs in node.lhs_list:
            lhs_ref_id = self.reference_identifier(lhs)
            if self.rlocked[lhs_ref_id] > 0 or self.wlocked[lhs_ref_id] > 0:
                # Disallow re-binding a locked name
                error(lhs.pos, "Assigning to a locked cypclass reference")
                return node
        for lhs in node.lhs_list:
            node.rhs = self.lockcheck_if_subscript_rhs(lhs, node.rhs)
        with self.accesscontext(writing=True):
            for lhs in node.lhs_list:
                self.visit(lhs)
        with self.accesscontext(reading=True):
            self.visit(node.rhs)
        return node

    def visit_WithTargetAssignmentStatNode(self, node):
        target_id = self.reference_identifier(node.lhs)
        if self.rlocked[target_id] > 0 or self.wlocked[target_id] > 0:
            # Disallow re-binding a locked name
            error(node.lhs.pos, "With expression target is a locked cypclass reference")
            return node
        node.rhs = self.lockcheck_if_subscript_rhs(node.lhs, node.rhs)
        with self.accesscontext(writing=True):
            self.visit(node.lhs)
        with self.accesscontext(reading=True):
            self.visit(node.rhs)
        return node

    def visit__ForInStatNode(self, node):
        target_id = self.reference_identifier(node.target)
        if self.rlocked[target_id] > 0 or self.wlocked[target_id] > 0:
            # Disallow re-binding a locked name
            error(node.target.pos, "For-Loop target is a locked cypclass reference")
            return node
        node.item = self.lockcheck_if_subscript_rhs(node.target, node.item)
        with self.accesscontext(writing=True):
            self.visit(node.target)
        with self.accesscontext(reading=True):
            self.visit(node.item)
        self.visit(node.body)
        self.visit(node.iterator)
        if node.else_clause:
            self.visit(node.else_clause)
        return node

    def visit_ExceptClauseNode(self, node):
        if not node.target:
            self.visitchildren(node)
        else:
            target_id = self.reference_identifier(node.target)
            if self.rlocked[target_id] > 0 or self.wlocked[target_id] > 0:
                # Disallow re-binding a locked name
                error(node.target.pos, "Except clause target is a locked cypclass reference")
                return node
            with self.accesscontext(writing=True):
                self.visit(node.target)
            for p in node.pattern:
                self.visit(p)
            self.visit(node.body)
        return node

    def visit_AttributeNode(self, node):
        if node.obj.type and node.obj.type.is_cyp_class:
            if node.is_called and node.type.is_cfunction:
                if not node.type.is_static_method:
                    node.obj = self.lockcheck_written_or_read(node.obj, reading=node.type.is_const_method)
            else:
                node.obj = self.lockcheck_on_context(node.obj)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_SimpleCallNode(self, node):
        for i, arg in enumerate(node.args or ()): # provide an empty tuple fallback in case node.args is None
            if arg.type.is_cyp_class:
                node.args[i] = self.lockcheck_written_or_read(arg, reading=arg.type.is_const)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_CoerceFromCallable(self, node):
        if node.arg.type.is_cyp_class:
            node.arg = self.lockcheck_written_or_read(node.arg, reading=node.type.is_const_method)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_IndexNode(self, node):
        if node.base.type.is_cyp_class:
            func_entry = None
            if self.deleting:
                func_entry = node.base.type.scope.lookup("__delitem__")
            elif self.writing:
                func_entry = node.base.type.scope.lookup("__setitem__")
            elif self.reading:
                func_entry = node.base.type.scope.lookup("__getitem__")
            if func_entry:
                func_type = func_entry.type
                node.base = self.lockcheck_written_or_read(node.base, reading=func_type.is_const_method)
                if len(func_type.args):
                    if func_type.args[0].type.is_cyp_class:
                        node.index = self.lockcheck_written_or_read(node.index, reading=func_type.args[0].type.is_const)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def _visit_binop(self, node, func_type):
        if func_type is not None:
            if node.operand1.type.is_cyp_class and len(func_type.args) == 1:
                node.operand1 = self.lockcheck_written_or_read(node.operand1, reading=func_type.is_const_method)
                arg_type = func_type.args[0].type
                if arg_type.is_cyp_class:
                    node.operand2 = self.lockcheck_written_or_read(node.operand2, reading=arg_type.is_const)
            elif len(func_type.args) == 2:
                arg1_type = func_type.args[0].type
                if arg1_type.is_cyp_class:
                    node.operand1 = self.lockcheck_written_or_read(node.operand1, reading=arg1_type.is_const)
                arg2_type = func_type.args[1].type
                if arg2_type.is_cyp_class:
                    node.operand2 = self.lockcheck_written_or_read(node.operand2, reading=arg2_type.is_const)

    def visit_BinopNode(self, node):
        func_type = node.op_func_type
        self._visit_binop(node, func_type)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_PrimaryCmpNode(self, node):
        func_type = node.cmp_func_type
        self._visit_binop(node, func_type)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_InPlaceAssignmentNode(self, node):
        # operator = "operator%s="% node.operator
        # if node.lhs.type.is_cyp_class:
            # TODO: get operator function type and treat it like a binop with lhs and rhs
        with self.accesscontext(reading=True, writing=True):
            self.visit(node.lhs)
        with self.accesscontext(reading=True):
            self.visit(node.rhs)
        return node

    def _visit_unop(self, node, func_type):
        if func_type is not None:
            if node.operand.type.is_cyp_class and len(func_type.args) == 0:
                node.operand = self.lockcheck_written_or_read(node.operand, reading=func_type.is_const_method)

    def visit_UnopNode(self, node):
        func_type = node.op_func_type
        self._visit_unop(node, func_type)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node

    def visit_TypecastNode(self, node):
        func_type = node.op_func_type
        self._visit_unop(node, func_type)
        with self.accesscontext(reading=True):
            self.visitchildren(node)
        return node
