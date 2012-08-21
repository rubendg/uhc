%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EHC Compile output generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Output generation, on stdout or file

%%[8 module {%{EH}EHC.CompilePhase.Output}
%%]

-- general imports
%%[8 import(qualified EH.Util.FastSeq as Seq)
%%]
%%[8 import(qualified Data.Map as Map, qualified Data.Set as Set)
%%]

%%[8 import({%{EH}EHC.Common})
%%]
%%[8 import({%{EH}EHC.CompileUnit})
%%]
%%[8 import({%{EH}EHC.CompileRun})
%%]

%%[8 import(qualified {%{EH}Config} as Cfg)
%%]

-- EH semantics
%%[99 import(qualified {%{EH}EH.MainAG} as EHSem)
%%]

-- HI syntax and semantics
%%[50 import(qualified {%{EH}HI} as HI)
%%]

-- Core semantics
-- TBD: this depends on grin gen, but should also be available for Core, so in a CoreXXXSem
%%[(8 codegen grin) import(qualified {%{EH}Core.ToGrin} as Core2GrSem)
%%]

-- Core output
%%[(8 codegen) import({%{EH}Core},{%{EH}Core.Pretty})
%%]
-- TyCore output
%%[(8 codegen tycore) import({%{EH}TyCore},{%{EH}TyCore.Pretty})
%%]
-- Grin input and output
%%[(8 codegen grin) import({%{EH}GrinCode.Pretty})
%%]
-- Java output
%%[(8888 codegen java) import({%{EH}Core.ToJava})
%%]
-- Cmm output
%%[(8 codegen cmm) import({%{EH}Cmm.ToC}(cmmMod2C))
%%]

-- serialization
%%[50 import(qualified {%{EH}Base.Binary} as Bin, {%{EH}Base.Serialize})
%%]
-- for debugging only
%%[50 import({%{EH}Gam})
%%]

-- module admin
%%[50 import({%{EH}Module})
%%]

-- gam related utils
%%[99 import({%{EH}Gam.Utils})
%%]


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Compile actions: output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen tycore) export(cpOutputTyCoreModule,cpOutputTyCore)
cpOutputTyCoreModule :: Bool -> String -> String -> HsName -> Module -> EHCompilePhase ()
cpOutputTyCoreModule binary nmsuff suff modNm tyMod
  =  do  {  cr <- get
         ;  let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                 fpC = mkOutputFPath opts modNm fp (suff ++ nmsuff) -- for now nmsuff after suff, but should be inside name
                 fnC    = fpathToStr fpC
%%[[8
         ;  lift $ putPPFPath fpC (ppModule opts tyMod) 100
%%][50
         ;  lift (if binary
                  then do { fpathEnsureExists fpC		-- should be in FPath equivalent of putSerializeFile
                          ; putSerializeFile fnC tyMod
                          }
                  else putPPFPath fpC (ppModule opts tyMod) 100
                 )
%%]]
         }
cpOutputTyCore :: String -> HsName -> EHCompilePhase ()
cpOutputTyCore suff modNm
  =  do  {  cr <- get
         -- part 1: current .tycore
         ;  let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                 mbTyCore = ecuMbTyCore ecu
                 cMod   = panicJust "cpOutputTyCore" mbTyCore
                 fpC = mkOutputFPath opts modNm fp suff
         ;  cpMsg modNm VerboseALot "Emit TyCore"
         ;  lift $ putPPFPath fpC (ppModule opts cMod) 100
         }
%%]

%%[(8 codegen) export(cpOutputCoreModule,cpOutputCore)
cpOutputCoreModule :: Bool -> String -> String -> HsName -> CModule -> EHCompilePhase ()
cpOutputCoreModule binary nmsuff suff modNm cMod
  =  do  {  cr <- get
         ;  let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                 fpC     = mkOutputFPath opts modNm fp (suff ++ nmsuff) -- for now nmsuff after suff, but should be inside name
                 fnC     = fpathToStr fpC
                 coreInh = crsiCoreInh crsi
                 lm      = Core2GrSem.lamMp_Inh_CodeAGItf coreInh
%%[[8
         ;  lift $ putPPFPath fpC (ppCModule opts {- lm -} cMod) 100
%%][50
         ;  lift (if binary
                  then do { fpathEnsureExists fpC		-- should be in FPath equivalent of putSerializeFile
                          ; putSerializeFile fnC cMod
                          }
                  else putPPFPath fpC (ppCModule opts {- lm -} cMod) 100
                 )
%%]]
         }

cpOutputCore :: Bool -> String -> String -> HsName -> EHCompilePhase ()
cpOutputCore binary nmsuff suff modNm
  =  do  {  cr <- get
         -- part 1: current .core
         ;  let  (ecu,_,_,_) = crBaseInfo modNm cr
                 mbCore = ecuMbCore ecu
                 cMod   = panicJust "cpOutputCore" mbCore
         ;  cpMsg modNm VerboseALot "Emit Core"
         ;  cpOutputCoreModule binary nmsuff suff modNm cMod
         }
%%]

%%[(8888 codegen java) export(cpOutputJava)
cpOutputJava :: String -> HsName -> EHCompilePhase ()
cpOutputJava suff modNm
  =  do  {  cr <- get
         ;  let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                 mbCore = ecuMbCore ecu
                 cMod   = panicJust "cpOutputJava" mbCore
                 (jBase,jPP) = cmodJavaSrc cMod
                 -- fpJ = fpathSetBase jBase fp    
                 fpJ    = mkOutputFPath opts (mkHNm jBase) fp suff
         ;  cpMsg modNm VerboseALot "Emit Java"
         ;  lift (putPPFPath fpJ jPP 100)
         }
%%]

%%[(8 codegen grin) export(cpOutputGrin)
cpOutputGrin :: Bool -> String -> HsName -> EHCompilePhase ()
cpOutputGrin binary suff modNm
  =  do  { cr <- get
         ; let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                mbGrin = ecuMbGrin ecu
                grin   = panicJust "cpOutputGrin" mbGrin
                mkb x  = x ++ suff
                fpG    = mkOutputFPath opts (mkHNm $ mkb $ show modNm) (fpathUpdBase mkb fp) "grin"
                fnG    = fpathToStr fpG
         ; cpMsg modNm VerboseALot "Emit Grin"
%%[[8
         ; lift $ putPPFPath fpG (ppGrModule grin) 1000 --TODO ? getal
%%][50
         ; lift (if binary
                 then do { fpathEnsureExists fpG
                         ; putSerializeFile fnG grin
                         }
                 else putPPFPath fpG (ppGrModule grin) 1000 --TODO ? getal
                )
%%]]
         }

%%]

%%[(8 codegen grin) export(cpOutputByteCodeC)
cpOutputByteCodeC :: String -> HsName -> EHCompilePhase ()
cpOutputByteCodeC suff modNm
  =  do  {  cr <- get
         ;  let  (ecu,_,opts,fp) = crBaseInfo modNm cr
                 bc       = panicJust "cpOutputByteCodeC bytecode" $ ecuMbBytecodeSem ecu
                 fpC      = mkOutputFPath opts modNm fp suff
%%[[(8 cmm)
                 cmm      = panicJust "cpOutputByteCodeC cmm" $ ecuMbCmm ecu
                 fpCmm    = mkOutputFPath opts modNm fp (suff ++ "-cmm")
%%]]
         ;  cpMsg' modNm VerboseALot "Emit ByteCode C" Nothing fpC     -- '
%%[[99
         ;  cpRegisterFilesToRm [fpC]
%%]]
         ;  lift $ putPPFPath fpC bc 150
%%[[(8 cmm)
         -- 20111220: temporary, until Cmm is main path
         ;  when (ehcOptPriv opts)
                 (do { let cmmPP = cmmMod2C opts cmm
                     ; lift $ putPPFPath fpCmm cmmPP 150
                     })
%%]]
         }
%%]

%%[50 export(cpOutputHI)
cpOutputHI :: String -> HsName -> EHCompilePhase ()
cpOutputHI suff modNm
  =  do  {  cr <- get
         ;  let  (ecu,crsi,opts,fp) = crBaseInfo modNm cr
                 mmi    = panicJust "cpOutputHI.crsiModMp" $ Map.lookup modNm $ crsiModMp crsi
                 hii1   = ecuHIInfo ecu
                 impNmS = ecuImpNmS ecu
                 hii2   = hii1 { HI.hiiValidity             = HI.HIValidity_Ok
                               , HI.hiiModuleNm             = modNm
                               , HI.hiiExps                 = mmiExps       mmi
                               , HI.hiiHiddenExps           = mmiHiddenExps mmi
                               , HI.hiiHasMain              = ecuHasMain ecu
                               , HI.hiiTarget               = ehcOptTarget opts
                               , HI.hiiTargetFlavor         = ehcOptTargetFlavor opts
                               , HI.hiiSrcTimeStamp         = Cfg.verTimestamp Cfg.version
                               , HI.hiiSrcSig               = Cfg.verSig Cfg.version
                               , HI.hiiSrcVersionMajor      = Cfg.verMajor Cfg.version
                               , HI.hiiSrcVersionMinor      = Cfg.verMinor Cfg.version
                               , HI.hiiSrcVersionMinorMinor = Cfg.verMinorMinor Cfg.version
                               , HI.hiiSrcVersionSvn        = Cfg.verSvnRevision Cfg.version
                               , HI.hiiCompileFlags         = optsDiscrRecompileRepr opts
                               , HI.hiiCompiler             = Cfg.installVariant opts
                               , HI.hiiTransClosedUsedModMp = Map.unions $
                                                                Map.singleton modNm impNmS : [ ecuTransClosedUsedModMp $ crCU m cr | m <- Set.toList impNmS ]
                               , HI.hiiTransClosedOrphanModS= Set.unions $
                                                                [ Set.unions [if ecuIsOrphan me then Set.singleton m else Set.empty, ecuTransClosedOrphanModS me]
                                                                | m <- Set.toList impNmS
                                                                , let me = crCU m cr
                                                                ]
                               }
%%[[50
                 hii3   = hii2
%%][9999
                 ehInh  = crsiEHInh crsi
                 hii3 = HI.hiiIncludeCacheOfImport (ecuAnHIInfo . flip crCU cr) (mentrelFilterMpExtendViaValGam modNm (EHSem.valGam_Inh_AGItf ehInh) (ecuUsedNames ecu)) hii2
                 -- hii3   = hii2
%%]]
                 fpH    = mkOutputFPath opts modNm fp suff
                 fnH    = fpathToStr fpH
         ;  cpMsg modNm VerboseALot "Emit HI"
         ;  hiExists <- lift $ doesFileExist fnH
         ;  when (hiExists)
                 (lift $ removeFile fnH)
         ;  when (ehcOptVerbosity opts > VerboseALot)
                 (do { lift $ putPPLn ("hii3: " >#< hii3)
                     ; lift $ putPPLn ("orph: " >#< vlist [ m >#< (fmap Set.toList $ HI.hiiMbOrphan $ ecuHIInfo me) | m <- Set.toList impNmS, let me = crCU m cr ])
%%[[99
                     ; lift $ putPPLn ("used nms: " >#< (pp $ show $ ecuUsedNames ecu))
%%]]
                     })
         ;  lift $ do { fpathEnsureExists fpH
                      ; putSerializeFile fnH hii3
                      }
         ;  now <- lift $ getClockTime
         ;  cpUpdCU modNm ( ecuStoreHIInfoTime now
%%[[99
                          . ecuStoreHIInfo hii3
%%]]
                          )
         }

%%]


