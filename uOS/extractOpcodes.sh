#!/bin/bash

#ident "$Id: extractOpcodes.sh,v 1.1 2026/02/18 18:01:34 administrateur Exp $"

#set -x
#set -e

# Extraction des opcodes produits par 'avra' (MSB en tete ;-)

if [ $# -eq 1 ]; then
	if [ -f $1.hex ]; then
		echo "File name:    [$1]"

		avrdisas $1

		if [ ! -f $1.disa ]; then
			echo "No such file '$1.disa'"
			exit 1;
		fi

		cat $1.disa | grep -v ^# |
		awk '
		BEGIN {
			flg_trace = 0

			if (flg_trace) printf("Begin of extraction\n");
		}
		{
			if (flg_trace) printf("#%d [%s]\n", NR, $0);

			if ($0 ~ /:/ && length($0) != 0) {
				split($0, a, ":");
				b = substr(a[2], 4, 24);
				c = substr(b, 14, 12);

				if (length(c) != 0) {
					#printf("\t[%s] (len %d)\n", b, length(b));
					#printf("\t[%s] (len %d)\n", c, length(c));

					if (length(b) >= 19) {
						e = b;	# Extraction with q0

						#printf("%s %s\n", substr(b, 1, 2), substr(b, 4, 2));
						printf("%s %s\n", substr(b, 4, 2), substr(b, 1, 2));

						if (substr(b, 7, 1) != " ") {
							#printf("%s %s\n", substr(b, 7, 2), substr(b, 10, 2));
							printf("%s %s\n", substr(b, 10, 2), substr(b, 7, 2));
						}
					}
					else if (length(b) >= 80) {
						#printf("%s %s\n", substr(b, 1, 2), substr(b, 4, 2));
						printf("%s %s\n", substr(b, 4, 2), substr(b, 1, 2));
					}
					else {
						printf("??? #1: Invalid pattern [%s]\n", $0);
					}
				}
			 	else if (length($0) == 16 && $0 ~ /.dw/) {
					#printf("Datas [%s] (len %d)\n", $0, length($0));
					# Codage naturel des textes
					printf("%s %s\n", substr($0, 13, 2), substr($0, 15, 2));
					#printf("%s %s\n", substr($0, 15, 2), substr($0, 13, 2));
			 	}
				else {
					pos_end_label = index($0, ":");

					if (pos_end_label != length($0)) {
						printf("??? #2: Invalid pattern [%s]\n", $0);
						exit(1);
					}
				}
			 }
		}
		END {
		}
		' > $1.opcodes

		echo "File opcodes: [$1.opcodes]"

	else
		echo "$0: '$1': No such file"
		echo
	fi
else
	echo "Usage: $0 <project>"
	echo
	exit 2
fi

exit 0
