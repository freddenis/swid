#!/bin/bash
# Fred Denis -- Feb 2020 -- fred.denis3@gmail.com -- https://unknowndba.blogspot.com
#    swid.sh -- a Scheduler WIth Dependencies
#

#
# Variables
#
 JOB_FILE="swid.jobs"					# Default job file
RETENTION=31						# Number of days we keep the logs and tempfiles (they are purged after each execution)
       TS="date +%Y-%m-%d-%H:%M:%S"			# A timestamp
  TMP_DIR="./tmp"					# To save the makefiles
 MAKEFILE="${TMP_DIR}/makefile.tmp${RANDOM}$$"		# Makefile name
  LOG_DIR="./logs"					# For the logs
  LOGFILE="${LOG_DIR}/${JOB_FILE}_${TS}"		# Logfile of the makefile execution
     TMP1="${TMP_DIR}/swidtempfile${RANDOM}$$.tmp" 	# A tempfile to save the cleaned up job file
#
# Variables checks
#
if ! [ -x "$(command -v make)" ]
then
	printf "\n\t\033[1;31m%s\n\n" "ERROR -- make is needed on the system but cannot be found; please have it installed (yum install make or apt install make); cannot continue for now."
	exit 123
fi
for X in ${TMP_DIR} ${LOG_DIR}
do
	if [[ ! -d ${X} ]] 
	then
		mkdir -p ${X}
		if [ $? -eq 0 ]
		then
			printf "\033[1;36m%s\033[m\n" "INFO -- $($TS) -- ${X} has been successfully created."
		else
			printf "\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Could not create ${X}; cannot continue."
			exit 124
		fi
	fi
done
#
# Clean up the job file
#
cat ${JOB_FILE} |	grep -v "^#" 		|	sed 's/^-/\n-/' 	|	sed 's/#.*$//g'		|\
			sed 's/\t//g'		|	sed 's/^ *//'		|	sed 's/ *: */:/'	|\
			sed 's/ *$//g'		> ${TMP1}
#
# Generate the makefile
#
cat ${TMP1} |\
awk '   BEGIN\
	{	   FS = ":"							;
		first = 1							;
		cpt   = 1							;
		end_tag = "the_end" systime()					;		# To avoid another alias named like this one
                # some colors
             COLOR_BEGIN =       "\033[1;"              			;
               COLOR_END =       "\033[m"               			;
                     RED =       "31m"                  			;
                   GREEN =       "32m"                  			;
                  YELLOW =       "33m"                  			;
                    BLUE =       "34m"                  			;
                    TEAL =       "36m"                  			;
                   WHITE =       "37m"                  			;
	}
	function print_a_line(size)
        {
               if (! size)
               {       size = 120						;
               }
               printf("%s", COLOR_BEGIN WHITE)                          	;
               for (k=1; k<=size; k++) {printf("%s", "*");}             	;
               printf("%s", COLOR_END)                              		;
        }
	{	# Names
		if ($1 ~ /^- names/)
		{	while (getline)
			{	
				if ($1 ~ /^$/)
				{	break					;
				}
				tab_names[$1] = $2				;
			}
		}
		# Dependencies
		if ($1 ~ /^- dependencies/)
		{	#print $1						;
			if (first)
			{
                        	printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H:%M:%S\"`");	# A timestamp
				printf("%s\n", "done: "end_tag)			;
				first = 0					;
			}
			while (getline)
			{	
				if ($1 ~ /^$/)
				{	break					;
				}
				if ($0 !~ /:/)							# If no dependency, we may not have a ":" after the alias
				{	$0 = $0":"				;
				}
				printf("%s\n", $0)				;		# Name of the step on the dependencies
				#printf("\t%s -- %s\n", "@echo \"$(TS)\"", $0)	;		# Print a timestamp
				printf("\t%s -- %s\n", "@echo STEP"cpt" -- \"$(TS)\"", $0)	;		# Print a timestamp
				printf("\t%s", "@echo \"")			;
				print_a_line()					;
				printf("%s\n", "\"")				;
				printf("\t%s\n", tab_names[$1])			;		# What to execute
				printf("\t%s\n", "@echo\"\"")			;
				cpt++						;
			}
		}
	}
	END\
	{	
		printf("%s:%s\n", end_tag, $1)					;
	}
    ' > ${MAKEFILE}
#
# Run the makefile
#
if [[ ! -f ${MAKEFILE} ]] 
then
	printf "\t\033[1;31m%s\n" "There was an issue generating the makefile ${MAKEFILE}; cannot continue."
	exit 234
else
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Makefile ${MAKEFILE} successfully generated."
	sleep 3
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Logfile ${LOGFILE} will be used."
fi
make -f ${MAKEFILE} ${PARALLEL} | sed 's/^/\t/' | tee ${LOGFILE}
RET=${PIPESTATUS[0]}					# Make return code
if [ ${RET} -eq 0 ]
then
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Execution of makefile ${MAKEFILE} was successful with no error."
	ON_SUCCESS=$(grep "^on_success" ${TMP1} | awk -F ":" '{print $2}')
	if [[ -n ${ON_SUCCESS} ]]
	then
		printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- on_success action"
		eval "${ON_SUCCESS}" | sed 's/^/\t/'
	fi
else
	printf "\t\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Got error $RET when executing the makefile ${MAKEFILE}."
	ON_FAILURE=$(grep "^on_failure" ${TMP1} | awk -F ":" '{print $2}')
	if [[ -n ${ON_FAILURE} ]]
	then
		printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- on_failure action"
		eval "${ON_FAILURE}" | sed 's/^/\t/'
	fi
fi
#
# Clean uo
#
if [[ -f ${TMP1} ]]
then
	rm -f ${TMP1}
fi
#
printf "\n"
exit ${RET}
#
#****************************************************************************************#
#*			E N D        O F       S O U R C E 				*#
#****************************************************************************************#
