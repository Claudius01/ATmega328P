#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProjectAll4Simu.sh,v 1.1 2026-02-14 16:54:07 crudel Exp $"

# Script de production (clean et generation) de tous les projets pour la simulation
# Exemples:
#   $ ./goGenerateProjectAll4Simu.sh
#   $ ./goGenerateProjectAll4Simu.sh clean

# Remarque: L'ordre de la production doit respecter les dependances (ie. 'ATmega328P_uOS' avant 'ATmega328P_monitor')

#set -x
set -e

if [ ${1} == "clean" ]; then
	(
		cd uOS
		./goGenerateProject4Simu.sh clean
	)

	(
		cd monitor
		./goGenerateProject4Simu.sh clean
	)
else
	(
		cd uOS
		./goGenerateProject4Simu.sh ATmega328P_uOS
	)

	(
		cd monitor
		./goGenerateProject4Simu.sh ATmega328P_monitor
	)
fi

exit 0
