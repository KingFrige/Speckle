#!/bin/bash

set -e

if [ -z  "$SPEC_DIR" ]; then
   echo "  Please set the SPEC_DIR environment variable to point to your copy of SPEC CPU2006."
   exit 1
fi

ARCH=x86
CMD_FILE=commands.txt
INPUT_TYPE=test
SUITE_TYPE=all

# the integer set
INTBENCHMARKS=(400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer 458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar 483.xalancbmk)
#FPBENCHMARKS=(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3)
FPBENCHMARKS=(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3)

# idiomatic parameter and option handling in sh
compileFlag=false
runFlag=false
copyFlag=false
fpFlag=false
intFlag=false

function clean_build_data()
{
  BENCHMARKS=("${INTBENCHMARKS[@]}" "${FPBENCHMARKS[@]}")
  for b in "${BENCHMARKS[@]}"; do

    BUILD_DIR=$SPEC_DIR/benchspec/CPU2006/$b/build
    RUN_DIR=$SPEC_DIR/benchspec/CPU2006/$b/run

    if test -d "$BUILD_DIR"; then
      rm -rf ${BUILD_DIR}
      echo "rm -rf ${BUILD_DIR}"
    fi
    if test -d "$RUN_DIR"; then
      rm -rf ${RUN_DIR}
      echo "rm -rf ${RUN_DIR}"
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --arch)
      ARCH="$2"
      if ! [[ "$ARCH" =~ ^(x86|riscv)$ ]]; then
        echo "Error: dont support $ARCH"
        echo "support arch: x86, riscv"
        exit 1
      fi
      shift 2
      ;;
    --compile)
      compileFlag=true
      shift
      ;;
    --run)
      runFlag=true
      shift
      ;;
    --copy)
      copyFlag=true
      shift
      ;;
    --fp)
      fpFlag=true
      SUITE_TYPE=fp
      shift
      ;;
    --int)
      intFlag=true
      SUITE_TYPE=int
      shift
      ;;
    --clean)
      clean_build_data
      shift
      ;;
    --*) echo "ERROR: bad option $1"
      echo "  --compile (compile the SPEC benchmarks), --run (to run the benchmarks) --copy (copies, not symlinks, benchmarks to a new dir)"
      exit 1
      ;;
    *) echo "ERROR: bad argument $1"
      echo "  --compile (compile the SPEC benchmarks), --run (to run the benchmarks) --copy (copies, not symlinks, benchmarks to a new dir)"
      exit 2
      ;;
  esac
done

CONFIG=$ARCH
CONFIGFILE=${CONFIG}.cfg

if [[ $ARCH == "riscv" ]]; then
  if [ -z  "$RISCV" ]; then
    echo "  Please set the RSICV environment variable to point to your copy of RISCV toolchain."
    exit 1
  fi

  RUN="$RISCV/bin/spike $RISCV/riscv64-unknown-elf/bin/pk "
else
  RUN=""
fi

if [[ "$SUITE_TYPE" == "fp" ]]; then
  fpFlag=true
fi

if [[ "$SUITE_TYPE" == "int" ]]; then
  intFlag=true
fi

echo "== Speckle Options =="
echo "  arch   : " $ARCH
echo "  Config : " ${CONFIG}
echo "  Input  : " ${INPUT_TYPE}
echo "  compile: " $compileFlag
echo "  run    : " $runFlag
echo "  copy   : " $copyFlag
echo "  fp     : " $fpFlag
echo "  int    : " $intFlag
echo ""

if [[ "$fpFlag" == true ]]; then
  BENCHMARKS=(${FPBENCHMARKS[@]})
elif [[ "$intFlag" == true ]]; then
  BENCHMARKS=(${INTBENCHMARKS[@]})
else
  BENCHMARKS=("${INTBENCHMARKS[@]}" "${FPBENCHMARKS[@]}")
fi

BUILD_DIR=$PWD/build
COPY_DIR=$PWD/${CONFIG}-spec-${SUITE_TYPE}-${INPUT_TYPE}
mkdir -p build;


# compile the binaries
if [ "$compileFlag" = true ]; then
   echo "Compiling SPEC..."
   # copy over the config file we will use to compile the benchmarks
   cp $BUILD_DIR/../${CONFIGFILE} $SPEC_DIR/config/${CONFIGFILE}
   if [ "$fpFlag" = true ]; then
     cd $SPEC_DIR; . ./shrc; time runspec --config ${CONFIG} --size ${INPUT_TYPE} --action setup fp
   elif [ "$intFlag" = true ]; then
     cd $SPEC_DIR; . ./shrc; time runspec --config ${CONFIG} --size ${INPUT_TYPE} --action setup int
   else
     cd $SPEC_DIR; . ./shrc;
     time runspec --config ${CONFIG} --size ${INPUT_TYPE} --action setup fp
     time runspec --config ${CONFIG} --size ${INPUT_TYPE} --action setup int
   fi

   if [ "$copyFlag" = true ]; then
      rm -rf $COPY_DIR
      mkdir -p $COPY_DIR
   fi

   # copy back over the binaries.  Fuck xalancbmk for being different.
   # Do this for each input type.
   # assume the CPU2006 directories are clean. I've hard-coded the directories I'm going to copy out of
   for b in ${BENCHMARKS[@]}; do
      echo ${b}
      SHORT_EXE=${b##*.} # cut off the numbers ###.short_exe
      if [ $b == "483.xalancbmk" ]; then
         SHORT_EXE=Xalan #WTF SPEC???
      fi
      if [ $b == "482.sphinx3" ]; then
         SHORT_EXE=sphinx_livepretend
      fi
      BMK_DIR0=$SPEC_DIR/benchspec/CPU2006/$b/run/run_base_${INPUT_TYPE}_${CONFIG}.0000;
      BMK_DIR1=$SPEC_DIR/benchspec/CPU2006/$b/run/run_base_${CONFIG}.0000;

      if test -d "$BMK_DIR0"; then
        BMK_DIR=${BMK_DIR0}
      elif test -d "$BMK_DIR1"; then
        BMK_DIR=${BMK_DIR1}
      else
        echo "目录不存在: ${BMK_DIR0}"
        echo "目录不存在: ${BMK_DIR1}"
      fi

      echo ""
      echo "ls $SPEC_DIR/benchspec/CPU2006/$b/run"
      ls $SPEC_DIR/benchspec/CPU2006/$b/run
      ls ${BMK_DIR}
      echo ""

      # make a symlink to SPEC (to prevent data duplication for huge input files)
      echo "ln -sf $BMK_DIR $BUILD_DIR/${b}_${INPUT_TYPE}"
      if [ -d $BUILD_DIR/${b}_${INPUT_TYPE} ]; then
         echo "unlink $BUILD_DIR/${b}_${INPUT_TYPE}"
         unlink $BUILD_DIR/${b}_${INPUT_TYPE}
      fi
      ln -sf $BMK_DIR $BUILD_DIR/${b}_${INPUT_TYPE}

      if [ "$copyFlag" = true ]; then
         echo "---- copying benchmarks ----- "
         mkdir -p $COPY_DIR/$b
         cp -r $BUILD_DIR/../commands $COPY_DIR/commands

         if [ "$SUITE_TYPE" = "fp" ]; then
           cp $BUILD_DIR/../run_fp.sh $COPY_DIR/run.sh
         else
           cp $BUILD_DIR/../run_int.sh $COPY_DIR/run.sh
         fi

         sed -i '4s/.*/INPUT_TYPE='${INPUT_TYPE}' #this line was auto-generated from gen_binaries.sh/' $COPY_DIR/run.sh
         for f in $BMK_DIR/*; do
            echo $f
            if [[ -d $f ]]; then
               cp -r $f $COPY_DIR/$b/$(basename "$f")
            else
               cp $f $COPY_DIR/$b/$(basename "$f")
            fi
         done
         mv $COPY_DIR/$b/${SHORT_EXE}_base.${CONFIG} $COPY_DIR/$b/${SHORT_EXE}
      fi
   done
fi

# running the binaries/building the command file
# we could also just run through BUILD_DIR/CMD_FILE and run those...
if [[ "$runFlag" == true ]]; then
   for b in ${BENCHMARKS[@]}; do

      cd $BUILD_DIR/${b}_${INPUT_TYPE}
      SHORT_EXE=${b##*.} # cut off the numbers ###.short_exe
      # handle benchmarks that don't conform to the naming convention
      if [ $b == "482.sphinx3" ]; then SHORT_EXE=sphinx_livepretend; fi
      if [ $b == "483.xalancbmk" ]; then SHORT_EXE=Xalan; fi

      # read the command file
      mapfile -t commands < $BUILD_DIR/../commands/${b}.${INPUT_TYPE}.cmd

      for input in "${commands[@]}"; do
         if [[ ${input:0:1} != '#' ]]; then # allow us to comment out lines in the cmd files
            echo "~~~Running ${b}..."
            echo "${RUN} ./${SHORT_EXE}_base.${CONFIG} ${input}"
            eval ${RUN} ./${SHORT_EXE}_base.${CONFIG} ${input}
         fi
      done
   done
fi

echo ""
echo "Done!"
