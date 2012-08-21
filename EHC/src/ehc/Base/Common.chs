%%[0
%include lhs2TeX.fmt
%include afp.fmt
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Common
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1 module {%{EH}Base.Common} import(UU.Scanner.Position,EH.Util.Utils,{%{EH}Base.HsName},{%{EH}Base.Builtin}) export(module {%{EH}Base.HsName})
%%]

%%[1 import({%{EH}Base.UID}) export(module {%{EH}Base.UID})
%%]

%%[1 import({%{EH}Base.AssocL}) export(module {%{EH}Base.AssocL})
%%]

%%[1 import(EH.Util.Pretty, Data.List) export(ppSpaced, ppCon, ppCmt)
%%]

%%[1 import(Control.Applicative((<|>)))
%%]

%%[1 export(ParNeed(..), ParNeedL, parNeedApp)
%%]

%%[1 export(Fixity(..))
%%]

%%[1 export(Range(..),emptyRange,builtinRange,mkRange1,mkRange2)
%%]

%%[1 export(NmLev,nmLevAbsent, nmLevBuiltin, nmLevOutside, nmLevModule)
%%]

%%[1 import(EH.Util.ScanUtils) export(tokMkQName,tokMkQNames,tokMkInt,tokMkStr)
%%]

%%[1.Token hs import(UU.Scanner.Token)
%%]

%%[2 import(qualified Data.Set as Set)
%%]

%%[5 -1.Token hs import({%{EH}Scanner.Token})
%%]

%%[2 export(unions)
%%]

%%[4 export(listCombineUniq)
%%]

%%[7777 export(Seq,mkSeq,unitSeq,concatSeq,"(<+>)",seqToList,emptySeq,concatSeqs,filterSeq)
%%]

%%[7_2 import(qualified Data.Map as Map, Data.Map(Map), Data.Set(Set))
%%]

%%[7_2 export(threadMap,Belowness(..), groupAllBy, mergeListMap)
%%]

%%[7 export(uidHNm, uidQualHNm)
%%]

%%[8 import (EH.Util.FPath,System.IO,System.Environment,System.Exit,Data.Char,Data.Maybe,Numeric)
%%]

%%[8 export(putCompileMsg)
%%]

%%[8 import (qualified Data.Map as Map) export(showPP,ppPair,ppFM)
%%]

%%[8 hs export(ctag,ppCTag,ppCTagInt)
%%]

%%[9 export(ppListV)
%%]

%%[9 export(snd3,thd)
%%]

%%[(8 codegen) import({%{EH}Base.Strictness}) export(module {%{EH}Base.Strictness})
%%]

%%[50 import(Control.Monad, {%{EH}Base.Binary}, {%{EH}Base.Serialize})
%%]

%%[9999 import({%{EH}Base.Hashable})
%%]
%%[9999 import({%{EH}Base.ForceEval})
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Printing of names with non-alpha numeric constants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(ppHsnNonAlpha,ppHsnEscaped,hsnEscapeeChars)
ppHsnEscaped :: Either Char (Set.Set Char) -> Char -> Set.Set Char -> HsName -> PP_Doc
ppHsnEscaped first escChar escapeeChars
  = \n -> let (nh:nt) = show n
          in  pp $ hd ++ chkhd nh ++ (concatMap esc nt)
  where (hd,chkhd) = either (\c -> ([c],(:""))) (\chs -> ("",\h -> if Set.member h chs then [escChar,h] else esc h)) first
        escapeeChars' = Set.unions [escapeeChars, Set.fromList [escChar]]
        hexChars      = Set.fromList $ ['\NUL'..' '] ++ "\t\r\n"
        esc c | Set.member c escapeeChars' = [escChar,c]
              | Set.member c hexChars      = [escChar,'x'] ++ pad_out (showHex (ord c) "")
              | otherwise                  = [c]
        pad_out ls = (replicate (2 - length ls) '0') ++ ls

hsnEscapeeChars :: Char -> ScanOpts -> Set.Set Char
hsnEscapeeChars escChar scanOpts
  = Set.fromList [escChar] `Set.union` scoSpecChars scanOpts `Set.union` scoOpChars scanOpts

ppHsnNonAlpha :: ScanOpts -> HsName -> PP_Doc
ppHsnNonAlpha scanOpts
  = p
  where escapeeChars = hsnEscapeeChars '$' scanOpts
        p n = let name = show n
              in  {- if name `elem`  scoKeywordsTxt scanOpts
                   then pp ('$' : '_' : name)
                   else -}
                        let s = foldr (\c r -> if c `Set.member` escapeeChars then '$':c:r else c:r) [] name
                         in  pp ('$':s)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Pred occurrence id
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 hs export(PredOccId(..))
newtype PredOccId
  = PredOccId
      { poiId       :: UID
      }
  deriving (Show,Eq,Ord)
%%]

%%[9 hs export(mkPrId,poiHNm)
mkPrId :: UID -> PredOccId
mkPrId u = PredOccId u

poiHNm :: PredOccId -> HsName
poiHNm = uidHNm . poiId
%%]

%%[9 export(mkPrIdCHR)
mkPrIdCHR :: UID -> PredOccId
mkPrIdCHR = mkPrId
%%]

%%[9 export(emptyPredOccId)
emptyPredOccId :: PredOccId
emptyPredOccId = mkPrId uidStart
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Pretty printing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1.PP.ppAppTop export(ppAppTop)
ppAppTop :: PP arg => (HsName,arg) -> [arg] -> PP_Doc -> PP_Doc
ppAppTop (conNm,con) argL dflt
  =  if       (  hsnIsArrow conNm
%%[[9
              || hsnIsPrArrow conNm
%%]]
              ) && length argL == 2
                                then  ppListSep "" "" (" " >|< con >|< " ") argL
     else if  hsnIsProd  conNm  then  ppParensCommas argL
%%[[5
     else if  hsnIsList  conNm  then  ppBracketsCommas argL
%%]]
%%[[7
     else if  hsnIsRec   conNm  then  ppListSep (hsnORec >|< con) hsnCRec "," argL
     else if  hsnIsSum   conNm  then  ppListSep (hsnOSum >|< con) hsnCSum "," argL
     else if  hsnIsRow   conNm  then  ppListSep (hsnORow >|< con) hsnCRow "," argL
%%]]
                                else  dflt
%%]

%%[99 export(ppAppTop')
ppAppTop' :: PP arg => (HsName,arg) -> [arg] -> [Bool] -> PP_Doc -> PP_Doc
ppAppTop' cc@(conNm,_) [_,a] [True,_] _ | hsnIsArrow conNm || hsnIsPrArrow conNm    = pp a
ppAppTop' cc argL _ dflt                                                            = ppAppTop cc argL dflt
%%]

%%[1.PP.NeededByExpr
ppCon :: HsName -> PP_Doc
ppCon nm =  if    hsnIsProd nm
            then  ppParens (text (replicate (hsnProdArity nm - 1) ','))
            else  pp nm

ppCmt :: PP_Doc -> PP_Doc
ppCmt p = "{-" >#< p >#< "-}"
%%]

%%[1.PP.Rest

ppSpaced :: PP a => [a] -> PP_Doc
ppSpaced = ppListSep "" "" " "

%%]

%%[7 export(ppFld,mkPPAppFun,mkPPAppFun')
ppFld :: String -> Maybe HsName -> HsName -> PP_Doc -> PP_Doc -> PP_Doc
ppFld sep positionalNm nm nmPP f
  = case positionalNm of
      Just pn | pn == nm -> f
      _                  -> nmPP >#< sep >#< f

mkPPAppFun' :: String -> HsName -> PP_Doc -> PP_Doc
mkPPAppFun' sep c p = if c == hsnRowEmpty then empty else p >|< sep

mkPPAppFun :: HsName -> PP_Doc -> PP_Doc
mkPPAppFun = mkPPAppFun' "|"
%%]

%%[7 export(mkExtAppPP,mkExtAppPP')
mkExtAppPP' :: String -> (HsName,PP_Doc,[PP_Doc]) -> (HsName,PP_Doc,[PP_Doc],PP_Doc) -> (PP_Doc,[PP_Doc])
mkExtAppPP' sep (funNm,funNmPP,funPPL) (argNm,argNmPP,argPPL,argPP)
  =  if hsnIsRec funNm || hsnIsSum funNm
     then (mkPPAppFun' sep argNm argNmPP,argPPL)
     else (funNmPP,funPPL ++ [argPP])

mkExtAppPP :: (HsName,PP_Doc,[PP_Doc]) -> (HsName,PP_Doc,[PP_Doc],PP_Doc) -> (PP_Doc,[PP_Doc])
mkExtAppPP = mkExtAppPP' "|"
%%]

%%[8
instance (PP a, PP b) => PP (a,b) where
  pp (a,b) = ppParensCommas' [pp a,pp b]
%%]

%%[8
ppPair :: (PP a, PP b) => (a,b) -> PP_Doc
ppPair (x,y) = ppParens (pp x >|< "," >|< pp y)
%%]

%%[8
showPP :: PP a => a -> String
showPP x = disp (pp x) 100 ""
%%]

%%[8
ppFM :: (PP k,PP v) => Map.Map k v -> PP_Doc
ppFM = ppAssocL . Map.toList
%%]

%%[9
ppListV :: PP a => [a] -> PP_Doc
ppListV = vlist . map pp
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Putting stuff on output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8
putCompileMsg :: Verbosity -> Verbosity -> String -> Maybe String -> HsName -> FPath -> IO ()
putCompileMsg v optsVerbosity msg mbMsg2 modNm fNm
  = if optsVerbosity >= v
    then do { hPutStrLn stdout (strBlankPad 40 msg ++ " " ++ strBlankPad 22 (show modNm) ++ " (" ++ fpathToStr fNm ++ maybe "" (\m -> ", " ++ m) mbMsg2 ++ ")")
            ; hFlush stdout
            }
    else return ()
%%]

%%[8 export(writePP, writeToFile)
writePP ::  (a -> PP_Doc) -> a -> FPath -> IO ()
writePP f text fp = writeToFile (show.f $ text) fp

writeToFile' :: Bool -> String -> FPath -> IO ()
writeToFile' binary str fp
  = do { (fn, fh) <- openFPath fp WriteMode binary
       ; (if binary then hPutStr else hPutStrLn) fh str
       ; hClose fh
       }

writeToFile :: String -> FPath -> IO ()
writeToFile = writeToFile' False

%%]

%%[(8 java) export(writeBinaryToFile)
writeBinaryToFile :: String -> FPath -> IO ()
writeBinaryToFile = writeToFile' True
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Prio computation for need of parenthesis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1.ParNeed
data ParNeed =  ParNotNeeded | ParNeededLow | ParNeeded | ParNeededHigh | ParOverrideNeeded
                deriving (Eq,Ord)

type ParNeedL = [ParNeed]

parNeedApp :: HsName -> (ParNeed,ParNeedL)
parNeedApp conNm
  =  let  pr  | hsnIsArrow  conNm   =  (ParNeededLow,[ParNotNeeded,ParNeeded])
              | hsnIsProd   conNm   =  (ParOverrideNeeded,repeat ParNotNeeded)
%%[[5
              | hsnIsList   conNm   =  (ParOverrideNeeded,[ParNotNeeded])
%%]]
%%[[7
              | hsnIsRec    conNm   =  (ParOverrideNeeded,[ParNotNeeded])
              | hsnIsSum    conNm   =  (ParOverrideNeeded,[ParNotNeeded])
              | hsnIsRow    conNm   =  (ParOverrideNeeded,repeat ParNotNeeded)
%%]]
              | otherwise           =  (ParNeeded,repeat ParNeededHigh)
     in   pr
%%]

%%[1 export(ppParNeed)
ppParNeed :: PP p => ParNeed -> ParNeed -> p -> PP_Doc
ppParNeed locNeed globNeed p
  = par (pp p)
  where par = if globNeed > locNeed then ppParens else id
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Belowness
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[7_2
data Belowness = Below | NotBelow | UnknownBelow deriving (Show,Eq,Ord)
%%]

%%[7_2
instance PP Belowness where
  pp Below        = pp "B+"
  pp NotBelow     = pp "B-"
  pp UnknownBelow = pp "B?"
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Tags (of data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 hs export(CTag(..),ctagIsRec,ctagTag,ctagChar,ctagInt,emptyCTag)
data CTag
  = CTagRec
  | CTag
      { ctagTyNm        :: !HsName
      , ctagNm          :: !HsName
      , ctagTag'        :: !Int
      , ctagArity       :: !Int
      , ctagMaxArity    :: !Int
      }
  deriving (Show,Eq,Ord)

ctagIsRec :: CTag -> Bool
ctagIsRec CTagRec = True
ctagIsRec t       = False

ctagTag :: CTag -> Int
ctagTag CTagRec = 0
ctagTag t       = ctagTag' t

ctagInt  =  CTag hsnInt  hsnInt  0 1 1
ctagChar =  CTag hsnChar hsnChar 0 1 1

emptyCTag = CTag hsnUnknown hsnUnknown 0 0 0
%%]

%%[9 export(mkClassCTag)
-- only used when `not ehcCfgClassViaRec'
mkClassCTag :: HsName -> Int -> CTag
mkClassCTag n sz = CTag n n 0 sz sz
%%]

%%[8 hs
ctag :: a -> (HsName -> HsName -> Int -> Int -> Int -> a) -> CTag -> a
ctag n t tg = case tg of {CTag tn cn i a ma -> t tn cn i a ma; _ -> n}

ppCTag :: CTag -> PP_Doc
ppCTag = ctag (pp "Rec") (\tn cn t a ma -> pp t >|< "/" >|< pp cn >|< "/" >|< pp a >|< "/" >|< pp ma)

ppCTagInt :: CTag -> PP_Doc
ppCTagInt = ctag (pp "-1") (\_ _ t _ _ -> pp t)

instance PP CTag where
  pp = ppCTag
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Label for expr
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 hs export(CLbl(..),clbl)
-- | Expressions in a CBound position optionally may be labelled
data CLbl
  = CLbl_None
  | CLbl_Nm
      { clblNm		:: !HsName
      }
  | CLbl_Tag
      { clblTag		:: !CTag
      }
  deriving (Show,Eq,Ord)

clbl :: a -> (HsName -> a) -> (CTag -> a) -> CLbl -> a
clbl f _ _  CLbl_None   = f
clbl _ f _ (CLbl_Nm  n) = f n
clbl _ _ f (CLbl_Tag t) = f t
%%]

%%[8 hs
instance PP CLbl where
  pp = clbl empty pp pp
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Unboxed values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 hs export(Unbox(..))
data Unbox
  = Unbox_FirstField
  | Unbox_Tag         !Int
  | Unbox_None
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Misc info passed to backend
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 hs export(CTagsMp, emptyCTagsMp)
type CTagsMp = AssocL HsName (AssocL HsName CTag)

emptyCTagsMp :: CTagsMp
emptyCTagsMp = []
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% List related, should move in time to general library
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.unions
unions :: Eq a => [[a]] -> [a]
unions = foldr union []
%%]

%%[4.listCombineUniq
listCombineUniq :: Eq a => [[a]] -> [a]
listCombineUniq = nub . concat
%%]

%%[7_2
threadMap :: (a -> c -> (b, c)) -> c -> [a] -> ([b], c)
threadMap f c = foldr (\a (bs, c) -> let (b, c') = f a c in (b:bs, c')) ([], c)
%%]

%%[7_2
groupAllBy :: Ord b => (a -> b) -> [a] -> [[a]]
groupAllBy f = Map.elems . foldr (\v -> Map.insertWith (++) (f v) [v]) Map.empty
%%]

%%[7_2
mergeListMap :: Ord k => Map k [a] -> Map k [a] -> Map k [a]
mergeListMap = Map.unionWith (++)
%%]

%%[8 export(replicateBy)
replicateBy :: [a] -> b -> [b]
replicateBy l e = replicate (length l) e
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Misc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(strPadLeft, strBlankPad)
strPadLeft :: Char -> Int -> String -> String
strPadLeft c n s = replicate (n - length s) c ++ s

strBlankPad :: Int -> String -> String
strBlankPad n s = s ++ replicate (n - length s) ' '
%%]

%%[9
snd3 :: (a,b,c) -> b
snd3 (a,b,c) = b

thd :: (a,b,c) -> c
thd (a,b,c) = c
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Verbosity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(Verbosity(..))
data Verbosity
  = VerboseQuiet | VerboseMinimal | VerboseNormal | VerboseALot | VerboseDebug
  deriving (Eq,Ord,Enum)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% CHR scoped translation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(CHRScoped(..))
data CHRScoped
  = CHRScopedInstOnly | CHRScopedMutualSuper | CHRScopedAll
  deriving (Eq,Ord)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Point in sequence of EH compilation phases
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1 export(CompilePoint(..))
data CompilePoint
  = CompilePoint_Imports
  | CompilePoint_Parse
  | CompilePoint_AnalHS
  | CompilePoint_AnalEH
%%[[(8 codegen)
  | CompilePoint_Core
%%]]
  | CompilePoint_All
  deriving (Eq,Ord,Show)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Fixity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1
data Fixity
  = Fixity_Infix | Fixity_Infixr | Fixity_Infixl
  deriving (Eq,Ord,Show,Enum)

instance PP Fixity where
  pp Fixity_Infix  = pp "infix"
  pp Fixity_Infixl = pp "infixl"
  pp Fixity_Infixr = pp "infixr"
%%]

%%[1 export(fixityMaxPrio)
fixityMaxPrio :: Int
fixityMaxPrio = 9
%%]

%%[91 export(fixityAppPrio)
fixityAppPrio :: Int
fixityAppPrio = fixityMaxPrio + 1
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Eq,Ord for Pos
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1
instance Eq Pos where
  p1 == p2 = line p1 == line p2 && column p1 == column p2

instance Ord Pos where
  compare p1 p2
    = case compare (line p1) (line p2) of
        EQ -> compare (column p1) (column p2)
        c  -> c
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Range
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1
data Range
  = Range_Range    !Pos !Pos
  | Range_Unknown
  | Range_Builtin

emptyRange :: Range
emptyRange = Range_Unknown

builtinRange :: Range
builtinRange = Range_Builtin

mkPos :: Position p => p -> Pos
mkPos p = Pos (line p) (column p) (file p)

mkRange1 :: Position p => p -> Range
mkRange1 p = Range_Range (mkPos p) noPos

mkRange2 :: Position p => p -> p -> Range
mkRange2 p1 p2 = Range_Range (mkPos p1) (mkPos p2)
%%]

%%[1
show2Pos :: Pos -> Pos -> String
show2Pos p1 p2
  | p1 /= p2 && p2 /= noPos  = if line p1 == line p2
                               then mk (show (line p1))                          (Just $ show (column p1) ++ "-" ++ show (column p2))
                               else mk (show (line p1) ++ "-" ++ show (line p2)) Nothing
  | otherwise                =      mk (show (line p1))                          (Just $ show (column p1))
  where mk l c = file p1 ++ ":" ++ l ++ maybe "" (":" ++) c
%%]

%%[1
instance Show Range where
  show (Range_Range p q) = show2Pos p q
  show Range_Unknown     = "??"
  show Range_Builtin     = "builtin"

instance PP Range where
  pp = pp . show
%%]

%%[1 export(isEmptyRange)
isEmptyRange :: Range -> Bool
isEmptyRange  Range_Unknown    = True
isEmptyRange (Range_Range p _) = p == noPos
isEmptyRange  _                = False
%%]

20100209 AD: The lax equality/compare goes badly with serialization. TBD: fix this...

%%[50
instance Eq Range where
  _ == _ = True             -- a Range is ballast, not a criterium to decide equality for

instance Ord Range where
  _ `compare` _ = EQ        -- a Range is ballast, not a criterium to decide equality for
%%]

%%[1
rngAdd :: Range -> Range -> Range
rngAdd r1 r2
  = case (r1,r2) of
      (Range_Range l1 h1,Range_Range l2 h2)
        -> Range_Range (l1 `min` l2) (h1 `max` h2)
      (Range_Range _ _,_)
        -> r1
      (_,Range_Range _ _)
        -> r2
      _ -> Range_Unknown
%%]

%%[5 export(rangeUnion,rangeUnions)
posMax, posMin :: Pos -> Pos -> Pos
posMax (Pos l1 c1 f1) (Pos l2 c2 _) = Pos (l1 `max` l2) (c1 `max` c2) f1
posMin (Pos l1 c1 f1) (Pos l2 c2 _) = Pos (l1 `min` l2) (c1 `min` c2) f1

rangeUnion :: Range -> Range -> Range
rangeUnion (Range_Range b1 e1) (Range_Range b2 e2) = Range_Range (b1 `posMin` b2) (e1' `posMax` e2')
                                                  where e1' = if e1 == noPos then b1 else e1
                                                        e2' = if e2 == noPos then b2 else e2
rangeUnion Range_Unknown       r2                  = r2
rangeUnion r1                  _                   = r1

rangeUnions :: [Range] -> Range
rangeUnions = foldr1 rangeUnion
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Lifting of Range
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1.rngLift export(RngLiftArg,rngLift,rngAntilift)
type RngLiftArg  x = x
type RngLift     x = Range -> RngLiftArg x -> x

rngLift :: RngLift v
rngLift r v = v

rngAntilift :: v -> RngLiftArg v
rngAntilift = id
%%]

%%[99 -1.rngLift export(RngLiftArg,rngLift,rngAntilift)
type RngLiftArg  x = Range -> x
type RngLift     x = Range -> RngLiftArg x -> x

rngLift :: RngLift v
rngLift r mkv
  = x `seq` x
  where x = mkv r

rngAntilift :: v -> RngLiftArg v
rngAntilift = const
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Instance variant
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(InstVariant(..))
data InstVariant
  = InstNormal | InstDefault
%%[[91
  | InstDeriving InstDerivingFrom
%%]]
  deriving (Eq,Ord,Show)
%%]

%%[91 export(InstDerivingFrom(..))
-- | Either a deriving combined from a datatype directly or a standalone
data InstDerivingFrom
  = InstDerivingFrom_Datatype
  | InstDerivingFrom_Standalone
  deriving (Eq,Ord,Show)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Levels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1 hs
type NmLev = Int

nmLevAbsent, nmLevBuiltin, nmLevOutside, nmLevModule :: NmLev
nmLevAbsent  = -3
nmLevBuiltin = -2
nmLevOutside = -1
nmLevModule  =  0
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Token related
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1.tokenVal hs export(tokenVal)
tokenVal = genTokVal
%%]

%%[5 -1.tokenVal hs
%%]

%%[1 hs
-- Assumption: tokTpIsInt (genTokTp t) == True
tokMkInt :: Token -> Int
tokMkInt t
  = case genTokTp t of
      Just TkInteger10 -> read v
      _                -> 0
  where v = tokenVal t

tokMkStr :: Token -> String
tokMkStr = tokenVal
%%]

%%[1.tokMkQName hs
tokMkQName :: Token -> HsName
tokMkQName = hsnFromString . tokenVal
%%]

%%[7 -1.tokMkQName hs
tokMkQName :: Token -> HsName
tokMkQName t
  = case genTokTp t of
      Just tp | tokTpIsInt tp -> mkHNmPos $ tokMkInt t
      _                       -> mkHNm $ map hsnFromString $ tokenVals t
%%]
      _                       -> mkHNm $ concat $ intersperse "." $ tokenVals t		-- ok
      _                       -> mkHNm $ concat $ tokenVals t						-- not ok

%%[1 hs
tokMkQNames :: [Token] -> [HsName]
tokMkQNames = map tokMkQName

instance HSNM Token where
  mkHNm = tokMkQName
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Name supply, without uniqueness required
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1 hs export(hsnLclSupply,hsnLclSupplyWith)
hsnLclSupplyWith :: HsName -> [HsName]
hsnLclSupplyWith n = map (\i -> hsnSuffix n $ "_" ++ show i) [1..]

hsnLclSupply :: [HsName]
hsnLclSupply = hsnLclSupplyWith (hsnFromString "")
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Hex printing, dissecting numbers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(splitByRadix)
splitByRadix :: (Integral b) => Int -> Int -> b -> (Int,[Int])
splitByRadix len radix num
  = ( fromIntegral $ signum num
    , replicate difflen 0 ++ drop (-difflen) repr
    )
  where radix' = fromIntegral radix
        repr = reverse $
               unfoldr
                 (\b -> if b == 0
                        then Nothing
                        else let (q,r) = b `divMod` radix'
                             in  Just (fromIntegral r, q))
                 (abs num)
        difflen = len - length repr
%%]

%%[8 export(strHex)
strHex :: (Show a, Integral a) => Int -> a -> String
strHex prec x
  = replicate (prec - length h) '0' ++ h
  where h = showHex x []
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Backends
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(Backend(..))
data Backend
  = BackendGrinByteCode
  | BackendSilly
  deriving (Eq, Ord)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Fake AG dependency: first param is not used, only introduces an AG dependency
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[1
%%]
agFakeDependOn :: a -> b -> b
agFakeDependOn _ x = x

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Substitutable name (used by CHR)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(VarUIDHsName(..),vunmNm)
data VarUIDHsName
  = VarUIDHs_Name       { vunmId :: !UID, vunmNm' :: !HsName }
  | VarUIDHs_UID        { vunmId :: !UID }
  | VarUIDHs_Var        !UID
  deriving (Eq, Ord)

vunmNm :: VarUIDHsName -> HsName
vunmNm (VarUIDHs_Name _ n) = n
vunmNm (VarUIDHs_UID  i  ) = mkHNm i
vunmNm _                   = panic "Common.assnmNm"
%%]

%%[9 export(vunmMbVar)
vunmMbVar :: VarUIDHsName -> Maybe UID
vunmMbVar (VarUIDHs_Var v) = Just v
vunmMbVar _                = Nothing
%%]

%%[9
instance Show VarUIDHsName where
  show (VarUIDHs_Name _ n) = show n
  show (VarUIDHs_UID  i  ) = show i
  show (VarUIDHs_Var  i  ) = show i

instance PP VarUIDHsName where
  pp a = pp $ show a
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Generic lookup wrapper checking for cycles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2 hs
withLkupLiftCyc2 :: (t -> Maybe UID) -> (t -> UIDS) -> (UID -> Maybe t) -> x -> (UIDS -> t -> x) -> (t -> x) -> UIDS -> UID -> x
withLkupLiftCyc2 get noVisit lookup dflt yes no vsVisited v
  = case lookup v of
      Just t | not (v `Set.member` vsVisited)
        -> yes (Set.insert v $ Set.union (noVisit t) vsVisited) t
      _ -> dflt
%%]

%%[2 hs export(withLkupLiftCyc1,withLkupChkVisitLift,withLkupLift)
withLkupLiftCyc1 :: (t -> Maybe UID) -> (t -> UIDS) -> (UID -> Maybe t) -> (UIDS -> t -> x) -> (t -> x) -> UIDS -> t -> x
withLkupLiftCyc1 get noVisit lookup yes no vsVisited t
  = maybe dflt (withLkupLiftCyc2 get noVisit lookup dflt yes no vsVisited) $ get t
  where dflt = no t

withLkupChkVisitLift :: (t -> Maybe UID) -> (t -> UIDS) -> (UID -> Maybe t) -> (t -> x) -> (t -> x) -> t -> x
withLkupChkVisitLift get noVisit lookup yes no t
  = withLkupLiftCyc1 get noVisit lookup (\_ t -> yes t) no Set.empty t

withLkupLift :: (t -> Maybe UID) -> (UID -> Maybe t) -> (t -> x) -> (t -> x) -> t -> x
withLkupLift get
  = withLkupChkVisitLift get (const Set.empty)
%%]

%%[2 hs
lookupLiftCyc1 :: (x -> Maybe UID) -> (UID -> Maybe x) -> x' -> (x->x') -> x -> x'
lookupLiftCyc1 get lookup dflt found x
  = lk Set.empty dflt found x
  where lk s dflt found x = withLkupLiftCyc1 get (const Set.empty) lookup (\s t -> lk s (found t) found t) (const dflt) s x

lookupLiftCyc2 :: (x -> Maybe UID) -> (UID -> Maybe x) -> x' -> (x->x') -> UID -> x'
lookupLiftCyc2 get lookup dflt found x
  = maybe dflt (\x -> lookupLiftCyc1 get lookup (found x) found x) $ lookup x
%%]

%%[2 export(lookupLiftCycMb1,lookupLiftCycMb2)
lookupLiftCycMb1 :: (x -> Maybe UID) -> (UID -> Maybe x) -> x -> Maybe x
lookupLiftCycMb1 get lookup x = lookupLiftCyc1 get lookup Nothing Just x

lookupLiftCycMb2 :: (x -> Maybe UID) -> (UID -> Maybe x) -> UID -> Maybe x
lookupLiftCycMb2 get lookup x = lookupLiftCyc2 get lookup Nothing Just x
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Presence of something (just a boolean with meaning)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(Presence(..))
data Presence = Present | Absent deriving (Eq,Ord,Show)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Combinations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(combineToDistinguishedElts)
-- | Combine [[x1..xn],..,[y1..ym]] to [[x1..y1],[x2..y1],..,[xn..ym]].
--   Each element [xi..yi] is distinct based on the the key k in xi==(k,_)
combineToDistinguishedElts :: Eq k => [AssocL k v] -> [AssocL k v]
combineToDistinguishedElts []     = []
combineToDistinguishedElts [[]]   = []
combineToDistinguishedElts [x]    = map (:[]) x
combineToDistinguishedElts (l:ls)
  = combine l $ combineToDistinguishedElts ls
  where combine l ls
          = concatMap (\e@(k,_)
                         -> mapMaybe (\ll -> maybe (Just (e:ll)) (const Nothing) $ lookup k ll)
                                     ls
                      ) l
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Run length encoded list
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(RLList(..))
newtype RLList a
  = RLList [(a,Int)]
  deriving (Eq)

instance Ord a => Ord (RLList a) where
  (RLList [])           `compare` (RLList [])           = EQ
  (RLList [])           `compare` (RLList _ )           = LT
  (RLList _ )           `compare` (RLList [])           = GT
  (RLList ((x1,c1):l1)) `compare` (RLList ((x2,c2):l2)) | x1 == x2 = if c1 == c2
                                                                     then RLList l1 `compare` RLList l2
                                                                     else c1 `compare` c2
                                                        | x1 <  x2 = LT
                                                        | x1 >  x2 = GT
%%]

%%[9 export(rllConcat,rllSingleton,rllEmpty,rllToList,rllFromList)
rllConcat :: Eq a => RLList a -> RLList a -> RLList a
rllConcat (RLList []) rll2  = rll2
rllConcat rll1 (RLList [])  = rll1
rllConcat (RLList l1) (RLList l2@(h2@(x2,c2):t2))
                            | x1 == x2  = RLList (h1 ++ [(x1,c1+c2)] ++ t2)
                            | otherwise = RLList (l1 ++ l2)
                            where (h1,t1@(x1,c1)) = fromJust (initlast l1)

rllEmpty :: RLList a
rllEmpty = RLList []

rllSingleton :: a -> RLList a
rllSingleton x = RLList [(x,1)]

rllToList :: RLList a -> [a]
rllToList (RLList l) = concatMap (\(x,c) -> replicate c x) l

rllFromList :: Eq a => [a] -> RLList a
rllFromList l = RLList [ (x,length g) | g@(x:_) <- group l ]
%%]

%%[9 export(rllLength,rllNull)
rllLength :: RLList a -> Int
rllLength (RLList l) = sum $ map snd l

rllNull :: RLList a -> Bool
rllNull (RLList []) = True
rllNull (RLList _ ) = False
%%]

%%[9 export(rllIsPrefixOf)
rllIsPrefixOf :: Eq a => RLList a -> RLList a -> Bool
rllIsPrefixOf (RLList []) _ = True
rllIsPrefixOf _ (RLList []) = False
rllIsPrefixOf (RLList ((x1,c1):l1)) (RLList ((x2,c2):l2))
                            | x1 == x2  = if c1 < c2
                                          then True
                                          else if c1 > c2
                                          then False
                                          else rllIsPrefixOf (RLList l1) (RLList l2)
                            | otherwise = False
%%]

%%[9 export(rllInits,rllInit,rllInitLast)
rllInitLast :: Eq a => RLList a -> Maybe (RLList a,a)
rllInitLast (RLList l ) = il [] l
                        where il acc [(x,1)]    = Just (RLList (reverse acc),x)
                              il acc [(x,c)]    = Just (RLList (reverse ((x,c-1):acc)),x)
                              il acc (a:as)     = il (a:acc) as
                              il _   _          = Nothing

rllInit :: Eq a => RLList a -> RLList a
rllInit = fst . fromJust . rllInitLast

rllInits :: Eq a => RLList a -> [RLList a]
rllInits = map rllFromList . inits . rllToList
%%]

%%[9 export(rllHeadTail)
rllHeadTail :: RLList a -> Maybe (a,RLList a)
rllHeadTail (RLList [])        = Nothing
rllHeadTail (RLList ((x,1):t)) = Just (x,RLList t)
rllHeadTail (RLList ((x,c):t)) = Just (x,RLList ((x,c-1):t))
%%]

%%[9
instance Show a => Show (RLList a) where
  show = show . rllToList
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% AlwaysEq
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

General purpose info for which comparison always yields EQ.
This is to fool 'deriving' when info is added for debugging purposes only.

%%[1 export(AlwaysEq(..))
data AlwaysEq a = AlwaysEq a

instance Eq (AlwaysEq a) where
  _ == _ = True

instance Ord (AlwaysEq a) where
  _ `compare` _ = EQ

instance Show a => Show (AlwaysEq a) where
  show (AlwaysEq x) = show x

instance PP a => PP (AlwaysEq a) where
  pp (AlwaysEq x) = pp x
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Package name
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[99 export(PkgName)
type PkgName = String
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Derivation tree ways of printing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(99 tyderivtree) export(DerivTreeWay(..))
data DerivTreeWay
  = DerivTreeWay_Infer      -- follow order of inference when printing type variables
  | DerivTreeWay_Final      -- use final mapping of type variables instead
  | DerivTreeWay_None       -- no printing
  deriving Eq
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Row specific
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[7777 hs export(rowCanonOrderBy)
-- order on ...
rowCanonOrderBy :: (o -> o -> Ordering) -> AssocL o a -> AssocL o a
rowCanonOrderBy cmp = sortByOn cmp fst
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Meta levels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2 hs export(MetaLev)
type MetaLev = Int
%%]

%%[4 hs export(metaLevVal)
metaLevVal :: MetaLev
metaLevVal = 0
%%]

%%[6 hs export(metaLevTy, metaLevKi, metaLevSo)
metaLevTy, metaLevKi, metaLevSo :: MetaLev
metaLevTy  = metaLevVal + 1
metaLevKi  = metaLevTy  + 1
metaLevSo  = metaLevKi  + 1
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Instances: Typeable, Data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[50
deriving instance Typeable VarUIDHsName
deriving instance Data VarUIDHsName

deriving instance Typeable Fixity
deriving instance Data Fixity

deriving instance Typeable1 AlwaysEq
deriving instance Data x => Data (AlwaysEq x)

deriving instance Typeable PredOccId
deriving instance Data PredOccId

deriving instance Typeable1 RLList
deriving instance Data x => Data (RLList x)

deriving instance Typeable CLbl
deriving instance Data CLbl

deriving instance Typeable CTag
deriving instance Data CTag

deriving instance Typeable Range
deriving instance Data Range

deriving instance Typeable Pos
deriving instance Data Pos

%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% HsName functionality for UID
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[7
uidHNm :: UID -> HsName
uidHNm = mkHNm -- hsnFromString . show
%%]

%%[7
uidQualHNm :: HsName -> UID -> HsName
uidQualHNm modnm uid =
%%[[50
                        hsnPrefixQual modnm $
%%]]
                        uidHNm uid
%%]

%%[1
instance HSNM UID where
  mkHNm x = hsnFromString ('_' : show x)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Instances: Binary, Serialize
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[50
instance Serialize VarUIDHsName where
  sput (VarUIDHs_Name a b) = sputWord8 0 >> sput a >> sput b
  sput (VarUIDHs_UID  a  ) = sputWord8 1 >> sput a
  sput (VarUIDHs_Var  a  ) = sputWord8 2 >> sput a
  sget = do t <- sgetWord8
            case t of
              0 -> liftM2 VarUIDHs_Name sget sget
              1 -> liftM  VarUIDHs_UID  sget
              2 -> liftM  VarUIDHs_Var  sget

instance Serialize CLbl where
  sput (CLbl_Nm   a  ) = sputWord8 0 >> sput a
  sput (CLbl_Tag  a  ) = sputWord8 1 >> sput a
  sput (CLbl_None    ) = sputWord8 2
  sget = do t <- sgetWord8
            case t of
              0 -> liftM  CLbl_Nm 	sget
              1 -> liftM  CLbl_Tag  sget
              2 -> return CLbl_None

instance Binary Fixity where
  put = putEnum8
  get = getEnum8

instance Serialize Fixity where
  sput = sputPlain
  sget = sgetPlain

instance Binary KnownPrim where
  put = putEnum8
  get = getEnum8

instance Serialize KnownPrim where
  sput = sputPlain
  sget = sgetPlain

instance Binary x => Binary (AlwaysEq x) where
  put (AlwaysEq x) = put x
  get = liftM AlwaysEq get

instance Serialize x => Serialize (AlwaysEq x) where
  sput (AlwaysEq x) = sput x
  sget = liftM AlwaysEq sget

instance Binary PredOccId where
  put (PredOccId a) = put a
  get = liftM PredOccId get

instance Serialize PredOccId where
  sput = sputPlain
  sget = sgetPlain

instance Binary a => Binary (RLList a) where
  put (RLList a) = put a
  get = liftM RLList get

instance Serialize CTag where
  sput = sputShared
  sget = sgetShared
  sputNested (CTagRec          ) = sputWord8 0
  sputNested (CTag    a b c d e) = sputWord8 1 >> sput a >> sput b >> sput c >> sput d >> sput e
  sgetNested
    = do t <- sgetWord8
         case t of
           0 -> return CTagRec
           1 -> liftM5 CTag    sget sget sget sget sget

instance Binary Range where
  put (Range_Unknown    ) = putWord8 0
  put (Range_Builtin    ) = putWord8 1
  put (Range_Range   a b) = putWord8 2 >> put a >> put b
  get = do t <- getWord8
           case t of
             0 -> return Range_Unknown
             1 -> return Range_Builtin
             2 -> liftM2 Range_Range get get

instance Serialize Range where
  sput = sputShared
  sget = sgetShared
  sputNested = sputPlain
  sgetNested = sgetPlain

instance Binary Pos where
  put (Pos a b c) = put a >> put b >> put c
  get = liftM3 Pos get get get
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Constants as appearing directly from the source text, without class related toInteger (etc) interpretation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[97 export(SrcConst(..))
data SrcConst
  = SrcConst_Int    Integer
  | SrcConst_Char   Char
  | SrcConst_Ratio  Integer Integer
  deriving (Eq,Show,Ord)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Lifting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(fmap2Tuple)
fmap2Tuple :: Functor f => snd -> f x -> f (x,snd)
fmap2Tuple snd = fmap (\x -> (x,snd))
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Name generation for variables, mapping from arbitrary to concise name from ['a' .. ]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(genNmMap)
genNmMap :: Ord x => (String->s) -> [x] -> Map.Map x s -> (Map.Map x s, [s])
genNmMap mk xs m
  = (m',reverse ns)
  where (m',_,ns)
          = foldl (\(m,sz,ns) x
                    -> case Map.lookup x m of
                         Just n -> (m, sz, n:ns)
                         _      -> (Map.insert x n m, sz+1, n:ns)
                                where n = mk $ ch sz
                  )
                  (m,Map.size m,[]) xs
        ch x | x < 26    = [chr $ ord 'a' + x]
             | otherwise = let (q,r) = x `quotRem` 26 in ch q ++ ch r
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Variation of Maybe
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) export(MaybeOk(..),isJustOk,isNotOk,maybeOk,fromJustOk,fromNotOk)
data MaybeOk a
  = JustOk  a
  | NotOk   String
  deriving (Eq,Ord,Show)

isJustOk (JustOk _) = True
isJustOk _          = False

fromJustOk (JustOk x) = x
fromJustOk _          = panic "fromJustOk"

isNotOk (NotOk _) = True
isNotOk _         = False

fromNotOk (NotOk x) = x
fromNotOk _         = panic "fromNotOk"

maybeOk :: (String -> x) -> (a -> x) -> MaybeOk a -> x
maybeOk _ j (JustOk x) = j x
maybeOk n _ (NotOk  x) = n x
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Visit as graph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[99 export(graphVisit)
-- | Abstract graph visit, over arbitrary structures
graphVisit
  :: (Ord node)
     => (thr -> graph -> node -> (thr,Set.Set node))        -- fun: visit node, get new thr and nodes to visit next
     -> (Set.Set node -> Set.Set node -> Set.Set node)      -- fun: combine new to visit + already known to visit (respectively)
     -> thr                                                 -- the accumulator, threaded as state
     -> Set.Set node                                        -- root/start
     -> graph                                               -- graph over which we visit
     -> thr                                                 -- accumulator is what we are interested in
graphVisit visit unionUnvisited thr start graph
  = snd $ v ((Set.empty,start),thr)
  where v st@((visited,unvisited),thr)
          | Set.null unvisited = st
          | otherwise          = let (n,unvisited2)      = Set.deleteFindMin unvisited
                                     (thr',newUnvisited) = visit thr graph n
                                     visited'            = Set.insert n visited
                                     unvisited3          = unionUnvisited (newUnvisited `Set.difference` visited') unvisited2
                                 in  v ((visited',unvisited3),thr')
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Known primitives, encoding semantics of particular primitives in a FFI decl, propagated to backend
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) export(KnownPrim(..))
data KnownPrim
  =
    -- platform Int
    KnownPrim_AddI
  | KnownPrim_SubI
  | KnownPrim_MulI

%%[[97
    -- platform Float
  | KnownPrim_AddF
  | KnownPrim_SubF
  | KnownPrim_MulF

    -- platform Double
  | KnownPrim_AddD
  | KnownPrim_SubD
  | KnownPrim_MulD

    -- 8 bit
  | KnownPrim_Add8          -- add: 1 byte / 8 bit, etc etc
  | KnownPrim_Sub8
  | KnownPrim_Mul8

    -- 16 bit
  | KnownPrim_Add16
  | KnownPrim_Sub16
  | KnownPrim_Mul16

    -- 32 bit
  | KnownPrim_Add32
  | KnownPrim_Sub32
  | KnownPrim_Mul32

    -- 64 bit
  | KnownPrim_Add64
  | KnownPrim_Sub64
  | KnownPrim_Mul64
%%]]
  deriving (Show,Eq,Enum,Bounded)
%%]

%%[(50 codegen)
deriving instance Data KnownPrim
deriving instance Typeable KnownPrim
%%]

%%[(8 codegen)
instance PP KnownPrim where
  pp = pp . show
%%]

%%[(8 codegen) export(allKnownPrimMp)
allKnownPrimMp :: Map.Map String KnownPrim
allKnownPrimMp
  = Map.fromList [ (drop prefixLen $ show t, t) | t <- [ minBound .. maxBound ] ]
  where prefixLen = length "KnownPrim_"
%%]

