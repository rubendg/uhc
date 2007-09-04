# location of test src
TEST_SRC_PREFIX						:= $(TOP_PREFIX)test/
TEST_REGRESS_SRC_PREFIX				:= $(TEST_SRC_PREFIX)regress/
TEST_BIN_PREFIX						:= ../../bin/

# limits
TEST_LIMIT_TIME						:= 5

# grin suffix as generated by ehc
TEST_GRIN_SUFFIX					:= grin2

# this file
TEST_MKF							:= $(TEST_SRC_PREFIX)files.mk

# main + sources + dpds, for .chs
TEST_REGRESS_ALL_SRC				:= $(wildcard $(TEST_REGRESS_SRC_PREFIX)*.eh)
TEST_REGRESS_EXP_DRV				:= $(wildcard $(TEST_REGRESS_SRC_PREFIX)*.eh.exp*)

# distribution
TEST_DIST_FILES						:= $(TEST_REGRESS_ALL_SRC) $(TEST_REGRESS_EXP_DRV) $(TEST_MKF)

# rules
test-lists:
	@cd $(TEST_REGRESS_SRC_PREFIX) ; \
	shopt -s nullglob ; \
	for v in $(EHC_VARIANTS) ; \
	do \
	  ehs= ; \
	  vv=`echo $$v | sed -e 's/_[0-9]//'` ; \
	  for ((i = 1 ; i <= $${vv} ; i++)) ; do ehs="$$ehs `echo $${i}/*.{eh,hs}`" ; done ; \
	  echo "$$ehs" > $$v.lst ; \
	done

# run tests for generation of expected results or check agains those results
# NOTE: previously parameterizable mini preludes with non-portable 'sed -E': tprelbase=`sed -n -E 's/^-- %% *inline test *\(([a-z0-9]+)\) --$$/\1/p' < $$t`
#       now fixed: 'prefix1' labeled files
test-expect test-regress: test-lists
	@how=`echo $@ | sed -e 's/.*expect.*/exp/' -e 's/.*regress.*/reg/'` ; \
	cd $(TEST_REGRESS_SRC_PREFIX) ; \
	for v in $(TEST_VARIANTS) ; \
	do \
	  echo "== version $$v ==" ; \
	  ehc=$(TEST_BIN_PREFIX)$$v/$(EHC_EXEC_NAME)$(EXEC_SUFFIX) ; \
	  gri=$(TEST_BIN_PREFIX)$$v/$(GRINI_EXEC_NAME)$(EXEC_SUFFIX) ; \
	  if test -x $$ehc ; \
	  then \
	    if test "x$${TEST_FILES}" = "x" ; \
	    then \
	      TEST_FILES=`cat $$v.lst` ; \
	    fi ; \
	    for t in $${TEST_FILES} ; \
	    do \
	      cleanup="rm -f" ; \
	      tdir=`dirname $$t` ; \
	      tb="$${tdir}/"`basename $$t .eh` ; \
	      tsuff=".eh" ; \
	      if test $${tb} = $${t} ; \
	      then \
	        tb="$${tdir}/"`basename $$t .hs` ; \
	        tsuff=".hs" ; \
	      fi ; \
	      if test -r $$t -a -x $$ehc ; \
	      then \
	        tprelbase=`sed -n -e 's/^-- %% *inline test *([a-z0-9]*) --$$/prefix1/p' < $$t` ; \
	        tprel="$${v}-$${tprelbase}$${tsuff}" ; \
	        if test -r $${tprel} ; \
	        then \
	          tb2="$${tb}+p" ; \
	          t2="$${tb2}$${tsuff}" ; \
	          cat $${tprel} $${t} > $${t2} ; \
	          cleanup="$${cleanup} $${t2}" ; \
	        else \
	          tb2="$${tb}" ; \
	          t2="$${t}" ; \
	        fi ; \
	        te=$${t}.exp$${v} ; tr=$${t}.reg$${v} ; th=$${t}.$${how}$${v} ; tc=$${tb2}.core ; tg=$${tb2}.$(TEST_GRIN_SUFFIX) ; texe=$${tb2}$(EXEC_SUFFIX) ; \
	        cleanup="$${cleanup} $${texe}" ; \
	        rm -f $${tc} $${tg} ; \
	        $$ehc $${t2} $${TEST_OPTIONS} > $${th} 2>&1 ; \
	        if test -r $${tc} ; \
	        then \
	          echo "== core ==" >> $${th} ; \
	          cat $${tc} >> $${th} ; \
	          if test -x $$gri -a "x$(CORE_TARG_SUFFIX)" = "x$(TEST_GRIN_SUFFIX)" ; \
	          then \
	            rm -f $${tg} ; \
	            $$ehc $${TEST_OPTIONS} --code=grin $${t2} > /dev/null ; \
	            echo "== grin execution ==" >> $${th} ; \
	            $$gri $${tg} >> $${th} 2>&1 ; \
	            rm -f $${texe} ; \
	            echo "== grin bytecode (GBM) compilation ==" >> $${th} ; \
	            $$ehc $${TEST_OPTIONS} --pretty=- --code=bexe $${t2} >> $${th} 2>&1 ; \
	            if test $$? = 0 -a -x $${texe} ; \
	            then \
	              echo "== grin bytecode (GBM) execution ==" >> $${th} ; \
	              (ulimit $(TEST_LIMIT_TIME) && $${texe} >> $${th} 2>&1) ; \
	            fi ; \
	            rm -f $${texe} ; \
	            echo "== grin full program analysis compilation ==" >> $${th} ; \
	            $$ehc $${TEST_OPTIONS} --pretty=- --code=exe $${t2} >> $${th} 2>&1 ; \
	            if test $$? = 0 -a -x $${texe} ; \
	            then \
	              echo "== grin full program analysis execution ==" >> $${th} ; \
	              (ulimit $(TEST_LIMIT_TIME) && $${texe} >> $${th} 2>&1) ; \
	            fi \
	          fi \
	        fi ; \
	        if test $${tr} = $${th} -a -r $${te} ; \
	        then \
	          echo "-- $${te} -- $${th} --" | $(INDENT2) ; \
	          if cmp $${te} $${th} > /dev/null ; \
	          then \
	            echo -n ; \
	          else \
	            diff $${te} $${th} | $(INDENT4) ; \
	          fi \
	        elif test ! -r $${te} ; \
	        then \
	          echo "-- no $${te} to compare to" | $(INDENT2) ; \
	        fi \
	      fi ; \
	      $${cleanup} ; \
	    done ; \
	    TEST_FILES="" ; \
	  else \
	    echo "-- no $$ehc to compile with" | $(INDENT2) ; \
	  fi \
	done
