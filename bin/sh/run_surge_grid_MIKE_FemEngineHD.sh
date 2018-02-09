#!/bin/sh
#Script to Run R scripts in local directory

#--- SET CONSTANTS / SET UP VARIABLES ---

QUEUE="$CATRESP_Q"
SLOTS="1"
HELP="FALSE"
PE=""
RUN="true"
EMAIL="false"
INPUT_FILE=""
INPUT_LIST=""
SUBSCRIPT="false"
PROJECT=""
MANY="false"
PE="mpi"
CORES="1"
#MACHINES="1"

#--- SET OTHERS ---

#--- IMPORT FUNCTIONS

source $MDTK_BIN/functions/functions.sh

#--- USAGE ---

usage(){
 echo 
 echo "-----------------------------------------------------------------------------------------"
 echo
 echo "Script to Mike FemEngineHD on all *.m21fm input files in local Directory through the Grid"
 echo "Default behaviour is to run all *.m21fm input files found in Current Directory."
 echo "Individual input files can be specific with the --input option below"	
 echo "Default bevahiour is to create individual Grid Engine Submission Scripts *.sge.sh"
# echo "Grid Engine Submission script can be created with option -subscript"
 echo ""
 echo "Usage run_surge_MIKE_FemEngineHD.sh -options"
 echo "Required Options:"
 echo " --mem please specifiy the maximum memory required per process"
 echo " -P Choose Project"
 echo ""
 echo "Optional Options:"
 echo " --input specify an invidivual *.m21fm input file"
 echo " -n number of cores requested per job(default=1)"
# echo " -m number of machines requested n must be divisble by m (default=1)"
 echo " -q specify the queue to submit to default = $QUEUE"
 echo " --norun just create the submission scripts - do not submit to the queue"
 echo " --pass pass any other options in command line"
 echo " --pe specify parallel enviroment (default mpi can also specify smp)"
 echo " --many Create a Submission script for each individual *.m21fm input file"
 echo " --email Email me when the job is completed"
 echo " --help/-h display this help"
 exit 1
}

#--- OPTIONS ---
OPTIONS=$(getopt -o q:P:n:h:m --long many,norun,email,mem:,input:,help,norun -- "$@")
[ $? -eq 0 ] || { 
	echo "Incorrect options provided"; usage 
} 
eval set -- "$OPTIONS" 
while true; do 
	case "$1" in 
          --input) shift ; INPUT_FILE="$1"  ; echo "INPUT_FILE=$INPUT_FILE";;
          -q) shift ; QUEUE="$1" ; echo "QUEUE=$QUEUE";;
          -P) shift ; PROJECT="$1" ; echo "PROJECT=$PROJECT";;
	  -n) shift ; CORES="$1" ; echo "CORES=$CORES";;
	  #-m) shift ; MACHINES="$1" ; echo "MACHINES=$MACHINES";;
	  --mem) shift ; MEM="$1" ; echo "MEM_REQUIRED=$MEM";;
	  #--pe) shift ; PE="$1" ; echo "PARALELL ENV=$PE";;
	  --pe) shift; # The arg is next in position args 
                 PE=$1 
                 [[ ! $PE =~ mpi|ppn1|ppn2|ppn4|ppn8|ppn16|smp ]] && { 
                 	echo "Incorrect Parallel Execute Enviroment !$PE! provided" ; usage
           } ;;
	  --norun) RUN="false" ;;
	  --email) EMAIL="true" ;;
	  --many) MANY="true" ;;
          -h) usage ;; 
	  --help) usage ;;
          --pass) shift ; PASS="$1" ;;    
          --) shift ; break ;;
        *) echo "Unexpected option $1" ; usage ;; 
        esac 
        shift 
done

shopt -s nullglob

#--- REQUIRED OPTIONS CHECKING ---

if [ -z "$PROJECT" ]; then echo "No Project Defined";usage; fi
if [ -z "$MEM" ]; then echo "No Memory Usage Defined";usage; fi
#if ! [ $CORES%$MACHINES==0 ]; then echo "Number of CORES must be divisble by Number of MACHINES";usage; fi

# --- BUILD ARRAY OF INPUT FILES TO RUN THROUGH OR USER SPECIFED INPUT ---
if [ ! "$INPUT_FILE" == "" ]; then
 if [ ! -f "$INPUT_FILE" ]; then
    echo "No input file found !"
    usage
 fi
 INPUT_LIST=("$INPUT_FILE") 
else
 for INPUT_FILE in *.m21fm; do
  if [ ! "$INPUT_LIST" == "" ]; then
   INPUT_LIST=("${INPUT_LIST[@]}" "$INPUT_FILE")
  else
   INPUT_LIST=("$INPUT_FILE")
  fi
 done
fi

echo "INPUT_LIST=${INPUT_LIST[@]}"
echo "EMAIL=$EMAIL"
echo "MANY=$MANY"
echo "RUN=$RUN"
echo "QUEUE=$QUEUE"


echo "CORES=$CORES:MACHINES=$MACHINES"

#---Create Many SGE Scripts ---
if [ "$MANY" = "true" ] || [ "$#{INPUT_LIST[@]}" = "1" ]; then


 #--- LOOP THROUGH R SCRIPTS ---
 for INPUT_FILE in "${INPUT_LIST[@]}"; do
 
  echo "INPUT_FILE=$INPUT_FILE"
 
  #--- Create Submission Script *.sge.sh ---
 
  NAME=${INPUT_FILE%.*}
  SGE_SH=$NAME.sge.sh
  DIR=`pwd`
 
  #--- SGE SPECIFIC ---
  echo >$SGE_SH "#!/bin/sh"
  echo >>$SGE_SH "#$ -o \$JOB_ID-$NAME-screen.out"
  echo >>$SGE_SH "#$ -e \$JOB_ID-$NAME-error.out"
  echo >>$SGE_SH "#$ -cwd"
  echo >>$SGE_SH "#$ -S /bin/sh"
  echo >>$SGE_SH "#$ -q $QUEUE"
  echo >>$SGE_SH "#$ -P $PROJECT" 
  echo >>$SGE_SH "#$ -l mem_free=$MEM"
  if [ "$EMAIL" = "true" ]; then
   echo >>$SGE_SH "#$ -m ea"
   echo >>$SGE_SH "#$ -M $USER_EMAIL"
  fi
   
  #---WRITE MODULE INFO TO SCRIPT---
  echo >>$SGE_SH 
  echo >>$SGE_SH "module purge"
  echo >>$SGE_SH "module load MIKE"
 
  #--- MAIN JOB SCRIPT ---
  echo >>$SGE_SH 
  CMD_EXE="mpirun -n $CORES FemEngineHD $INPUT_FILE"
  echo >>$SGE_SH "$CMD_EXE"

  if [ "$RUN" = "true" ]; then
   echo "Submitting $NAME"
   qsub $SGE_SH
  fi
  
 done

#---Create Single SGE Script ---
 else

  #NAME=RScripts_$TIME_DATE
  NAME=MIKEjobs_$DATE
  #--- Create Submission Script *.sge.sh ---
  SGE_SH=$NAME.sge.sh
  DIR=`pwd`
  
  #--- SGE SPECIFIC ---
  echo >$SGE_SH "#!/bin/sh"
  echo >>$SGE_SH "#$ -o \$JOB_ID-$NAME-screen.out"
  echo >>$SGE_SH "#$ -e \$JOB_ID-$NAME-error.out"
  echo >>$SGE_SH "#$ -cwd"
  echo >>$SGE_SH "#$ -S /bin/sh"
  echo >>$SGE_SH "#$ -q $QUEUE"
  echo >>$SGE_SH "#$ -P $PROJECT" 
  echo >>$SGE_SH "#$ -t 1-${#INPUT_LIST[@]}"
  echo >>$SGE_SH "#$ -l centos=*"
  echo >>$SGE_SH "#$ -l mem_free=$MEM"
  echo >>$SGE_SH "#$ -pe $PE $CORES"
  if [ "$EMAIL" = "true" ]; then
   echo >>$SGE_SH "#$ -m ea"
   echo >>$SGE_SH "#$ -M $USER_EMAIL"
  fi
  if [ "$CORES" -gt "16" ];
  then
   echo 'Large number of Core Requested; Reservation Enabled'
   echo >>$SGE_SH '#$ -R y'
  fi

  #--- LOOP THROUGH R SCRIPTS ---
  echo >>$SGE_SH 
  echo >>$SGE_SH "INPUT_LIST=(${INPUT_LIST[@]})"
 
  #---WRITE MODULE INFO TO SCRIPT---
  echo >>$SGE_SH 
  echo >>$SGE_SH "module purge"
  echo >>$SGE_SH "module load MIKE"
 
  #--- MAIN JOB SCRIPT ---
  
  echo >>$SGE_SH "echo \"Running \${INPUT_LIST[\$SGE_TASK_ID-1]}\""
  CMD_EXE="mpirun -n $CORES FemEngineHD \${INPUT_LIST[\$SGE_TASK_ID-1]}"
  echo >>$SGE_SH 
  echo >>$SGE_SH "$CMD_EXE"

  if [ "$RUN" = "true" ]; then
   echo "Submitting $SGE_SH"
   qsub $SGE_SH
  fi

fi


