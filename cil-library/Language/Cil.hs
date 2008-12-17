-- |
-- A simple abstraction over the Common Intermediate Language.
-- Note that this library specific to the EHC .NET backend and isn't very
-- reusable (yet).
-- It only exposes a small subset of CIL.
--

module Language.Cil where

import Data.List (intersperse)
import Numeric (showHex)

class Cil a where
  -- | Serializes a Cil data structure to a String.
  cil :: a -> ShowS

-- | Represents a name in the CIL world.
-- These need to confirm to certain restrictions, altough these aren't
-- currently checked.
type Name = String

-- | Serializes a Name, escaping some weird names (such as \'add\').
cilName :: Name -> ShowS
cilName "add" = ("'add'" ++)
cilName "pop" = ("'pop'" ++)
cilName n     = (n ++)

-- | Represents the top level Assembly.
-- This is the root of a CIL program.
data Assembly =
    Assembly Name [TypeDef]

instance Cil Assembly where
  cil (Assembly n ms) =
      (".assembly extern mscorlib {}\n" ++)
    . (".assembly " ++) . cilName n . (" {}\n" ++)
    . foldr (\m s -> cil m . s) id ms

-- | A Type definition in CIL, either a class or a value type.
data TypeDef =
    Class Visibility Name [FieldDef] [MethodDef]

instance Cil TypeDef where
  cil (Class v n fs ms) =
      (".class " ++) . cil v . sp . cilName n . ("\n{\n" ++)
    . foldr (\f s -> cil f . s) id fs
    . nl
    . foldr (\m s -> cil m . s) id ms
    . ("}\n" ++)

data Visibility =
    AssemblyVisible
  | Family
  | FamilyAndAssembly
  | FamilyOrAssembly
  | Private
  | Public

instance Cil Visibility where
  cil AssemblyVisible   = ("assembly" ++)
  cil FamilyAndAssembly = ("famandassem" ++)
  cil FamilyOrAssembly  = ("famorassem" ++)
  cil Private           = ("private" ++)
  cil Public            = ("public" ++)

data FieldDef =
    Field Visibility PrimitiveType Name

instance Cil FieldDef where
  cil (Field v t n) = 
      ident . (".field " ++) .  cil v . sp . cil t . sp . cilName n . nl

-- | A Method definition in CIL.
-- Currently, only static methods are implemented.
data MethodDef =
    Constructor  Visibility [Parameter] [Directive] [OpCode]
  | StaticMethod Visibility PrimitiveType Name [Parameter] [Directive] [OpCode]
  -- InstanceMethod

instance Cil MethodDef where
  cil (Constructor v ps ds os) =
      ident . (".method " ++) . cil v
    . (" hidebysig instance void .ctor(" ++)
    . foldr (.) id (intersperse (", " ++) (map cil ps))
    . (") cil managed\n" ++)
    . ident . ("{\n" ++)
    . foldr (\d s -> cil d . s) id ds
    . foldr (\o s -> cil o . s) id os
    . ident . ("}\n" ++)
  cil (StaticMethod v t n ps ds os) =
      ident . (".method " ++) . cil v
    . (" hidebysig static " ++) . cil t . sp . cilName n . ("(" ++)
    . foldr (.) id (intersperse (", " ++) (map cil ps))
    . (") cil managed\n" ++)
    . ident . ("{\n" ++)
    . foldr (\d s -> cil d . s) id ds
    . foldr (\o s -> cil o . s) id os
    . ident . ("}\n" ++)

-- | Represents a formal parameter to a method.
data Parameter =
    Param PrimitiveType Name

instance Cil Parameter where
  cil (Param t n) = cil t . sp . cilName n

-- | Directive meta data for method definitions.
data Directive =
    EntryPoint
  | LocalsInit [Local]
  | MaxStack Int

instance Cil Directive where
  cil (EntryPoint)    = ident . ident . (".entrypoint" ++) . nl
  cil (LocalsInit ls) =
    let bigident = ident . ident . ident . ident
    in
      ident . ident . (".locals init (\n" ++)
    . foldr (.) id (intersperse (",\n" ++) (map (\l -> bigident . cil l) ls))
    . (")\n" ++)
  cil (MaxStack x)    = ident . ident . (".maxstack " ++) . (shows x) . nl

-- | Local variables used inside a method definition.
data Local =
    Local PrimitiveType Name

instance Cil Local where
  cil (Local t n) = cil t . sp . cilName n

-- | Represents a Label in CIL.
type Label = String

-- | CIL OpCodes inside a method definition.
-- See <http://msdn.microsoft.com/en-us/library/system.reflection.emit.opcodes_members.aspx>
-- for a more complete list with documentation.
data OpCode =
    Label Label OpCode -- ^ Meta instruction. Give an instruction a label, used in jumps.
  | Add                -- ^ Adds two values and pushes the result onto the evaluation stack.
  | And                -- ^ Computes the bitwise AND of two values and pushes the result onto the evaluation stack.
  | Beq Label          -- ^ Transfers control to a target instruction if two values are equal.
  | Bge Label          -- ^ Transfers control to a target instruction if the first value is greater than or equal to the second value.
  | Bgt Label          -- ^ Transfers control to a target instruction if the first value is greater than the second value.
  | Ble Label          -- ^ Transfers control to a target instruction if the first value is less than or equal to the second value.
  | Blt Label          -- ^ Transfers control to a target instruction if the first value is less than the second value.
  | Box PrimitiveType  -- ^ Converts a value type to an object reference (type O).
  | Br Label           -- ^ Unconditionally transfers control to a target instruction.
  | Brfalse Label      -- ^ Transfers control to a target instruction if value is false, a null reference, or zero.
  | Brtrue Label       -- ^ Transfers control to a target instruction if value is true, not null, or non-zero.
  | Break              -- ^ Signals the Common Language Infrastructure (CLI) to inform the debugger that a break point has been tripped.
  | Call { association  :: Association     -- ^ Method is associated with class or instance.
         , returnType   :: PrimitiveType   -- ^ Return type of the method.
         , assemblyName :: Name            -- ^ Name of the assembly where the method lives.
         , typeName     :: Name            -- ^ Name of the type of which the method is a member.
         , methodName   :: Name            -- ^ Name of the method.
         , paramTypes   :: [PrimitiveType] -- ^ Types of the formal parameters of the method.
         } -- ^ Calls the indicated method.
  | Ceq                -- ^ Compares two values. If they are equal, the integer value 1 /(int32)/ is pushed onto the evaluation stack; otherwise 0 /(int32)/ is pushed onto the evaluation stack.
  | Dup                -- ^ Copies the current topmost value on the evaluation stack, and then pushes the copy onto the evaluation stack.
  | Ldarg Int
  | Ldc_i4 Int
  | Ldfld { fieldType    :: PrimitiveType
          , assemblyName :: Name
          , typeName     :: Name
          , fieldName    :: Name
          } -- ^ Finds the value of a field in the object whose reference is currently on the evaluation stack.
  | Ldloc Int
  | Ldloca Int
  | Ldstr String
  | Neg
  | Newobj { association  :: Association
           , returnType   :: PrimitiveType
           , assemblyName :: Name
           , typeName     :: Name
           , paramTypes   :: [PrimitiveType]
           } -- ^ Creates a new object or a new instance of a value type, pushing an object reference (type O) onto the evaluation stack.
  | Nop
  | Pop
  | Rem
  | Ret
  | Stfld { fieldType    :: PrimitiveType
          , assemblyName :: Name
          , typeName     :: Name
          , fieldName    :: Name
          } -- ^ Replaces the value stored in the field of an object reference or pointer with a new value.
  | Stloc Int          -- ^ Pops the current value from the top of the evaluation stack and stores it in a the local variable list at a specified index.
  | Sub                -- ^ Subtracts one value from another and pushes the result onto the evaluation stack. 
  | Tail               -- ^ Performs a postfixed method call instruction such that the current method's stack frame is removed before the actual call instruction is executed.

-- Note: this could be a lot more efficient. For example, there are specialized
-- instructions for loading the constant integers 1 through 8, but for clearity
-- these aren't used.
instance Cil OpCode where
  cil (Label l oc)        = ident . (l ++) . (":" ++) . nl . cil oc
  cil (Add)               = ident . ident . ("add" ++) . nl
  cil (And)               = ident . ident . ("and" ++) . nl
  cil (Beq l)             = ident . ident . ("beq " ++) . (l ++) . nl
  cil (Bge l)             = ident . ident . ("bge " ++) . (l ++) . nl
  cil (Bgt l)             = ident . ident . ("bgt " ++) . (l ++) . nl
  cil (Ble l)             = ident . ident . ("ble " ++) . (l ++) . nl
  cil (Blt l)             = ident . ident . ("blt " ++) . (l ++) . nl
  cil (Box t)             = ident . ident . ("box " ++) . cil t . nl
  cil (Br l)              = ident . ident . ("br " ++) . (l ++) . nl
  cil (Brfalse l)         = ident . ident . ("brfalse " ++) . (l ++) . nl
  cil (Brtrue l)          = ident . ident . ("brtrue " ++) . (l ++) . nl
  cil (Break)             = ident . ident . ("break" ++) . nl
  cil (Call s t a c m ps) = ident . ident . ("call " ++) . cil s . sp
                             . cil t . sp . cilCall a c m ps . nl
  cil (Ceq)               = ident . ident . ("ceq" ++) . nl
  cil (Dup)               = ident . ident . ("dup" ++) . nl
  cil (Ldarg x)           = ident . ident . ("ldarg " ++) . shows x . nl
  cil (Ldc_i4 x)          = ident . ident . ("ldc.i4 " ++) . shows x . nl 
  cil (Ldfld t a c f)     = ident . ident . ("ldfld " ++) . cil t . sp
                             . cilFld a c f . nl
  cil (Ldloc x)           = ident . ident . ("ldloc " ++) . shows x . nl
  cil (Ldloca x)          = ident . ident . ("ldloca " ++) . shows x . nl
  cil (Ldstr s)           = ident . ident . ("ldstr " ++) . shows s . nl
  cil (Neg)               = ident . ident . ("neg" ++) . nl
  cil (Newobj s t a c ps) = ident . ident . ("newobj " ++) . cil s . sp
                             . cil t . sp . cilNewobj a c ps . nl
  cil (Nop)               = ident . ident . ("nop" ++) . nl
  cil (Pop)               = ident . ident . ("pop" ++) . nl
  cil (Rem)               = ident . ident . ("rem" ++) . nl
  cil (Ret)               = ident . ident . ("ret" ++) . nl
  cil (Stfld t a c f)     = ident . ident . ("stfld " ++) . cil t . sp
                             . cilFld a c f . nl
  cil (Stloc x)           = ident . ident . ("stloc " ++) . shows x . nl
  cil (Sub)               = ident . ident . ("sub" ++) . nl
  cil (Tail)              = ident . ident . ("tail." ++) . nl

cilFld :: Name -> Name -> Name -> ShowS
cilFld a c f = 
    cilAssembly a
  . (if c /= ""
     then cilName c . ("::" ++)
     else id)
  . cilName f

cilNewobj :: Name -> Name -> [PrimitiveType] -> ShowS
cilNewobj a c ps = 
    cilAssembly a
  . (if c /= ""
     then cilName c . ("::" ++)
     else id)
  . (".ctor(" ++)
  . foldr (.) id (intersperse (", " ++) (map cil ps))
  . (")" ++)

cilCall :: Name -> Name -> Name -> [PrimitiveType] -> ShowS
cilCall a c m ps = 
    cilAssembly a
  . (if c /= ""
     then cilName c . ("::" ++)
     else id)
  . cilName m
  . ("(" ++)
  . foldr (.) id (intersperse (", " ++) (map cil ps))
  . (")" ++)

cilAssembly :: Name -> ShowS
cilAssembly a =
    (if a /= ""
     then ("[" ++) . cilName a . ("]" ++)
     else id)

data Association =
    Static
  | Instance

instance Cil Association where
  cil Static   = id
  cil Instance = ("instance" ++)

data PrimitiveType =
    Void
  | Bool
  | Char
  | Byte
  | Int32
  | Int64
  | String
  | Object
  | ValueType Name Name
  | ReferenceType Name Name

instance Cil PrimitiveType where
  cil Void            = ("void" ++) 
  cil Bool            = ("bool" ++)
  cil Char            = ("char" ++)
  cil Byte            = ("unsigned int8" ++)
  cil Int32           = ("int32" ++)
  cil Int64           = ("int64" ++)
  cil String          = ("string" ++)
  cil Object          = ("object" ++)
  cil (ValueType a c) = ("valuetype " ++) . cilAssembly a . cilName c
  cil (ReferenceType a c) = cilAssembly a . cilName c

-- Helper functions, to pretty print
ident = ("    " ++)
sp    = (" " ++)
nl    = ('\n' :)

