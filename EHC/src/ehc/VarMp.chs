%%[0
%include lhs2TeX.fmt
%include afp.fmt

%if style == poly
%format sl1
%format sl1'
%format sl2
%format sl2'
%endif
%%]

%%[doesWhat doclatex
A VarMp maps from variables (tvars, ...) to whatever else has to be
mapped to (Ty, ...).

Starting with variant 6 (which introduces kinds) it allows multiple meta
level mapping, in that the VarMp holds mappings for multiple meta
levels. This allows one map to both map to base level info and to higher
levels. In particular this is used by fitsIn which also instantiates
types, and types may quantify over type variables with other kinds than
kind *, which must be propagated. A separate map could have been used,
but this holds the info together and is extendible to more levels.

A multiple level VarMp knows its own absolute metalevel, which is the default to use for lookup.
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Substitution for types
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2 module {%{EH}VarMp} import(Data.List, {%{EH}Base.Common}, {%{EH}Ty}) export(VarMp'(..), VarMp)
%%]

%%[2 import(qualified Data.Map as Map,qualified Data.Set as Set,Data.Maybe)
%%]

%%[2 import(EH.Util.Pretty, {%{EH}Ty.Pretty}) export(ppVarMpV)
%%]

%%[4 export(varmpFilterTy,varmpDel,(|\>))
%%]

%%[4
%%]

%%[4 import({%{EH}Error})
%%]

%%[(4_2) import(Maybe) export(varmpDelAlphaRename,varmpFilterAlphaRename,varmpFilterTyAltsMappedBy)
%%]

%%[(4_2) export(tyAsVarMp',varmpTyRevUnit)
%%]

%%[6 import({%{EH}VarLookup}) export(module {%{EH}VarLookup})
%%]

%%[6 import({%{EH}Base.Debug}) export(VarMpInfo(..))
%%]

%%[8 import(EH.Util.Utils)
%%]

%%[50 import(Control.Monad, {%{EH}Base.Binary}, {%{EH}Base.Serialize})
%%]

%%[9090 export(varmpMapTy)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.VarMpQ.Base
newtype VarMp' k v = VarMp (AssocL k v) deriving Show
%%]

%%[6 -2.VarMpQ.Base
data VarMp' k v
  = VarMp
      { varmpMetaLev 	:: !MetaLev				-- the base meta level
      , varmpMpL 		:: [Map.Map k v]		-- for each level a map, starting at the base meta level
      }
  deriving ( Eq, Ord
%%[[50
           , Typeable, Data
%%]]
           )
%%]

%%[99 export(varmpToMap)
-- get the base meta level map, ignore the others
varmpToMap :: VarMp' k v -> Map.Map k v
varmpToMap (VarMp _ (m:_)) = m
%%]

%%[6 export(mkVarMp)
mkVarMp :: Map.Map k v -> VarMp' k v
mkVarMp m = VarMp 0 [m]
%%]

%%[2.VarMp.emptyVarMp export(emptyVarMp)
emptyVarMp :: VarMp' k v
emptyVarMp = VarMp []
%%]

%%[6.VarMp.emptyVarMp -2.VarMp.emptyVarMp export(emptyVarMp,varmpIsEmpty)
emptyVarMp :: VarMp' k v
emptyVarMp = mkVarMp Map.empty

varmpIsEmpty :: VarMp' k v -> Bool
varmpIsEmpty (VarMp {varmpMpL=l}) = all Map.null l

instance VarLookupBase (VarMp' k v) k v where
  varlookupEmpty = emptyVarMp
%%]

%%[4.varmpFilter export(varmpFilter)
varmpFilter :: (k -> v -> Bool) -> VarMp' k v -> VarMp' k v
varmpFilter f (VarMp l) = VarMp (filter (uncurry f) l)

varmpPartition :: (k -> v -> Bool) -> VarMp' k v -> (VarMp' k v,VarMp' k v)
varmpPartition f (VarMp l)
  = (VarMp p1, VarMp p2)
  where (p1,p2) = partition (uncurry f) l
%%]

%%[6.varmpFilter -4.varmpFilter
varmpFilter :: Ord k => (k -> v -> Bool) -> VarMp' k v -> VarMp' k v
varmpFilter f (VarMp l c) = VarMp l (map (Map.filterWithKey f) c)

varmpPartition :: Ord k => (k -> v -> Bool) -> VarMp' k v -> (VarMp' k v,VarMp' k v)
varmpPartition f (VarMp l m)
  = (VarMp l p1, VarMp l p2)
  where (p1,p2) = unzip $ map (Map.partitionWithKey f) m
%%]

%%[4.varmpDel
varmpDel :: Ord k => [k] -> VarMp' k v -> VarMp' k v
varmpDel tvL c = varmpFilter (const.not.(`elem` tvL)) c

(|\>) :: Ord k => VarMp' k v -> [k] -> VarMp' k v
(|\>) = flip varmpDel
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: meta level changes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[6 export(varmpShiftMetaLev,varmpIncMetaLev,varmpDecMetaLev)
-- shift up the level,
-- or down when negative, throwing away the lower levels
varmpShiftMetaLev :: MetaLev -> VarMp' k v -> VarMp' k v
varmpShiftMetaLev inc (VarMp mlev fm)
  | inc < 0   = let mlev' = mlev+inc in VarMp (mlev' `max` 0) (drop (- (mlev' `min` 0)) fm)
  | otherwise = VarMp (mlev+inc) fm

varmpIncMetaLev :: VarMp' k v -> VarMp' k v
varmpIncMetaLev = varmpShiftMetaLev 1

varmpDecMetaLev :: VarMp' k v -> VarMp' k v
varmpDecMetaLev = varmpShiftMetaLev (-1)
%%]

%%[6 export(varmpSelectMetaLev)
varmpSelectMetaLev :: [MetaLev] -> VarMp' k v -> VarMp' k v
varmpSelectMetaLev mlevs (VarMp mlev ms)
  = (VarMp mlev [ if l `elem` mlevs then m else Map.empty | (l,m) <- zip [mlev..] ms ])
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: destruction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(varmpAsMap)
-- | Extract first level map, together with a construction function putting a new map into the place of the previous one
varmpAsMap :: VarMp' k v -> (Map.Map k v, Map.Map k v -> VarMp' k v)
varmpAsMap (VarMp mlev (m:ms)) = (m, \m' -> VarMp mlev (m':ms))
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: properties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(varmpSize)
varmpSize :: VarMp' k v -> Int
varmpSize (VarMp _ m) = sum $ map Map.size m
%%]

%%[4.varmpKeys export(varmpKeys,varmpKeysSet)
varmpKeys :: VarMp' k v -> [k]
varmpKeys (VarMp l) = assocLKeys l

varmpKeysSet :: Ord k => VarMp' k v -> Set.Set k
varmpKeysSet = Set.fromList . varmpKeys
%%]

%%[6.varmpKeys -4.varmpKeys export(varmpKeys,varmpKeysSet)
varmpKeys :: Ord k => VarMp' k v -> [k]
varmpKeys (VarMp _ fm) = Map.keys $ Map.unions fm

varmpKeysSet :: Ord k => VarMp' k v -> Set.Set k
varmpKeysSet (VarMp _ fm) = Set.unions $ map Map.keysSet fm
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.VarMp.varmpSingleton export(varmpSingleton)
varmpSingleton :: k -> v -> VarMp' k v
varmpSingleton tv t = VarMp [(tv,t)]
%%]

%%[6.VarMp.varmpSingleton -2.VarMp.varmpSingleton export(varmpMetaLevSingleton,varmpSingleton)
varmpMetaLevSingleton :: MetaLev -> k -> v -> VarMp' k v
varmpMetaLevSingleton mlev k v = VarMp mlev [Map.singleton k v]

varmpSingleton :: k -> v -> VarMp' k v
varmpSingleton = varmpMetaLevSingleton metaLevVal
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: from/to AssocL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[4.assocTyLToVarMp export(assocTyLToVarMp,varmpToAssocTyL,varmpToAssocL)
assocTyLToVarMp, assocLToVarMp :: AssocL k v -> VarMp' k v
assocLToVarMp   = VarMp
assocTyLToVarMp = VarMp

varmpToAssocTyL :: VarMp' k v -> AssocL k v
varmpToAssocTyL (VarMp l) = l

varmpToAssocL :: VarMp' k v -> AssocL k v
varmpToAssocL = varmpToAssocTyL
%%]

%%[6.assocTyLToVarMp -4.assocTyLToVarMp export(assocMetaLevLToVarMp,assocLToVarMp,assocMetaLevTyLToVarMp,assocTyLToVarMp,varmpToAssocTyL,varmpToAssocL)
assocMetaLevLToVarMp :: Ord k => AssocL k (MetaLev,v) -> VarMp' k v
assocMetaLevLToVarMp l = varmpUnions [ varmpMetaLevSingleton lev k v | (k,(lev,v)) <- l ]

assocLToVarMp :: Ord k => AssocL k v -> VarMp' k v
assocLToVarMp = mkVarMp . Map.fromList

assocMetaLevTyLToVarMp :: Ord k => AssocL k (MetaLev,Ty) -> VarMp' k VarMpInfo
assocMetaLevTyLToVarMp = assocMetaLevLToVarMp . assocLMapElt (\(ml,t) -> (ml, VMITy t)) -- varmpUnions [ varmpMetaLevTyUnit lev v t | (v,(lev,t)) <- l ]

assocTyLToVarMp :: Ord k => AssocL k Ty -> VarMp' k VarMpInfo
assocTyLToVarMp = assocLToVarMp . assocLMapElt VMITy

varmpToAssocL :: VarMp' k i -> AssocL k i
varmpToAssocL (VarMp _ []   ) = []
varmpToAssocL (VarMp _ (l:_)) = Map.toList l

varmpToAssocTyL :: VarMp' k VarMpInfo -> AssocL k Ty
varmpToAssocTyL c = [ (v,t) | (v,VMITy t) <- varmpToAssocL c ]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: combine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.varmpPlus export(varmpPlus, (|+>))
infixr 7 `varmpPlus`, |+>

varmpPlus, (|+>) :: Ord k => VarMp' k v -> VarMp' k v -> VarMp' k v
varmpPlus (VarMp l1) (VarMp l2) = VarMp (l1 ++ l2)
(|+>) = varmpPlus
%%]

%%[6.varmpPlus -2.varmpPlus export(varmpPlus)
infixr 7 `varmpPlus`

varmpPlus :: Ord k => VarMp' k v -> VarMp' k v -> VarMp' k v
varmpPlus = (|+>) -- (VarMp l1) (VarMp l2) = VarMp (l1 `Map.union` l2)
%%]

%%[4 export(varmpUnion,varmpUnions)
varmpUnion :: Ord k => VarMp' k v -> VarMp' k v -> VarMp' k v
varmpUnion = varmpPlus

varmpUnions :: Ord k => [VarMp' k v] -> VarMp' k v
varmpUnions [ ] = emptyVarMp
varmpUnions [x] = x
varmpUnions l   = foldr1 varmpPlus l
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Fold: map
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(varmpMapMaybe,varmpMap)
varmpMapMaybe :: Ord k => (a -> Maybe b) -> VarMp' k a -> VarMp' k b
varmpMapMaybe f m = m {varmpMpL = map (Map.mapMaybe f) $ varmpMpL m}

varmpMap :: Ord k => (a -> b) -> VarMp' k a -> VarMp' k b
varmpMap f m = m {varmpMpL = map (Map.map f) $ varmpMpL m}
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Lookup as VarLookup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[6 export(varmpUnionWith)
-- | combine by taking the lowest level, adapting the lists with maps accordingly
varmpUnionWith :: Ord k => (v -> v -> v) -> VarMp' k v -> VarMp' k v -> VarMp' k v
varmpUnionWith f (VarMp l1 ms1) (VarMp l2 ms2)
  = case compare l1 l2 of
      EQ -> VarMp l1 (cmb                                   ms1                                    ms2 )
      LT -> VarMp l1 (cmb                                   ms1  (replicate (l2 - l1) Map.empty ++ ms2))
      GT -> VarMp l2 (cmb (replicate (l1 - l2) Map.empty ++ ms1)                                   ms2 )
  where cmb (m1:ms1) (m2:ms2) = Map.unionWith f m1 m2 : cmb ms1 ms2
        cmb ms1      []       = ms1
        cmb []       ms2      = ms2
%%]

%%[8 export(varmpInsertWith)
varmpInsertWith :: Ord k => (v -> v -> v) -> k -> v -> VarMp' k v -> VarMp' k v
varmpInsertWith f k v = varmpUnionWith f (varmpSingleton k v)
%%]

%%[6
instance Ord k => VarLookup (VarMp' k v) k v where
  varlookupWithMetaLev l k    (VarMp vmlev ms) = lkup (l-vmlev) ms
                                               where lkup _ []     = Nothing
                                                     lkup 0 (m:_)  = Map.lookup k m
                                                     lkup l (_:ms) = lkup (l-1) ms
  varlookup              k vm@(VarMp vmlev _ ) = varlookupWithMetaLev vmlev k vm
  

instance Ord k => VarLookupCmb (VarMp' k v) (VarMp' k v) where
  m1 |+> m2 = varmpUnionWith const m1 m2
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Construction specific for InstTo
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[6 export(instToL1VarMp)
instToL1VarMp :: [InstTo] -> VarMp
instToL1VarMp = varmpIncMetaLev . assocMetaLevTyLToVarMp . instToL1AssocL
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMpInfo, info varieties in VarMp
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[6
data VarMpInfo
  = VMITy      !Ty
%%[[9
  | VMIImpls   !Impls
  | VMIScope   !PredScope
  | VMIPred    !Pred
  | VMIAssNm   !VarUIDHsName
%%]]
%%[[10
  | VMILabel   !Label
  | VMIOffset  !LabelOffset
--  | VMIExts    !RowExts
%%]]
%%[[13
  | VMIPredSeq !PredSeq
%%]]
  deriving
    ( Eq, Ord, Show
%%[[50
    , Typeable, Data
%%]]
    )
%%]

%%[2.vmiMbTy export(vmiMbTy)
%%[[2
vmiMbTy      t = Just t
%%][6
vmiMbTy      i = case i of {VMITy      x -> Just x}
%%][9
vmiMbTy      i = case i of {VMITy      x -> Just x; _ -> Nothing}
%%]]
%%]

%%[9 export(vmiMbImpls,vmiMbScope,vmiMbPred,vmiMbAssNm)
vmiMbImpls   i = case i of {VMIImpls   x -> Just x; _ -> Nothing}
vmiMbScope   i = case i of {VMIScope   x -> Just x; _ -> Nothing}
vmiMbPred    i = case i of {VMIPred    x -> Just x; _ -> Nothing}
vmiMbAssNm   i = case i of {VMIAssNm   x -> Just x; _ -> Nothing}
%%]
%%[10 export(vmiMbLabel,vmiMbOffset)
vmiMbLabel   i = case i of {VMILabel   x -> Just x; _ -> Nothing}
vmiMbOffset  i = case i of {VMIOffset  x -> Just x; _ -> Nothing}
%%]
%%[13 export(vmiMbPredSeq)
vmiMbPredSeq i = case i of {VMIPredSeq x -> Just x; _ -> Nothing}
%%] 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.VarMp.Base
type VarMp  = VarMp' TyVarId Ty
%%]

20080610, AD, todo: use TvPurpose

%%[6 -2.VarMp.Base
type VarMp  = VarMp' TyVarId VarMpInfo

instance Show (VarMp' k v) where
  show _ = "VarMp"
%%]

%%[4.varmpFilterTy
varmpFilterTy :: (k -> v -> Bool) -> VarMp' k v -> VarMp' k v
varmpFilterTy = varmpFilter
%%]

%%[6.varmpFilterTy -4.varmpFilterTy
varmpFilterTy :: Ord k => (k -> Ty -> Bool) -> VarMp' k VarMpInfo -> VarMp' k VarMpInfo
varmpFilterTy f
  = varmpFilter
%%[[6
        (\v i -> case i of {VMITy t -> f v t})
%%][9
        (\v i -> case i of {VMITy t -> f v t ; _ -> True})
%%]]
%%]

%%[9 hs export(varmpTailAddOcc)
varmpTailAddOcc :: ImplsProveOcc -> Impls -> (Impls,VarMp)
varmpTailAddOcc o (Impls_Tail i os) = (t, varmpImplsUnit i t)
                                    where t = Impls_Tail i (o:os)
varmpTailAddOcc _ x                 = (x,emptyVarMp)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Fold: map + thread, for ty related
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9 export(varmpMapThr,varmpMapThrTy)
varmpMapThr :: (MetaLev -> TyVarId -> VarMpInfo -> thr -> (VarMpInfo,thr)) -> thr -> VarMp -> (VarMp,thr)
varmpMapThr f thr (VarMp l ms)
  = (VarMp l ms',thr')
  where (ms',thr') = foldMlev thr ms
        foldMp mlev thr fm
          = Map.foldrWithKey
              (\v i (fm,thr)
                 -> let  (i',thr') = f mlev v i thr
                    in   (Map.insert v i' fm,thr')
              )
              (Map.empty,thr) fm
        foldMlev thr ms
          = foldr
              (\(mlev,m) (ms,thr)
                -> let (m',thr') = foldMp mlev thr m
                   in  (m':ms,thr')
              )
              ([],thr) (zip [0..] ms)

varmpMapThrTy :: (MetaLev -> TyVarId -> Ty -> thr -> (Ty,thr)) -> thr -> VarMp -> (VarMp,thr)
varmpMapThrTy f
  = varmpMapThr
      (\mlev v i thr
         -> case i of 
              VMITy t -> (VMITy t,thr')
                      where (t',thr') = f mlev v t thr
              _       -> (i,thr)
      )
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Visit as graph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[9999 export(varmpGraphVisit)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Make var counterpart of VarMpInfo, for derivation tree pretty printing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[99.varmpinfoMkVar export(varmpinfoMkVar)
varmpinfoMkVar :: TyVarId -> VarMpInfo -> Ty
varmpinfoMkVar v i
  = case i of
      VMITy       t -> mkTyVar v
      VMIImpls    i -> mkImplsVar v
      _             -> mkTyVar v					-- rest incomplete
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.VarMp.varmpTyUnit export(varmpTyUnit)
varmpTyUnit :: k -> v -> VarMp' k v
varmpTyUnit = varmpSingleton
%%]

%%[6.VarMp.varmpTyUnit -2.VarMp.varmpTyUnit export(varmpMetaLevTyUnit,varmpTyUnit)
varmpMetaLevTyUnit :: Ord k => MetaLev -> k -> Ty -> VarMp' k VarMpInfo
varmpMetaLevTyUnit mlev v t = varmpMetaLevSingleton mlev v (VMITy t)

varmpTyUnit :: Ord k => k -> Ty -> VarMp' k VarMpInfo
varmpTyUnit = varmpMetaLevTyUnit metaLevVal
%%]

%%[4_2.varmpTyRevUnit
varmpTyRevUnit :: TyVarId -> Ty -> (Ty,VarMp)
varmpTyRevUnit tv t = maybe (t,varmpTyUnit tv t) (\v -> let t' = mkTyVar tv in (t',varmpTyUnit v t')) . tyMbVar $ t
%%]

%%[9 export(varmpImplsUnit,assocImplsLToVarMp,varmpScopeUnit,varmpPredUnit,varmpAssNmUnit)
varmpImplsUnit :: ImplsVarId -> Impls -> VarMp
varmpImplsUnit v i = mkVarMp (Map.fromList [(v,VMIImpls i)])

varmpScopeUnit :: TyVarId -> PredScope -> VarMp
varmpScopeUnit v sc = mkVarMp (Map.fromList [(v,VMIScope sc)])

varmpPredUnit :: TyVarId -> Pred -> VarMp
varmpPredUnit v p = mkVarMp (Map.fromList [(v,VMIPred p)])

varmpAssNmUnit :: TyVarId -> VarUIDHsName -> VarMp
varmpAssNmUnit v p = mkVarMp (Map.fromList [(v,VMIAssNm p)])

assocImplsLToVarMp :: AssocL ImplsVarId Impls -> VarMp
assocImplsLToVarMp = mkVarMp . Map.fromList . assocLMapElt VMIImpls
%%]


%%[10 export(varmpLabelUnit,varmpOffsetUnit)
varmpLabelUnit :: LabelVarId -> Label -> VarMp
varmpLabelUnit v l = mkVarMp (Map.fromList [(v,VMILabel l)])

varmpOffsetUnit :: UID -> LabelOffset -> VarMp
varmpOffsetUnit v l = mkVarMp (Map.fromList [(v,VMIOffset l)])

%%]
varmpExtsUnit :: UID -> RowExts -> VarMp
varmpExtsUnit v l = mkVarMp (Map.fromList [(v,VMIExts l)])

%%[13 export(varmpPredSeqUnit)
varmpPredSeqUnit :: TyVarId -> PredSeq -> VarMp
varmpPredSeqUnit v l = mkVarMp (Map.fromList [(v,VMIPredSeq l)])
%%]

%%[6 export(tyRestrictKiVarMp)
-- restrict the kinds of tvars bound to value identifiers to kind *
tyRestrictKiVarMp :: [Ty] -> VarMp
tyRestrictKiVarMp ts = varmpIncMetaLev $ assocTyLToVarMp [ (v,kiStar) | t <- ts, v <- maybeToList $ tyMbVar t ]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp: reification as VarMp
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2 export(tyAsVarMp',tyAsVarMp)
-- | Encode 'ty' as a tvar + VarMp, with additional initial construction
tyAsVarMp' :: (UID -> Ty -> Ty) -> UID -> Ty -> (Ty,VarMp)
tyAsVarMp' f u t
  = case f v1 t of
      t | tyIsVar t -> (t, emptyVarMp)
        | otherwise -> (mkTyVar v2, varmpTyUnit v2 t)
  where [v1,v2] = mkNewLevUIDL 2 u

-- | Encode 'ty' as a tvar + VarMp
tyAsVarMp :: UID -> Ty -> (Ty,VarMp)
tyAsVarMp = tyAsVarMp' (flip const)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp lookup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.varmpTyLookup export(varmpTyLookup)
varmpTyLookup, varmpLookup :: Eq k => k -> VarMp' k v -> Maybe v
varmpTyLookup tv (VarMp s) = lookup tv s

varmpLookup = varmpTyLookup
%%]

%%[6 -2.varmpTyLookup export(varmpLookup,varmpTyLookup)
varmpLookup :: (VarLookup m k i,Ord k) => k -> m -> Maybe i
varmpLookup = varlookupMap (Just . id)

varmpTyLookup :: (VarLookup m k VarMpInfo,Ord k) => k -> m -> Maybe Ty
varmpTyLookup = varlookupMap vmiMbTy
%%]

%%[9 export(varmpImplsLookup,varmpScopeLookup,varmpPredLookup)
varmpImplsLookup :: VarLookup m ImplsVarId VarMpInfo => ImplsVarId -> m -> Maybe Impls
varmpImplsLookup = varlookupMap vmiMbImpls

varmpScopeLookup :: VarLookup m TyVarId VarMpInfo => TyVarId -> m -> Maybe PredScope
varmpScopeLookup = varlookupMap vmiMbScope

varmpPredLookup :: VarLookup m TyVarId VarMpInfo => TyVarId -> m -> Maybe Pred
varmpPredLookup = varlookupMap vmiMbPred

varmpAssNmLookup :: VarLookup m TyVarId VarMpInfo => TyVarId -> m -> Maybe VarUIDHsName
varmpAssNmLookup = varlookupMap vmiMbAssNm
%%]

%%[10 export(varmpLabelLookup,varmpOffsetLookup)
varmpLabelLookup :: VarLookup m LabelVarId VarMpInfo => LabelVarId -> m -> Maybe Label
varmpLabelLookup = varlookupMap vmiMbLabel

varmpOffsetLookup :: VarLookup m UID VarMpInfo => UID -> m -> Maybe LabelOffset
varmpOffsetLookup = varlookupMap vmiMbOffset
%%]

%%[13 export(varmpPredSeqLookup)
varmpPredSeqLookup :: VarLookup m TyVarId VarMpInfo => TyVarId -> m -> Maybe PredSeq
varmpPredSeqLookup = varlookupMap vmiMbPredSeq
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp lookup: Cycle check variants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[4.varmpTyLookupCyc export(varmpTyLookupCyc)
%%[[4
varmpTyLookupCyc :: TyVarId -> VarMp -> Maybe Ty
%%][8
varmpTyLookupCyc :: VarLookup m TyVarId VarMpInfo => TyVarId -> m -> Maybe Ty
%%]]
varmpTyLookupCyc x m = lookupLiftCycMb2 tyMbVar (flip varmpTyLookup m) x
%%]

%%[9 export(varmpImplsLookupImplsCyc,varmpImplsLookupCyc,varmpScopeLookupScopeCyc,varmpAssNmLookupAssNmCyc)
varmpImplsLookupImplsCyc :: VarLookup m ImplsVarId VarMpInfo => Impls -> m -> Maybe Impls
varmpImplsLookupImplsCyc x m = lookupLiftCycMb1 implsMbVar (flip varmpImplsLookup m) x

varmpImplsLookupCyc :: VarLookup m ImplsVarId VarMpInfo => TyVarId -> m -> Maybe Impls
varmpImplsLookupCyc x m = lookupLiftCycMb2 implsMbVar (flip varmpImplsLookup m) x

varmpScopeLookupScopeCyc :: VarLookup m ImplsVarId VarMpInfo => PredScope -> m -> Maybe PredScope
varmpScopeLookupScopeCyc x m = lookupLiftCycMb1 pscpMbVar (flip varmpScopeLookup m) x

varmpAssNmLookupAssNmCyc :: VarLookup m ImplsVarId VarMpInfo => VarUIDHsName -> m -> Maybe VarUIDHsName
varmpAssNmLookupAssNmCyc x m = lookupLiftCycMb1 vunmMbVar (flip varmpAssNmLookup m) x
%%]

%%[10 export(varmpLabelLookupCyc,varmpLabelLookupLabelCyc)
varmpLabelLookupLabelCyc :: VarLookup m ImplsVarId VarMpInfo => Label -> m -> Maybe Label
varmpLabelLookupLabelCyc x m = lookupLiftCycMb1 labelMbVar (flip varmpLabelLookup m) x

varmpLabelLookupCyc :: VarLookup m ImplsVarId VarMpInfo => TyVarId -> m -> Maybe Label
varmpLabelLookupCyc x m = lookupLiftCycMb2 labelMbVar (flip varmpLabelLookup m) x
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp lookup: Flipped variants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[4 export(varmpTyLookupCyc2)
varmpTyLookupCyc2 :: VarMp -> TyVarId -> Maybe Ty
varmpTyLookupCyc2 x m = varmpTyLookupCyc m x
%%]

%%[9 export(varmpPredLookup2,varmpScopeLookup2,varmpAssNmLookup2,varmpImplsLookupCyc2)
varmpScopeLookup2 :: VarMp -> TyVarId -> Maybe PredScope
varmpScopeLookup2 m v = varmpScopeLookup v m

varmpImplsLookup2 :: VarMp -> ImplsVarId -> Maybe Impls
varmpImplsLookup2 m v = varmpImplsLookup v m

varmpImplsLookupCyc2 :: VarMp -> ImplsVarId -> Maybe Impls
varmpImplsLookupCyc2 m v = varmpImplsLookupCyc v m

varmpPredLookup2 :: VarMp -> TyVarId -> Maybe Pred
varmpPredLookup2 m v = varmpPredLookup v m

varmpAssNmLookup2 :: VarMp -> TyVarId -> Maybe VarUIDHsName
varmpAssNmLookup2 m v = varmpAssNmLookup v m
%%]

%%[10
varmpLabelLookup2 :: VarMp -> LabelVarId -> Maybe Label
varmpLabelLookup2 m v = varmpLabelLookup v m
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% VarMp stack, for nested/local behavior
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(VarMpStk')
newtype VarMpStk' k v
  = VarMpStk [VarMp' k v]
  deriving (Show)
%%]

%%[8 export(emptyVarMpStk, varmpstkUnit)
emptyVarMpStk :: VarMpStk' k v
emptyVarMpStk = VarMpStk [emptyVarMp]

varmpstkUnit :: Ord k => k -> v -> VarMpStk' k v
varmpstkUnit k v = VarMpStk [mkVarMp (Map.fromList [(k,v)])]
%%]

%%[8 export(varmpstkPushEmpty, varmpstkPop)
varmpstkPushEmpty :: VarMpStk' k v -> VarMpStk' k v
varmpstkPushEmpty (VarMpStk s) = VarMpStk (emptyVarMp : s)

varmpstkPop :: VarMpStk' k v -> (VarMpStk' k v, VarMpStk' k v)
varmpstkPop (VarMpStk (s:ss)) = (VarMpStk [s], VarMpStk ss)
varmpstkPop _                 = panic "varmpstkPop: empty"
%%]

%%[8 export(varmpstkToAssocL, varmpstkKeysSet)
varmpstkToAssocL :: VarMpStk' k v -> AssocL k v
varmpstkToAssocL (VarMpStk s) = concatMap varmpToAssocL s

varmpstkKeysSet :: Ord k => VarMpStk' k v -> Set.Set k
varmpstkKeysSet (VarMpStk s) = Set.unions $ map varmpKeysSet s
%%]

%%[8 export(varmpstkUnions)
varmpstkUnions :: Ord k => [VarMpStk' k v] -> VarMpStk' k v
varmpstkUnions [x] = x
varmpstkUnions l   = foldr (|+>) emptyVarMpStk l
%%]

%%[8
instance Ord k => VarLookup (VarMpStk' k v) k v where
  varlookupWithMetaLev l k (VarMpStk s) = varlookupWithMetaLev l k s

instance Ord k => VarLookupCmb (VarMpStk' k v) (VarMpStk' k v) where
  (VarMpStk s1) |+> (VarMpStk s2) = VarMpStk (s1 |+> s2)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Pretty printing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[2.ppVarMp
ppVarMp :: (PP k, PP v) => ([PP_Doc] -> PP_Doc) -> VarMp' k v -> PP_Doc
ppVarMp ppL (VarMp l) = ppL . map (\(n,v) -> pp n >|< ":->" >|< pp v) $ l
%%]

%%[2
ppVarMpV :: VarMp -> PP_Doc
ppVarMpV = ppVarMp vlist
%%]

%%[6.ppVarMp -2.ppVarMp export(ppVarMp)
ppVarMp :: (PP k, PP v) => ([PP_Doc] -> PP_Doc) -> VarMp' k v -> PP_Doc
ppVarMp ppL (VarMp mlev ms)
  = ppL [ "@" >|< pp lev >|< ":" >#< ppL [ pp n >|< ":->" >|< pp v | (n,v) <- Map.toList m]
        | (lev,m) <- zip [mlev..] ms
        ]
%%]

%%[2.PP
instance (PP k, PP v) => PP (VarMp' k v) where
  pp = ppVarMp (ppListSepFill "" "" ", ")
%%]

%%[8
instance (PP k, PP v) => PP (VarMpStk' k v) where
  pp (VarMpStk s) = ppListSepFill "" "" "; " $ map pp s
%%]

%%[99.ppVarMpInfoCfgTy export(ppVarMpInfoCfgTy,ppVarMpInfoDt)
ppVarMpInfoCfgTy :: CfgPPTy -> VarMpInfo -> PP_Doc
ppVarMpInfoCfgTy c i
  = case i of
      VMITy       t -> ppTyWithCfg    c t
      VMIImpls    i -> ppImplsWithCfg c i
      VMIScope    s -> pp s						-- rest incomplete
      VMIPred     p -> pp p
      VMILabel    x -> pp x
      VMIOffset   x -> pp x
      VMIPredSeq  x -> pp "predseq" -- pp x

ppVarMpInfoDt :: VarMpInfo -> PP_Doc
ppVarMpInfoDt = ppVarMpInfoCfgTy cfgPPTyDT
%%]

%%[6
instance PP VarMpInfo where
  pp (VMITy       t) = pp t
%%[[9
  pp (VMIImpls    i) = pp i
  pp (VMIScope    s) = pp s
  pp (VMIPred     p) = pp p
%%]]
%%[[10
  pp (VMILabel    x) = pp x
  pp (VMIOffset   x) = pp x
  -- pp (VMIExts     x) = pp "exts" -- pp x
%%]]
%%[[13
  pp (VMIPredSeq  x) = pp "predseq" -- pp x
%%]]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Instances: Binary, Serialize
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[50
instance Serialize VarMpInfo where
  sput (VMITy      a) = sputWord8 0  >> sput a
  sput (VMIImpls   a) = sputWord8 1  >> sput a
  sput (VMIScope   a) = sputWord8 2  >> sput a
  sput (VMIPred    a) = sputWord8 3  >> sput a
  sput (VMIAssNm   a) = sputWord8 4  >> sput a
  sput (VMILabel   a) = sputWord8 5  >> sput a
  sput (VMIOffset  a) = sputWord8 6  >> sput a
  sput (VMIPredSeq a) = sputWord8 7  >> sput a
  sget = do t <- sgetWord8
            case t of
              0 -> liftM VMITy      sget
              1 -> liftM VMIImpls   sget
              2 -> liftM VMIScope   sget
              3 -> liftM VMIPred    sget
              4 -> liftM VMIAssNm   sget
              5 -> liftM VMILabel   sget
              6 -> liftM VMIOffset  sget
              7 -> liftM VMIPredSeq sget

instance (Ord k, Serialize k, Serialize v) => Serialize (VarMp' k v) where
  sput (VarMp a b) = sput a >> sput b
  sget = liftM2 VarMp sget sget

%%]
