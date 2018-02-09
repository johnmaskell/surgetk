#!/bin/bash
# Script to Rearrange SGE pe_hostfile to HOSTLIST script
# 23/10/14 RRobinson

#ARGUMENTS
HOSTFILE=$1
LOGICAL=$2
HOSTLIST=""

#echo "LOGICAL=$LOGICAL"

if [ -f $HOSTFILE ] 
then
 while read line           
 do           
   arr=(`echo ${line}`);
   if [ "$LOGICAL" = "LOGICAL" ];
    then
      for i in `seq 1 ${arr[1]}`;
      do
        HOSTLIST="$HOSTLIST"${arr[0]}":cpus=1 "
      done  
    else  
     HOSTLIST="$HOSTLIST"${arr[0]}":cpus="${arr[1]}" "
    fi
   #echo $HOSTLIST
 done <$HOSTFILE
 HOSTLIST=$HOSTLIST
 echo $HOSTLIST
else
 echo 'There is no Host File Exiting'
fi

