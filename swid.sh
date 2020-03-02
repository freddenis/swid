#!/bin/bash
# Fred Denis -- Feb 2020 -- fred.denis3@gmail.com -- https://unknowndba.blogspot.com
#
#    swid.sh -- Schedule WIth Dependencies
#
# Please have a look at http://bit.ly/2v0HX6z for information on how swid works; alternatively, ./swid.sh -h is also a good way to start
#
# History:
# 20200302 - -u otion to remove color codes from the logfile; no ":" in the logfile name, I put "-" instead
#	     also new -i option to ignore the errors and continue
# 20200301 - new -l and -t option to specifcy the log and tmp directories
# 20200229 - make option -O only exists from GNU make 4 -- added a test on the version to avoid errors for those with make < 4
#            make 4 has been released in 2013 so it should be widely available on any system
# 20200224 - Initial Release
#
# Variables -- these one can be changed from the command line options
#
   JOB_FILE="job_def.swid"				# (-j) Default job dependencies definition file
     DRYRUN=""						# (-d) Default dry run option -- show what it would do but dont do anything
   PARALLEL=""						# (-p) Default parallelism degree (no value = maximum parallelism)
  RETENTION=31						# (-r) Number of days we keep the logs and tempfiles (they are purged after each execution)
OUTPUT_SYNC="-Otarget"					# (-o/-O) The way the output is shown for parallel executions:
							#	- target = output sorted by step executed 	   (-o)
							# 	- none   = logs shown as soon as they are executed (-O)
  KEEPGOING=""						# (-k) Keep going as much as make can if an error happens	 
    TMP_DIR="./tmp"					# (-t) To save the makefiles
    LOG_DIR="./logs"					# (-l) For the logs
WITH_COLORS="Yes"					# (-u) Keep the colors in the logfile or not
 IGNORE_ERR=""						# (-i) make ignore all the errors and continue
#
# Variables for internal use, you may not want to change these ones
#
       TS="date +%Y-%m-%d_%H-%M-%S"			# A timestamp
#
# usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` Schedule WIth Dependencies any job based on a simple job definition file
END
printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-j] [-r] [-d] [-o] [-O] [-p] [-k] [-l] [-t] [-u] [-i] [-h]
END
printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        - `basename $0` Schedules WIth Dependencies any job based on a simple job definition file
	- Below a job definition file example (available in examples/job_def.swid):
		- config:        								# Format is "config:value"
			on_success	:	echo "all good !"
			on_failure	:	echo "oh no, it failed !!"

		- names:         								# Format is "alias:command_to_execute"
			start		:	~/swid/examples/ISleep.sh 1
			do_stuff1	:	~/swid/examples/ISleep.sh 2
			do_stuff2	:	~/swid/examples/ISleep.sh 6			# This is a comment
			do_stuff3	:	~/swid/examples/ISleep.sh 4
			do_stuff4	:	~/swid/examples/ISleep.sh 8
			do_stuff5	:	~/swid/examples/ISleep.sh 3
		#	do_stuff6	:	~/swid/examples/ISleep.sh 14			# This wont be executed as it is commented out
			end		:	~/swid/examples/ISleep.sh 1

		- dependencies:   								# Format is "alias:dependency1 dependency2"
			start		:							# First step to execute, no dependency to anything
			do_stuff1	: 	start						# Depends on "start"
			do_stuff2	: 	start						# Depends on "start"
			do_stuff3	: 	start						# Depends on "start"
			do_stuff4	: 	start						# Depends on "start"
			do_stuff5	: 	do_stuff1 do_stuff2 do_stuff3 do_stuff4		# Depends on do_stuff1, do_stuff2, do_stuff3 and do_stuff4
			end		:	do_stuff5

	- Jobs executions are stopped in case of error (already running jobs finish and the next ones wont be started -- except if -k is specified)
	- The only requirement for `basename $0` to work is to have "make" installed on the system as it relies essentially on makefiles
	  (yum install make or apt install make) in the less lilekly scenario "make" would not already be installed on your system
END
printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -j      The path to a job dependency definition file (see above for an example)
        -p      Parallelism degree (default is maximum parallelism)
        -d      Dry run mode, won't do anything, just show what would be done
        -oO     When executing jobs in parallel, log lines can be interlaced between few parallel jobs: (for GNU Make >= 4 only)
		- The -o option (which is the default) shows the logs of a step only when it is done and then the logs are well sorted and not interlaced with other steps
		- The -O option shows the logs as soon as they are generated leading to interlaced logs -- but you will see them faster than with -o
        -r      `basename $0` is very nice and automatically purges the tempfiles and logfiles he used keeping the retention days specified by this parameter
	-k	- Keep going; tries to go as far as it can in case of error
	-l	Specific the log directory
	-t	Specify the temporary files directory
	-u	Remove the color codes from the logfile
	-i	Ignore the errors, show them as warning and continue

        -h      Shows this help

END
exit 555
}
#
# Command line variables
#
while getopts "j:dhr:p:oOkl:t:ui" OPT; do
        case ${OPT} in
        j)    JOB_FILE="${OPTARG}"					;;
	r)   RETENTION="${OPTARG}"					;;
	d)	DRYRUN=" --dry-run "					;;
	p)    PARALLEL="${OPTARG}"					;;
	o) OUTPUT_SYNC="-Otarget"					;;
	O) OUTPUT_SYNC="-Onone"						;;
	k)   KEEPGOING="-k"						;;
	t)     TMP_DIR="${OPTARG}"					;;
	l)     LOG_DIR="${OPTARG}"					;;
	u) WITH_COLORS="No"						;;
	i)  IGNORE_ERR="-i"						;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Variables checks
#
if ! [ -x "$(command -v make)" ]
then
	printf "\n\t\033[1;31m%s\n\n" "ERROR -- make is needed on the system but cannot be found; please have it installed (yum install make or apt install make); cannot continue for now."
	exit 123
fi
#
# We can now build the names of the lofiles and tempfiles
#
 MAKEFILE="${TMP_DIR}/makefile.tmp${RANDOM}$$"		# Makefile name
  LOGFILE="${LOG_DIR}/`basename ${JOB_FILE}`_$(${TS})"	# Logfile of the makefile execution
     TMP1="${TMP_DIR}/swidtempfile${RANDOM}$$.tmp" 	# A tempfile to save the cleaned up job file
#
# make option -O only available for GNU make >= 4
#
MAKE_VERSION=$(make -v | head -1 | awk '{printf("%d", $NF)}')
if (( MAKE_VERSION < 4 ))
then
	OUTPUT_SYNC=""		# Option -O only available for GNU make >= 4
fi
for X in ${TMP_DIR} ${LOG_DIR}
do
	if [[ ! -d ${X} ]] 
	then
		mkdir -p ${X}
		if [ $? -eq 0 ]
		then
			printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- ${X} has been successfully created."		| tee -a ${LOGFILE}
		else
			printf "\t\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Could not create ${X}; cannot continue."	| tee -a ${LOGFILE}
			exit 124
		fi
	fi
done
#
# A job definition file is needed
#
if [[ ! -f ${JOB_FILE}  ]] 
then
	printf "\t\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Could not find the job dependencies definition file ${JOB_FILE}; please use the -j option to specify one; cannot continue."	| tee -a ${LOGFILE}
	exit 125
fi
#
# We show the parameters we will be using -- it maybe useful for troubleshooting
#
if [[ -n ${DRYRUN} ]] 
then
	printf "\t\033[1;32m%s\033[m\n" "INFO -- $($TS) -- This is a dryrun mode (-d option selected); nothing will be executed; only shown what would be executed." | tee -a ${LOGFILE}
fi
if [[ "$PARALLEL" = "0" ]]
then
        PARALLEL=1
fi
if [[ -z ${PARALLEL} ]] 
then
	show_parallel="Max"
else
	show_parallel=${PARALLEL}
fi
if [[ -z ${IGNORE_ERR} ]]
then
	SHOW_IGNORE_ERR="No"
else
	SHOW_IGNORE_ERR="Yes"
fi
printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- (-j) Job dependencies definition file	: ${JOB_FILE}"		| tee -a ${LOGFILE}
printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- (-p) Parallel degree for execution	: ${show_parallel}"		| tee -a ${LOGFILE}
printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- (-r) Retention days for ${TMP_DIR} and ${LOG_DIR} purge: ${RETENTION}" | tee -a ${LOGFILE}
printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- (-i) Ignore the errors and continue	: ${SHOW_IGNORE_ERR}" 		| tee -a ${LOGFILE}
printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- (-u) Colors code in the logfile		: ${WITH_COLORS}"	| tee -a ${LOGFILE}
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

				#printf("\t%s -- %s\n", "@echo good one STEP"cpt" -- \"$(TS)\"", $0)	;		# Print a timestamp
				printf("\t%s", "@echo \"")			;
			        printf("%s", COLOR_BEGIN TEAL)			;
				printf("%s -- %s", "STEP"cpt" -- \"$(TS)\"", $0);
			        printf("%s\n", COLOR_END"\"")			;

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
	printf "\t\033[1;31m%s\n" "There was an issue generating the makefile ${MAKEFILE}; cannot continue."	| tee -a ${LOGFILE}
	exit 234
else
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Makefile ${MAKEFILE} successfully generated."	| tee -a ${LOGFILE}
	sleep 3
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Logfile ${LOGFILE} will be used."			| tee -a ${LOGFILE}
fi
#
make -f ${MAKEFILE} -j ${PARALLEL} ${DRYRUN} ${KEEPGOING} ${OUTPUT_SYNC} ${IGNORE_ERR} | tee -a ${LOGFILE} | sed 's/^/\t/' 
#
RET=${PIPESTATUS[0]}					# Make return code
if [ ${RET} -eq 0 ]
then
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Execution of makefile ${MAKEFILE} was successful with no error." | tee -a ${LOGFILE}
	ON_SUCCESS=$(grep "^on_success" ${TMP1} | awk -F ":" '{print $2}')
	if [[ -n ${ON_SUCCESS} ]]
	then
		printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- on_success action"				| tee -a ${LOGFILE}
		eval "${ON_SUCCESS}" | sed 's/^/\t/'								| tee -a ${LOGFILE}
	fi
else
	printf "\t\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Got error $RET when executing the makefile ${MAKEFILE}." | tee -a ${LOGFILE}
	ON_FAILURE=$(grep "^on_failure" ${TMP1} | awk -F ":" '{print $2}')
	if [[ -n ${ON_FAILURE} ]]
	then
		printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- on_failure action"				| tee -a ${LOGFILE}
		eval "${ON_FAILURE}" | sed 's/^/\t/'								| tee -a ${LOGFILE}
	fi
fi
#
# Clean up
#
if [[ -f ${TMP1} ]]
then
	rm -f ${TMP1}
fi
find ${LOG_DIR} ${TMP_DIR} -type f -mtime ${RETENTION} -delete
RET_FIND=$?
if [ ${RET_FIND} -eq 0 ] 
then
	printf "\t\033[1;36m%s\033[m\n" "INFO -- $($TS) -- Successfully purged ${LOG_DIR} and ${TMP_DIR} with a ${RETENTION} days retention period."	| tee -a ${LOGFILE}
else
	printf "\t\033[1;31m%s\033[m\n" "ERROR -- $($TS) -- Got error ${RET_FIND} when purging ${LOG_DIR} and ${TMP_DIR} with a ${RETENTION} days retention period." | tee -a ${LOGFILE}
	if [ ${RET} -eq 0 ]
	then
		RET=${RET_FIND}
	fi
fi
#
# Remove the colors from the logfile
#
if [[ "${WITH_COLORS}" = "No" ]] 
then
	sed -ri "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" ${LOGFILE}
fi
#
printf "\n"
exit ${RET}		# We exit with the makefile execution return code
#
#****************************************************************************************#
#*			E N D        O F       S O U R C E 				*#
#****************************************************************************************#
