#!/bin/bash
#
PROGRAM="$0 $@"
echo "Start $PROGRAM: "`date`
if [[ -z $1 ]] 
then
	SLEEP=1
else
	SLEEP=$1
fi
echo "Run $PROGRAM: Sleeping: $SLEEP seconds."
sleep ${SLEEP}
echo "End $PROGRAM: "`date`
