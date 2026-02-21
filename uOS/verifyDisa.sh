#!/bin/bash

#ident "$Id: verifyDisa.sh,v 1.1 2026/02/18 18:01:34 administrateur Exp $"

#set -x
#set -e

cat $1 | grep -v ^# |

awk '
BEGIN {
}
{
	len = length($0);

	n = split($0, a, " ");

	if (n == 1) {
		printf("%s\n", $0);
	}
	else if (len > 24) {
		code = substr($0, 25);

		split(code, a, " ");
		if (a[1] == "lds") {
			split(a[2], b, ",");
			printf("\tlds     %s, %s\n", a[3], b[1]);	
		}
		else {
			printf("\t%s\n", code);
		}
	}
}
END {
}
'

exit 0

