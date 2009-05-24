%%[0
%include lhs2TeX.fmt
%include afp.fmt
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% TyCore base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs module {%{EH}TyCore.Base} import({%{EH}Base.Builtin},{%{EH}Base.Common},{%{EH}Base.Opts})
%%]
%%[(8 codegen) hs import ({%{EH}TyCore},{%{EH}Ty.ToTyCore}) export(module {%{EH}TyCore},module {%{EH}Ty.ToTyCore})
%%]

%%[(8 codegen) hs import(Data.Maybe,Data.Char,Data.List,EH.Util.Pretty)
%%]

%%[(8 codegen) hs import(qualified Data.Map as Map,qualified Data.Set as Set)
%%]

-- import Ty only qualified
%%[(8 codegen) hs import(qualified {%{EH}Ty} as T)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Abstract syntax for encoding case+pattern rewrite info
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(RAlt(..),RPat(..),RPatConBind(..),RPatBind(..))
data RAlt
  = RAlt_Alt			{ rcaPats :: ![RPat], raaExpr :: !Expr, raaFailS :: UIDS }

data RPat
  = RPat_Var			{ rcpPNm :: !RPatNm, rcpTy :: !Ty }
  | RPat_Con			{ rcpPNm :: !RPatNm, rcpTy :: !Ty, rcpTag :: !CTag, rcpBinds :: !RPatConBind }
  | RPat_Int			{ rcpPNm :: !RPatNm, rcpTy :: !Ty, rcpInt :: !Integer }
  | RPat_Char			{ rcpPNm :: !RPatNm, rcpTy :: !Ty, rcpChar :: !Char }
  | RPat_Irrefutable	{ rcpPNm :: !RPatNm, rcpTy :: !Ty, rcpValBindL :: ![ValBind] }
%%[[97
  | RPat_BoolExpr		{ rcpPNm :: !RPatNm, rcpTy :: !Ty, rcpExpr :: !Expr }
%%]]

data RPatConBind
  = RPatConBind_One		{ rpcbRest :: !PatRest, rpcbBinds :: ![RPatBind] }
  | RPatConBind_Many	{ rpcbConBinds :: ![RPatConBind] }

data RPatBind
  = RPatBind_Bind		{ rpbLbl :: !HsName, rpbOffset :: !Expr, rpbNm :: !HsName, rpbPat :: !RPat }
%%]

%%[(8 codegen) hs export(rcaPat,raltLPatNms)
rcaPat :: RAlt -> RPat
rcaPat = head . rcaPats

raltLPatNms :: [RAlt] -> [RPatNm]
raltLPatNms = nub . sort . map (rcpPNm . rcaPat)
%%]

%%[(8 codegen) hs export(rcaTag)
rpatConTag :: RPat -> CTag
rpatConTag (RPat_Int  _ _ _ )  = ctagInt
rpatConTag (RPat_Char _ _ _ )  = ctagChar
rpatConTag p                   = rcpTag p

rcaTag :: RAlt -> CTag
rcaTag = rpatConTag . head . rcaPats
%%]

%%[(8 codegen) hs export(raltIsVar,raltIsConst)
raltIsVar :: RAlt -> Bool
raltIsVar (RAlt_Alt (RPat_Var _ _ : _) _ _)  = True
raltIsVar _                                  = False

raltIsConst :: RAlt -> Bool
raltIsConst (RAlt_Alt (p : _) _ _)
  = c p
  where c (RPat_Int   _ _ _) = True
        c (RPat_Char  _ _ _) = True
        c _                  = False
%%]

%%[(8 codegen) hs export(raltIsConMany)
raltIsConMany :: RAlt -> Bool
raltIsConMany (RAlt_Alt (RPat_Con _ _ _ (RPatConBind_Many _) : _) _ _) = True
raltIsConMany _                                                      = False
%%]

%%[(8 codegen) hs export(raltIsIrrefutable)
raltIsIrrefutable :: RAlt -> Bool
raltIsIrrefutable (RAlt_Alt (RPat_Irrefutable _ _ _ : _) _ _) = True
raltIsIrrefutable _                                         = False
%%]

%%[(97 codegen) hs export(raltIsBoolExpr)
raltIsBoolExpr :: RAlt -> Bool
raltIsBoolExpr (RAlt_Alt (RPat_BoolExpr _ _ _ : _) _ _)  = True
raltIsBoolExpr _                                       = False
%%]

Flatten bindings, delaying the handling of many bindings to the rewriting of case patterns.

%%[(8 codegen) hs export(rpatConBindUnFlatten)
rpatConBindUnFlatten :: RPatConBind -> [RPatConBind] -> RPatConBind
rpatConBindUnFlatten z []  = z
rpatConBindUnFlatten _ [b] = b
rpatConBindUnFlatten _ bs  = RPatConBind_Many bs
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Conversion from Rxxx -> Cxxx
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(rpat2Pat)
rpat2Pat :: RPat -> Pat
rpat2Pat p
  = case p of
      RPat_Var      n ty       -> Pat_Var (rpatNmNm n) ty
      RPat_Con      n ty t b   -> Pat_Con t r bs
                               where (r,bs) = rpatConBind2PatConBind b
      RPat_Int      n ty v     -> Pat_Int v ty
      RPat_Char     n ty v     -> Pat_Char v ty
%%[[97
      RPat_BoolExpr n ty v     -> Pat_BoolExpr v
%%]]
%%]

%%[(8 codegen) hs export(rpatConBind2PatConBind,rpatBind2FldBind)
rpatConBind2PatConBind :: RPatConBind -> (PatRest,[FldBind])
rpatConBind2PatConBind b
  = case b of
  	  RPatConBind_One 	r bs 	-> (r,map rpatBind2FldBind bs)
  	  RPatConBind_Many 	bs 		-> head (map rpatConBind2PatConBind bs)

rpatBind2FldBind :: RPatBind -> FldBind
rpatBind2FldBind (RPatBind_Bind l o n p) = FldBind_Fld n (rcpTy p) o		-- guaranteed to be a rpat with a Ty
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions for CMeta
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(metasDefault)
metasDefault :: Metas
metasDefault = (MetaBind_Plain,MetaVal_Val)
%%]

%%[(8 codegen) hs export(metasVal)
metasVal :: Metas -> MetaVal
metasVal (_,v) = v
%%]

%%[(8 codegen) hs export(metasMapVal)
metasMapVal :: (MetaVal -> MetaVal) -> Metas -> Metas
metasMapVal f (b,v) = (b,f v)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Context: what is above/below
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(WhatExpr(..))
data WhatExpr
  = ExprIsLam | ExprIsApp | ExprIsVar HsName | ExprIsInt Int | ExprIsOther
  deriving Eq
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Context: strictness as required by context
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(EvalCtx(..),isStrict)
data EvalCtx
  = EvalCtx_None         -- nothing known, no strictness required
  | EvalCtx_Eval         -- strictness (thus eval) required
  | EvalCtx_EvalUnbox    -- strictness (thus eval) + unboxing required
  deriving Eq

isStrict :: EvalCtx -> Bool
isStrict EvalCtx_Eval        = True
isStrict EvalCtx_EvalUnbox   = True
isStrict _                   = False
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Properties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(exprIsLam)
exprIsLam :: Expr -> Bool
exprIsLam (Expr_Lam _ _) = True
exprIsLam _              = False
%%]

%%[(8 codegen) hs export(valBindNm)
valBindNm :: ValBind -> HsName
valBindNm (ValBind_Val       n _ _ _) = n
-- valBindNm (ValBind_FFI _ _ _ n _  ) = n
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Remove duplicate bindings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(9 codegen) hs export(valBindLNub)
valBindLNub :: ValBindL -> ValBindL
valBindLNub = nubBy (\b1 b2 -> valBindNm b1 == valBindNm b2)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Name of a pattern var/con
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(RPatNm(..))
data RPatNm
  = RPatNmOrig {rpatNmNm :: !HsName}
  | RPatNmUniq {rpatNmNm :: !HsName}
  deriving Eq

instance Ord RPatNm where
  x `compare` y = rpatNmNm x `cmpHsNameOnNm` rpatNmNm y  

instance Show RPatNm where
  show pnm = show (rpatNmNm pnm)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Lifting to MetaVal tupled
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(metaLift)
metaLift' :: Functor f => MetaVal -> f x -> f (x,MetaVal)
metaLift' m = fmap (\x -> (x,m))

metaLift :: Functor f => f x -> f (x,MetaVal)
metaLift = metaLift' MetaVal_Val
%%]

%%[(9 codegen) hs export(metaLiftDict)
metaLiftDict :: Functor f => f x -> f (x,MetaVal)
metaLiftDict = metaLift' (MetaVal_Dict Nothing)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(mkValBind1Metas)
mkValBind1Metas :: HsName -> Metas -> Ty -> Expr -> ValBind
mkValBind1Metas n m t e = ValBind_Val n m t e
%%]

%%[(8 codegen) hs export(mkValBind1Meta)
mkValBind1Meta :: HsName -> MetaVal -> Ty -> Expr -> ValBind
mkValBind1Meta n m t e = mkValBind1Metas n (MetaBind_Plain,m) t e
%%]

%%[(8 codegen) hs export(mkValBind1)
mkValBind1 :: HsName -> Ty -> Expr -> ValBind
mkValBind1 n t e = mkValBind1Meta n MetaVal_Val t e
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(mkExprAppMeta,mkExprApp1Meta)
mkExprApp1Meta :: Expr -> Expr -> MetaVal -> Expr
mkExprApp1Meta f a m = Expr_App f [Arg_Val a m]

mkExprAppMeta :: Expr -> [(Expr,MetaVal)] -> Expr
mkExprAppMeta f as = foldl (\f (a,m) -> mkExprApp1Meta f a m) f as
%%]

%%[(8 codegen) hs export(mkExprAppTy,mkExprApp1Ty)
mkExprApp1Ty :: Expr -> Ty -> Expr
mkExprApp1Ty f t = Expr_App f [Arg_Ty t]

mkExprAppTy :: Expr -> [Ty] -> Expr
mkExprAppTy f as = foldl mkExprApp1Ty f as
%%]

%%[(8 codegen) hs export(mkExprApp,mkExprApp1)
mkExprApp1 :: Expr -> Expr -> Expr
mkExprApp1 f a = mkExprApp1Meta f a MetaVal_Val

mkExprApp :: Expr -> [Expr] -> Expr
mkExprApp f as = mkExprAppMeta f (metaLift as)
%%]

%%[(8 codegen) hs export(mkExprLamMeta,mkExprLam1Meta)
mkExprLam1Meta :: HsName -> MetaVal -> Ty -> Expr -> Expr
mkExprLam1Meta a m t e = Expr_Lam [ArgBind_Val a m t] e

mkExprLamMeta :: [(HsName,MetaVal,Ty)] -> Expr -> Expr
mkExprLamMeta as e = foldr (\(n,m,t) e -> mkExprLam1Meta n m t e) e as
%%]

%%[(8 codegen) hs export(mkExprLamTy,mkExprLam1Ty)
mkExprLam1Ty :: TyVarId -> Ty -> Expr -> Expr
mkExprLam1Ty a t e = Expr_Lam [ArgBind_Ty a t] e

mkExprLamTy :: [(TyVarId,Ty)] -> Expr -> Expr
mkExprLamTy as e = foldr (\(n,t) e -> mkExprLam1Ty n t e) e as
%%]

%%[(8 codegen) hs export(mkExprLam,mkExprLam1)
mkExprLam1 :: HsName -> Ty -> Expr -> Expr
mkExprLam1 a t e = mkExprLam1Meta a MetaVal_Val t e

mkExprLam :: [(HsName,Ty)] -> Expr -> Expr
mkExprLam as e = mkExprLamMeta [ (n,MetaVal_Val,t) | (n,t) <- as ] e
%%]

%%[(8 codegen) hs export(mkExprTuple,mkExprTuple')
mkExprTuple' :: CTag -> [Expr] -> Expr
mkExprTuple' t = mkExprApp (Expr_Tup t)

mkExprTuple :: [Expr] -> Expr
mkExprTuple = mkExprTuple' CTagRec
%%]

%%[(8 codegen) hs export(mkExprStrictInMeta)
mkExprStrictInMeta :: HsName -> MetaVal -> Ty -> Expr -> (Expr -> Expr) -> Expr
mkExprStrictInMeta nm m t e mkC = Expr_Let ValBindCateg_Strict [mkValBind1Meta nm m (mkTyUnThunk t) (mkExprUnThunk e)] (mkC (Expr_Var nm))
%%]

%%[(8 codegen) hs export(mkExprLet,mkExprLet')
mkExprLet' :: Bool -> ValBindCateg -> ValBindL -> Expr -> Expr
mkExprLet' merge c bs e
  = if null bs
    then e
    else case e of
           Expr_Let c' bs' e' | merge && c' == c
             -> Expr_Let c (bs++bs') e'
           _ -> Expr_Let c bs e

mkExprLet :: ValBindCateg -> ValBindL -> Expr -> Expr
mkExprLet c bs e = mkExprLet' False c bs e
%%]

%%[(8 codegen) hs export(mkExprLetRec,mkExprLetPlain,mkExprStrictIn,mkExprMbStrictIn)

mkExprLetRec :: ValBindL -> Expr -> Expr
mkExprLetRec = mkExprLet ValBindCateg_Rec

mkExprLetPlain ::  HsName -> Ty -> Expr -> Expr -> Expr
mkExprLetPlain nm t e = mkExprLet ValBindCateg_Plain [mkValBind1 nm t e]

mkExprStrictIn :: HsName -> Ty -> Expr -> (Expr -> Expr) -> Expr
mkExprStrictIn nm t e mkC = mkExprStrictInMeta nm MetaVal_Val t e mkC

mkExprMbStrictIn :: Maybe (HsName,Ty) -> Expr -> (Expr -> Expr) -> Expr
mkExprMbStrictIn (Just (nm,t)) e mkC = Expr_Let ValBindCateg_Strict [mkValBind1 nm t e] (mkC (Expr_Var nm))
mkExprMbStrictIn _             e mkC =                                                   mkC e
%%]

%%[(8888 codegen) hs
mkCMod :: Expr -> CModule
mkCMod e = CModule_Mod (hsnFromString "") e []
%%]

%%[(95 codegen) hs export(mkIf)
mkIf :: EHCOpts -> Maybe HsName -> Expr -> Expr -> Expr -> Expr
mkIf opts cn c t f
  = mkExprMbStrictIn (fmap (\n -> (n,tyBool opts)) cn) c
    $ (\c -> Expr_Case c
               [ Alt_Alt (Pat_Con (ctagFalse opts) PatRest_Empty []) f
               , Alt_Alt (Pat_Con (ctagTrue  opts) PatRest_Empty []) t
               ]
               (tcUndefined opts)
      )
%%]

%%[(99 codegen) hs export(mkMatchChar)
mkMatchChar :: EHCOpts -> Maybe HsName -> Char -> Expr -> Expr -> Expr -> Expr
mkMatchChar opts cn cchar cexpr t f
  = mkIf opts cn (tcEqChar opts cchar cexpr) t f
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Inspection/deconstruction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(exprMbVar,exprVar)
exprMbVar :: Expr -> Maybe HsName
exprMbVar (Expr_Var n)               = Just n
exprMbVar (Expr_Lam [] (Expr_Var n)) = Just n
exprMbVar _                          = Nothing

exprVar :: Expr -> HsName
exprVar = maybe hsnUnknown id . exprMbVar
%%]

%%[(8 codegen) hs export(exprTupFld)
exprTupFld :: Expr -> Expr
exprTupFld (Expr_TupIns _ _ _ _ e) = e
exprTupFld _                        = Expr_Var hsnUnknown
%%]

%%[(8 codegen) hs export(exprIsEvaluated)
exprIsEvaluated :: Expr -> Bool
exprIsEvaluated (Expr_Int  _ _) = True
exprIsEvaluated (Expr_Char _ _) = True
exprIsEvaluated _               = False
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Operator construction, expressed in terms of primitives
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(tcBuiltinApp)
tcBuiltinApp :: EHCOpts -> (EHBuiltinNames -> HsName) -> [Expr] -> Expr
tcBuiltinApp opts bnmOf args = Expr_Var (bnmOf $ ehcOptBuiltinNames opts) `mkExprApp` args
%%]

%%[(8 codegen) hs export(tcAddInt)
tcAddInt :: EHCOpts -> Expr -> Int -> Expr
tcAddInt opts e i
  = if i == 0
    then e
    else case e of
           Expr_Int i' t -> Expr_Int (toInteger i + i') t
           _             -> tcBuiltinApp opts ehbnPrimAddInt [e,tcInt i]
%%]

%%[(8 codegen) hs export(tcGtInt)
tcGtInt :: EHCOpts -> Expr -> Int -> Expr
tcGtInt opts e i = tcBuiltinApp opts ehbnPrimGtInt [e,tcInt i]
%%]

%%[(99 codegen) hs
tcEqChar :: EHCOpts -> Char -> Expr -> Expr
tcEqChar opts c e = tcBuiltinApp opts ehbnPrimEqChar [e,Expr_Char c tyChar]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Various construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(tcString)
tcString :: EHCOpts -> String -> Expr
tcString opts m = tcBuiltinApp opts ehbnPackedStringToString [Expr_String m (tyString opts)]
%%]

%%[(8 codegen) hs export(tcInt)
tcInt :: Int -> Expr
tcInt i = Expr_Int (toInteger i) tyInt
%%]

%%[(8 codegen) hs export(tcVarAsArg)
tcVarAsArg :: HsName -> Expr
tcVarAsArg n = mkExprThunk $ Expr_Var n
%%]

%%[(97 codegen) hs export(tcInteger)
tcInteger :: EHCOpts -> Integer -> Expr
tcInteger opts i = tcBuiltinApp opts ehbnPackedStringToInteger [Expr_String (show i) (tyString opts)]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Error
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(tcError,tcUndefined)
tcError :: EHCOpts -> String -> Expr
tcError opts m = tcBuiltinApp opts ehbnError [tcString opts m]

tcUndefined :: EHCOpts -> Expr
tcUndefined opts = tcBuiltinApp opts ehbnUndefined []
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Tags, in general
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(altConTag,altIntTag) 
patConTag :: Pat -> CTag
patConTag (Pat_Con  t _ _)  = t
patConTag (Pat_Int  _ _  )  = ctagInt
patConTag (Pat_Char _ _  )  = ctagChar

patIntTag :: Pat -> Int
patIntTag (Pat_Con  t _ _)  = ctagTag t
patIntTag (Pat_Int  i _  )  = fromInteger i
patIntTag (Pat_Char c _  )  = ord c

altConTag :: Alt -> CTag
altConTag (Alt_Alt p _) = patConTag p

altIntTag :: Alt -> Int
altIntTag (Alt_Alt p _) = patIntTag p
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Bool
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

In the following, note the hardcodedness!!!!!

%%[(95 codegen) hs export(ctagTrue, ctagFalse)
ctagTrue, ctagFalse :: EHCOpts -> CTag
ctagTrue  opts = CTag (ehbnDataBool $ ehcOptBuiltinNames opts) (ehbnBoolTrue  $ ehcOptBuiltinNames opts) 1 0 0		-- this makes it hardcoded, ideally dependent on datatype def itself !!
ctagFalse opts = CTag (ehbnDataBool $ ehcOptBuiltinNames opts) (ehbnBoolFalse $ ehcOptBuiltinNames opts) 0 0 0		-- this makes it hardcoded, ideally dependent on datatype def itself !!
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% List
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

In the following, note the hardcodedness!!!!!

%%[(97 codegen) hs export(ctagCons,ctagNil)
ctagCons, ctagNil :: EHCOpts -> CTag
ctagCons opts = CTag (ehbnDataList $ ehcOptBuiltinNames opts) (ehbnDataListAltCons $ ehcOptBuiltinNames opts) 0 2 2		-- this makes it hardcoded, ideally dependent on datatype def itself !!
ctagNil  opts = CTag (ehbnDataList $ ehcOptBuiltinNames opts) (ehbnDataListAltNil  $ ehcOptBuiltinNames opts) 1 0 2		-- this makes it hardcoded, ideally dependent on datatype def itself !!
%%]

%%[(99 codegen) hs export(mkListSingleton)
mkListSingleton :: EHCOpts -> Expr -> Expr
mkListSingleton opts e
  = mkExprApp (Expr_Tup $ ctagCons opts) [e,Expr_Tup $ ctagNil opts]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Var introduction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(VarIntro(..),emptyVarIntro)
data VarIntro
  = VarIntro
      { vintroLev		:: Int		-- lexical level
      , vintroMeta		:: MetaVal	-- meta info
      }

emptyVarIntro :: VarIntro
emptyVarIntro
  = VarIntro cLevExtern MetaVal_Val
%%]

%%[(8 codegen) hs export(VarIntroMp,VarIntroL,vintroLookup)
type VarIntroMp = Map.Map HsName VarIntro
type VarIntroL  = AssocL  HsName VarIntro

vintroLookup :: HsName -> VarIntroMp -> VarIntro
vintroLookup n m = Map.findWithDefault emptyVarIntro n m
%%]

%%[(8 codegen) hs export(cLevModule,cLevExtern)
cLevModule, cLevExtern :: Int
cLevModule = 0
cLevExtern = 0
%%]

%%[(20 codegen) hs export(cLevIntern)
cLevIntern :: Int
cLevIntern = 1
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Replacement in general
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(VarRepl(..))
data VarRepl r
  = VarRepl
      { vreplRepl		:: r		-- replacement
      , vreplMeta		:: MetaVal	-- meta info
      }
%%]

%%[(8 codegen) hs export(VarReplMp)
type VarReplMp  r = Map.Map HsName (VarRepl r)
type VarReplAsc r = AssocL  HsName (VarRepl r)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Replacement with HsName
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(VarReplNm,emptyVarReplNm)
type VarReplNm = VarRepl HsName

emptyVarReplNm :: VarReplNm
emptyVarReplNm = VarRepl hsnUnknown MetaVal_Val
%%]

%%[(8 codegen) hs export(VarReplNmMp,VarReplNmL)
type VarReplNmMp = VarReplMp  HsName
type VarReplNmL  = VarReplAsc HsName
%%]

%%[(8 codegen) hs export(vreplFromVarIntro)
vreplFromVarIntro :: VarIntro -> VarReplNm
vreplFromVarIntro i
  = emptyVarReplNm
      { vreplMeta 	= vintroMeta i
      }
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Support for transformations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(fvLev,fvsLev)
fvLev :: HsName -> VarIntroMp -> Int
fvLev n m = vintroLev $ vintroLookup n m

fvsLev :: VarIntroMp -> Int -> FvS -> Int
fvsLev lm lDflt fvs = foldr (\n l -> fvLev n lm `max` l) lDflt $ Set.toList $ fvs
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Known function arity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(ArityMp)
type ArityMp = Map.Map HsName Int
%%]

%%[(8 codegen) hs export(arityMpLookupLam,arityMpLookupCaf)
arityMpLookupLam :: HsName -> ArityMp -> Maybe Int
arityMpLookupLam n m
  = case Map.lookup n m of
      j@(Just a) | a > 0 -> j
      _                  -> Nothing

arityMpLookupCaf :: HsName -> ArityMp -> Maybe Int
arityMpLookupCaf n m
  = case Map.lookup n m of
      j@(Just a) | a == 0 -> j
      _                   -> Nothing
%%]

%%[(8 codegen) hs export(arityMpFilterLam,arityMpFilterCaf)
arityMpFilterLam :: ArityMp -> ArityMp
arityMpFilterLam = Map.filter (>0)

arityMpFilterCaf :: ArityMp -> ArityMp
arityMpFilterCaf = Map.filter (==0)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Name to offset (in a record)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(20 codegen) hs export(HsName2OffsetMp,HsName2OffsetMpMp)
type HsNameOffset      = Int
type HsName2OffsetMp   = Map.Map HsName HsNameOffset
type HsName2OffsetMpMp = Map.Map HsName (Int,HsName2OffsetMp)
%%]

%%[(20 codegen) hs export(offMpMpKeysSet)
offMpMpKeysSet :: HsName2OffsetMpMp -> Set.Set HsName
offMpMpKeysSet m = Set.unions [ Map.keysSet m' | (_,m') <- Map.elems m ]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Hole construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(9 codegen) hs export(mkExprPrHole,mkExprHole,mkExprLetHole)
mkExprHole :: EHCOpts -> UID -> Expr
mkExprHole opts = Expr_Var . mkHNm

mkExprPrHole :: EHCOpts -> PredOccId -> Expr
mkExprPrHole opts = mkExprHole opts . poiId

mkExprLetHole :: UID -> Expr -> Expr
mkExprLetHole i b = i `Expr_HoleLet` b
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Module merge
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(2020 codegen) hs
cModMerge :: [CModule] -> CModule
cModMerge mL
  = foldr1 cmb mL
  where get (Expr_Let c b e) = Expr_Let c b . get e
        get  _                = id
        cmb (CModule_Mod m1 e1 t1) (CModule_Mod m2 e2 t2)
          = CModule_Mod m2 (get e1 e2) (t1++t2)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Subst to replace CaseAltFail
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(CaseFailSubst)
type CaseFailSubst = Map.Map UID Expr
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Lam args merge of type and actual code
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Assumption: only singleton argument sequences in the type

%%[(8 codegen) hs export(tcMergeArgTypeAndCode)
tcMergeArgTypeAndCode :: [TySeq1L] -> [(HsName,Expr->Expr)] -> Expr -> Expr
tcMergeArgTypeAndCode ts as body
  = merge ts as
  where merge ((TySeq1_Val _ t:ts):tss) ((argNm,mkBody):as) = mkExprLam1   argNm    t (mkBody $ merge (ts:tss) as)
        merge ((TySeq1_Ty  v k:ts):tss)                 as  = mkExprLam1Ty (mknm v) k (         merge (ts:tss) as)
        merge (_                  :tss)                 as  =                                   merge     tss  as
        merge _                                         _   = body
        mknm = maybe uidStart id
%%]
