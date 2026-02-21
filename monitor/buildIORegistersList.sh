#!/bin/bash

#ident "$Id: buildIORegistersList.sh,v 1.1 2026/02/18 18:03:10 administrateur Exp $"

#set -x
#set -e

if [ $# -eq 1 -a -f $1 ]; then
	echo "# Configuration File automatically (don't modify) by [$0]"
	echo "# File name: [$1]"
	dir_name=`dirname $1` 
	file_name=`basename $1` 
	name=`echo $file_name | cut -d'.' -f1`
	ext=`echo $file_name | cut -d'.' -f2`
	echo "# Dir [$dir_name] Base [$file_name] Name [$name] Ext [$ext]"
	echo

	if [ "$ext" != "lst" ]; then
		echo
		echo "Error: Invalid extension [$ext] ('lst' expected)"
		exit 2
	fi

	# Generation d'un fichier de configuration 'avrdisas.conf' comme:
	# 	Unit            Global
	# 	Register        0x37    SPMCSR

	cat $1 | 
	awk '
	BEGIN {
		flg_extract = 0;
	}
	($0 ~ /I\/O REGISTER DEFINITIONS/) {	
		flg_extract = 1;

		printf("Unit\tGlobal\n");
	}
	($0 ~ /BIT DEFINITIONS/) {	
		flg_extract = 0;
	}
	{
		if (flg_extract) {
			if ($1 == ".equ") {
				printf("Register\t%s\t%s\n", $4, $2);
			}
		}
	}
	END {
		printf("\n");
		printf("# End of file\n");
	}
	'
else
	echo "Usage: $0 <file.lst>"
	echo
	exit 2
fi

exit 0

