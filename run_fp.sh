#!/bin/bash

TARGET_RUN=""
INPUT_TYPE=test # THIS MUST BE ON LINE 4 for an external sed command to work!
                # this allows us to externally set the INPUT_TYPE this script will execute

BENCHMARKS=(410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3)

base_dir=$PWD
for b in ${BENCHMARKS[@]}; do

   echo " -== ${b} ==-"
   mkdir -p ${base_dir}/output

   cd ${base_dir}/${b}
   SHORT_EXE=${b##*.} # cut off the numbers ###.short_exe
   if [ $b == "483.xalancbmk" ]; then 
      SHORT_EXE=Xalan #WTF SPEC???
   fi
   if [ $b == "482.sphinx3" ]; then
      SHORT_EXE=sphinx_livepretend
   fi
   
   # read the command file
   IFS=$'\n' read -d '' -r -a commands < ${base_dir}/commands/${b}.${INPUT_TYPE}.cmd

   # run each workload
   count=0
   for input in "${commands[@]}"; do
      if [[ ${input:0:1} != '#' ]]; then # allow us to comment out lines in the cmd files
         cmd="${TARGET_RUN} ./${SHORT_EXE} ${input} > ${base_dir}/output/${SHORT_EXE}.${count}.out"
         echo "workload=[${cmd}]"
         eval ${cmd}
         ((count++))
      fi
   done
   echo ""

done


echo ""
echo "Done!"
