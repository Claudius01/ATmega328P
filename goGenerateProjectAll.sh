#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProjectAll.sh,v 1.1.1.1 2026/11/11 17:36:19 administrateur Exp $"

# Script de production (clean et generation) de tous les projets
# Exemples:
#   $ ./goGenerateProjectAll.sh
#   $ ./goGenerateProjectAll.sh clean

# Remarque: L'ordre de la production doit respecter les dependances (ie. 'ATmega328P_uOS' avant 'ATmega328P_monitor')

#set -x
set -e

if [ ${1} == "clean" ]; then
	(
		cd uOS
		./goGenerateProject.sh clean
	)

	(
		cd monitor
		./goGenerateProject.sh clean
	)

	(
		cd optiBoot
		./goGenerateProject.sh clean
	)
else
	(
		cd uOS
		./goGenerateProject.sh ATmega328P_uOS
	)

	(
		cd monitor
		./goGenerateProject.sh ATmega328P_monitor
	)

	(
		cd optiBoot
		./goGenerateProject.sh ATmega328P_optiBoot
	)
fi

exit 0
