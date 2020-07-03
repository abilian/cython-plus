from Cython.TestUtils import CythonTest
from Cython.Compiler.TreeFragment import *
from Cython.Compiler.Nodes import *
from Cython.Compiler.ExprNodes import *
from Cython.Compiler.UtilNodes import *
import Cython.Compiler.Naming as Naming

class TestTreeFragments(CythonTest):

    def test_basic(self):
        F = self.fragment(u"x = 4")
        T = F.copy()
        self.assertCode(u"x = 4", T)

    def test_copy_is_taken(self):
        F = self.fragment(u"if True: x = 4")
        T1 = F.root
        T2 = F.copy()
        self.assertEqual("x", T2.stats[0].if_clauses[0].body.lhs.name)
        T2.stats[0].if_clauses[0].body.lhs.name = "other"
        self.assertEqual("x", T1.stats[0].if_clauses[0].body.lhs.name)

    def test_substitutions_are_copied(self):
        T = self.fragment(u"y + y").substitute({"y": NameNode(pos=None, name="x")})
        self.assertEqual("x", T.stats[0].expr.operand1.name)
        self.assertEqual("x", T.stats[0].expr.operand2.name)
        self.assertTrue(T.stats[0].expr.operand1 is not T.stats[0].expr.operand2)

    def test_substitution(self):
        F = self.fragment(u"x = 4")
        y = NameNode(pos=None, name=u"y")
        T = F.substitute({"x" : y})
        self.assertCode(u"y = 4", T)

    def test_exprstat(self):
        F = self.fragment(u"PASS")
        pass_stat = PassStatNode(pos=None)
        T = F.substitute({"PASS" : pass_stat})
        self.assertTrue(isinstance(T.stats[0], PassStatNode), T)

    def test_pos_is_transferred(self):
        F = self.fragment(u"""
        x = y
        x = u * v ** w
        """)
        T = F.substitute({"v" : NameNode(pos=None, name="a")})
        v = F.root.stats[1].rhs.operand2.operand1
        a = T.stats[1].rhs.operand2.operand1
        self.assertEqual(v.pos, a.pos)

    def test_temps(self):
        TemplateTransform.temp_name_counter = 0
        F = self.fragment(u"""
            TMP
            x = TMP
        """)
        T = F.substitute(temps=[u"TMP"])
        s = T.body.stats
        self.assertTrue(isinstance(s[0].expr, TempRefNode))
        self.assertTrue(isinstance(s[1].rhs, TempRefNode))
        self.assertTrue(s[0].expr.handle is s[1].rhs.handle)

    def test_declarator(self):
        F = self.fragment(u"cdef int NAME")
        declarator = CNameDeclaratorNode(pos=None, name="a")
        T = F.substitute({"NAME" : declarator})
        self.assertTrue(isinstance(T.stats[0], CVarDefNode), T)
        self.assertTrue(isinstance(T.stats[0].declarators[0], CNameDeclaratorNode), T)
        self.assertTrue(T.stats[0].declarators[0].name == "a", T)

    def test_simple_base_type(self):
        F = self.fragment(u"cdef TYPE a")
        base_type = CSimpleBaseTypeNode(pos=None, name="int", module_path = [],
        is_basic_c_type = 1, signed = 1,
        complex = 0, longness = 0,
        is_self_arg = 0, templates = None)
        T = F.substitute({"TYPE" : base_type})
        self.assertTrue(isinstance(T.stats[0], CVarDefNode), T)
        self.assertTrue(isinstance(T.stats[0].base_type, CSimpleBaseTypeNode), T)
        self.assertTrue(T.stats[0].base_type.name == "int", T)

    def test_typecast(self):
        F = self.fragment(u"a = <TYPE> b")

        T1 = F.substitute({"TYPE" : PyrexTypes.c_int_type})
        self.assertTrue(isinstance(T1.stats[0], SingleAssignmentNode), T1)
        self.assertTrue(isinstance(T1.stats[0].rhs, TypecastNode), T1)
        self.assertTrue(T1.stats[0].rhs.type is PyrexTypes.c_int_type, T1)
        self.assertTrue(isinstance(T1.stats[0].rhs.operand, NameNode), T1)
        self.assertTrue(T1.stats[0].rhs.operand.name == "b", T1)

        base_type = CSimpleBaseTypeNode(pos=None, name="int", module_path = [],
        is_basic_c_type = 1, signed = 1,
        complex = 0, longness = 0,
        is_self_arg = 0, templates = None)
        T2 = F.substitute({"TYPE" : base_type})
        self.assertTrue(isinstance(T2.stats[0], SingleAssignmentNode), T2)
        self.assertTrue(isinstance(T2.stats[0].rhs, TypecastNode), T2)
        self.assertTrue(isinstance(T2.stats[0].rhs.base_type, CSimpleBaseTypeNode), T2)
        self.assertTrue(T2.stats[0].rhs.base_type.name == "int", T2)
        self.assertTrue(isinstance(T2.stats[0].rhs.declarator, CNameDeclaratorNode), T2)
        self.assertTrue(T2.stats[0].rhs.declarator.name == "", T2)
        self.assertTrue(isinstance(T2.stats[0].rhs.operand, NameNode), T2)
        self.assertTrue(T2.stats[0].rhs.operand.name == "b", T2)

        typecast = TypecastNode(
            pos=None,
            base_type=base_type,
            declarator=CNameDeclaratorNode(pos=None, name=EncodedString(""), cname=None),
            operand = NameNode(pos=None, name="c")
        )
        T3 = F.substitute({"TYPE" : typecast})
        self.assertTrue(isinstance(T3.stats[0], SingleAssignmentNode), T3)
        self.assertTrue(isinstance(T3.stats[0].rhs, TypecastNode), T3)
        self.assertTrue(isinstance(T3.stats[0].rhs.base_type, CSimpleBaseTypeNode), T3)
        self.assertTrue(T3.stats[0].rhs.base_type.name == "int", T3)
        self.assertTrue(isinstance(T3.stats[0].rhs.declarator, CNameDeclaratorNode), T3)
        self.assertTrue(T3.stats[0].rhs.declarator.name == "", T3)
        self.assertTrue(isinstance(T3.stats[0].rhs.operand, NameNode), T3)
        self.assertTrue(T3.stats[0].rhs.operand.name == "c", T3)

    def test_args(self):
        F = self.fragment(u"def test(self, ARGS): pass")
        args = [
            CArgDeclNode(
                pos = None,
                base_type = CSimpleBaseTypeNode(pos=None, signed=1),
                declarator = CNameDeclaratorNode(pos=None, name="a")
            ),
            CArgDeclNode(
                pos = None,
                base_type = CSimpleBaseTypeNode(pos=None, signed=1),
                declarator = CNameDeclaratorNode(pos=None, name="b")
            )
        ]
        T = F.substitute({"ARGS" : args})
        self.assertTrue(isinstance(T.stats[0], DefNode), T)
        self.assertTrue(isinstance(T.stats[0].args[0], CArgDeclNode), T)
        self.assertTrue(isinstance(T.stats[0].args[1], CArgDeclNode), T)
        self.assertTrue(isinstance(T.stats[0].args[2], CArgDeclNode), T)
        self.assertTrue(isinstance(T.stats[0].args[0].declarator, CNameDeclaratorNode), T)
        self.assertTrue(isinstance(T.stats[0].args[1].declarator, CNameDeclaratorNode), T)
        self.assertTrue(isinstance(T.stats[0].args[2].declarator, CNameDeclaratorNode), T)
        self.assertTrue(T.stats[0].args[0].declarator.name == "self", T)
        self.assertTrue(T.stats[0].args[1].declarator.name == "a", T)
        self.assertTrue(T.stats[0].args[2].declarator.name == "b", T)
        self.assertTrue(len(T.stats[0].args) == 3, T)

    def test_attribute(self):
        F = self.fragment(u"OBJ.ATTR")
        base_type = CSimpleBaseTypeNode(pos=None, name="int", module_path = [],
        is_basic_c_type = 1, signed = 1,
        complex = 0, longness = 0,
        is_self_arg = 0, templates = None)
        T = F.substitute({
            "OBJ" : NameNode(pos=None, name="x"),
            "ATTR" : "y"
        })
        self.assertTrue(isinstance(T.stats[0], ExprStatNode), T)
        self.assertTrue(isinstance(T.stats[0].expr, AttributeNode), T)
        self.assertTrue(isinstance(T.stats[0].expr.obj, NameNode), T)
        self.assertTrue(T.stats[0].expr.obj.name == "x", T)
        self.assertTrue(T.stats[0].expr.attribute == "y", T)

    def test_defnode(self):
        F = self.fragment(u"def NAME(): pass")
        T = F.substitute({
            "NAME" : "test",
        })
        self.assertTrue(isinstance(T.stats[0], DefNode), T)
        self.assertTrue(T.stats[0].name == "test", T)

    def test_propertynode(self):
        F = TreeFragment(u"property NAME: pass", level='c_class')
        T = F.substitute({
            "NAME" : "test",
        })
        self.assertTrue(isinstance(T.stats[0], PropertyNode), T)
        self.assertTrue(T.stats[0].name == "test", T)

    def test_fromimportstatnode(self):
        F = TreeFragment(u"from A import b as NAME")
        T = F.substitute({
            "NAME" : NameNode(None, name="test"),
        })
        self.assertTrue(isinstance(T.stats[0], FromImportStatNode), T)
        self.assertTrue(isinstance(T.stats[0].items[0][1], NameNode), T)
        self.assertTrue(T.stats[0].items[0][1].name == "test", T)

if __name__ == "__main__":
    import unittest
    unittest.main()
