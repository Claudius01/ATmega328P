#!/bin/bash

#ident "$Id: buildFileTag.sh,v 1.2 2026/02/18 17:31:06 administrateur Exp $"

#set -x
#set -e

if [ $# -eq 1 -a -f $1 ]; then
	#echo "File name: [$1]"
	dir_name=`dirname $1` 
	file_name=`basename $1` 
	name=`echo $file_name | cut -d'.' -f1`
	#echo "Dir [$dir_name] Base [$file_name] Name [$name]"

	cat $1 | grep -v ^[_][_][A-Z] | grep -v ^[_][A-Z] |
	awk '
	BEGIN {
	}
	function asc2hex(i__value, i__len)
	{
		l__value = 0;
		for (l__n = 1; l__n <= i__len; l__n++) {
			l__c = substr(i__value, l__n, 1);

			l__value *= 16;
			if (l__c <= '9') {
				l__value += (l__c - '0');
			}
			else {
				if (l__c == "a") l__value += 10;
				else if (l__c == "b") l__value += 11;
				else if (l__c == "c") l__value += 12;
				else if (l__c == "d") l__value += 13;
				else if (l__c == "e") l__value += 14;
				else if (l__c == "f") l__value += 15;
			}
		}

		return (l__value);
	}
	($0 ~ /^[_a-z]/) {	
		if (length($0) > 0) {
			printf("0x%s\tL\t%s\n", $3, $1);
		}
	}
	($0 ~ /^[A-Z]/) {	
		if (length($0) > 0) {
			address = asc2hex($3, 4);
			# Test dans la plage SRAM [0x100...0x8FF]
			if (address >= 256 && address <= 2303) {
				printf("0x%s\tM\t%s\n", $3, $1);
			}
		}
	}
	{
	}
	END {
	}
	' | sort -u
else
	echo "Usage: $0 <file.map>"
	echo
	exit 2
fi

exit 0

