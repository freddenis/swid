#!/bin/bash
#

CONF=conf
AWK=$(type awk)
#echo $AWK

cat ${CONF} |	grep -v "^#" 		|	sed 's/^-/\n-/' 	|	sed 's/#.*$//g'		|\
		sed 's/\t//g'		|	sed 's/^ *//'		|	sed 's/ *: */:/'	|\
		sed 's/ *$//g'		|\
awk '   BEGIN\
	{	   FS = ":"						;
		first = 1						;
		end_tag = "the_end" systime()				;	# To avoid another alias named like this one
                # some colors
             COLOR_BEGIN =       "\033[1;"              ;
             #COLOR_BEGIN =       "\033["               ;
               COLOR_END =       "\033[m"               ;
                     RED =       "31m"                  ;
                   GREEN =       "32m"                  ;
                  YELLOW =       "33m"                  ;
                    BLUE =       "34m"                  ;
                    TEAL =       "36m"                  ;
                   WHITE =       "37m"                  ;
	}
	function print_a_line(size)
        {
               if (! size)
               {       size = 120					;
               }
               printf("%s", COLOR_BEGIN WHITE)                          ;
               for (k=1; k<=size; k++) {printf("%s", "*");}             ;
               printf("%s", COLOR_END)                              	;
        }
	{	# Config
		if ($1 ~ /^- config/)
		{	#print $1					;
			if ($1 == "begin")	{begin = $2	}	;
			if ($1 == "during")	{during = $2	}	;
			if ($1 == "end")	{end = $2	}	;
			
		}
		# Names
		if ($1 ~ /^- names/)
		{	#print $1					;
			while (getline)
			{	
				if ($1 ~ /^$/)
				{	break				;
				}
			#	print $0				;
				tab_names[$1] = $2			;
			}
		}
		# Dependencies
		if ($1 ~ /^- dependencies/)
		{	#print $1					;
			if (first)
			{
                        	printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H:%M:%S\"`")             ;	# A timestamp
				#TS := `/bin/date +%Y-%m-%d-%H:%M:%S`
				printf("%s\n", "done: "end_tag)		;
				first = 0				;
			}
			while (getline)
			{	
				if ($1 ~ /^$/)
				{	break				;
				}
				if ($0 !~ /:/)					# If no dependency, we may not have a ":" after the alias
				{	$0 = $0":"			;
				}
				printf("%s\n", $0)			;		# Name of the step on the dependencies
				printf("\t%s -- %s\n", "@echo \"$(TS)\"", $0)	;	# Print a timestamp
				printf("\t%s", "@echo \"")		;
				print_a_line()				;
				printf("%s\n", "\"")			;
				printf("\t%s\n", tab_names[$1])		;	# What to execute
				printf("\t%s\n", "@echo\"\"")			;
			}
		}
	}
	END\
	{	
		printf("%s:%s\n", end_tag, $1)				;
	}
    '

	


exit



#- config
#begin:mailx -s "done" people@company.company
#end:echo "done"
#during:mailx -s $STEP done people@company.company
#email:people@company.com
#- names
#backup:backup.sh
#step1:launch_sql.sh step1
#step2:launch_sql.sh step2
#final_step:final_step.sh -p blabla
#- dependencies
#backup
#step1:backup
#step2:backup
#final_step:step1, step2
