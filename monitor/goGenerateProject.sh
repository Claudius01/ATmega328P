#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProject.sh,v 1.4 2026/02/24 16:51:32 administrateur Exp $"

# Script de production (clean et generation) d'un projet passe en argument
# Exemples:
#   $ ./goGenerateProject.sh ATmega328P_monitor                  -> Production de l'extension "Moniteur" s'appuyant sur Micro OS
#   $ ./goGenerateProject.sh clean                               -> Clean du Micro OS et de l'extension "Moniteur"

# Remarque: L'ordre de la production doit respecter les dependances (ie. 'ATmega328P_uOS' avant 'ATmega328P_monitor')

#set -x
set -e

AVRA_DIR="/home/administrateur/Programmes/avra-master_1.4.3"
AVRA_BIN="${AVRA_DIR}/src/avra"
AVRA_INC="${AVRA_DIR}/includes"

PROJECTS="."

if [ -z ${1} ]; then
	echo "Usage: $0 clean|name_project"
	echo "Examples:"
	echo "  - $0 clean"
	echo "  - $0 ATmega328P_monitor"
	exit 2
elif [ "${1}" == "clean" ]; then
	echo "Clean project..."

	BASE_PROJECT=`basename $PWD`
	echo "Remove files produced from [${BASE_PROJECT}]..."

	rm -f *.hex *.obj *.map *.lst *.tag *.pub *.eep.hex *_for_C.def *.opcodes *.disa
	rm -f Products/*

	exit 0
fi

echo "List of project produced:"
echo $*

for project in $*
do
	PROJECTS_FILE=${project}

#PROJECTS_FILE="${PROJECTS}/${1}"

EXT_ASM="asm"
EXT_LST="lst"
EXT_MAP="map"
EXT_DEF="def"
EXT_PUB="pub"
EXT_OBJ="obj"
EXT_HEX="hex"
EXT_TAG="tag"

rm -f ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_MAP} ${PROJECTS_FILE}.${EXT_PUB} ${PROJECTS_FILE}.${EXT_OBJ} ${PROJECTS_FILE}.${EXT_HEX}

echo
echo "################## Production of '${PROJECTS_FILE}' ##################"

# Warning: USE_AVRSIMU=1 pour la cible et USE_AVRSIMU=0 pour la simulation
${AVRA_BIN} -D USE_AVRSIMU=0 -I ${PROJECTS} -I ../uOS -I ${AVRA_INC} -m ${PROJECTS_FILE}.${EXT_MAP} -l ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_ASM}

if [ ! -f ${PROJECTS_FILE}.${EXT_LST} ]; then
	echo "Error: No build ;-("	
	exit 1
fi

# Extraction des variables, flags et subroutines prefixees par "UOS_" ou "uos_"
# => Definitions necessaires a la production correcte d'un programme s'appuyant sur uOS ;-)
#    => Remarque: Production imperative de uOS avant les programmes
#                 => TOUS LES FICHIERS *.pub DOIVENT ETRE IDENTIQUES ;-)
echo
echo "Construction de '${PROJECTS_FILE}.pub' a partir de '${PROJECTS_FILE}.${EXT_MAP}'...."
echo "; === '${PROJECTS_FILE}.pub': Automatic generated (DON'T MODIFY) ===" > ${PROJECTS_FILE}.pub
grep -i ^uos_ ${PROJECTS_FILE}.${EXT_MAP} |
awk '
{
	printf("#define\t%s\t\t\t0x%s\n", $1, $3);	
} ' >> ${PROJECTS_FILE}.pub
echo "; === End of Automatic generated (DON'T MODIFY) ===" >> ${PROJECTS_FILE}.pub

FILE_NAME_PUB_FOR_C=${PROJECTS_FILE}"_for_C"

echo "Construction de '${FILE_NAME_PUB_FOR_C}.pub' a partir de '${PROJECTS_FILE}.${EXT_MAP}'...."
echo "// '${FILE_NAME_PUB_FOR_C}.pub': Automatic generated (DON'T MODIFY) ===" > ${FILE_NAME_PUB_FOR_C}.pub
egrep -i "^uos_|^callback_" ${PROJECTS_FILE}.${EXT_MAP} |
awk '
{
	printf("#define\t%s\t\t\t0x%s\n", $1, $3);	
} ' >> ${FILE_NAME_PUB_FOR_C}.pub
echo "// End of Automatic generated (DON'T MODIFY) ===" >> ${FILE_NAME_PUB_FOR_C}.pub
# Fin: Extraction des variables, flags et subroutines prefixees par "UOS_" ou "uos_"

if [ -f ${PROJECTS_FILE}.${EXT_DEF} ]; then
	FILE_NAME_DEF_FOR_C=${PROJECTS_FILE}"_for_C"

	echo "Construction de '${FILE_NAME_DEF_FOR_C}.def' a partir de '${PROJECTS_FILE}.${EXT_DEF}'...."
	echo "// Automatic generated (DON'T MODIFY) ===" > ${FILE_NAME_DEF_FOR_C}.def
	cat ${PROJECTS_FILE}.${EXT_DEF} | grep ^#define >> ${FILE_NAME_DEF_FOR_C}.def
	echo "// End of Automatic generated (DON'T MODIFY) ===" >> ${FILE_NAME_DEF_FOR_C}.def
fi

# Build '.tag' file
FILE_NAME_TAG=${PROJECTS_FILE}.${EXT_TAG}

echo "Construction de '${FILE_NAME_TAG}' a partir de '${PROJECTS_FILE}.${EXT_MAP}'..."

echo "#ident \"@(#) micro-infos \$Id\$\"" > ${FILE_NAME_TAG}
echo >> ${FILE_NAME_TAG}
echo "# Generated automatically (don't modify)" >> ${FILE_NAME_TAG}
echo >> ${FILE_NAME_TAG}
echo "# List of labels and memory addresses" >> ${FILE_NAME_TAG}

./buildFileTag.sh ${PROJECTS_FILE}.${EXT_MAP} >> ${FILE_NAME_TAG}

echo >> ${FILE_NAME_TAG}
echo "# List of registers accessibles by lds/sts" >> ${FILE_NAME_TAG}

cat /etc/avrdisas.conf | grep "^Register" |
awk '{
	printf("%s\tM\t%s\n", $2, $3);
}' >> ${FILE_NAME_TAG}

echo >> ${FILE_NAME_TAG}
echo "# End of file" >> ${FILE_NAME_TAG}
echo >> ${FILE_NAME_TAG}
# End: Build '.tag' file

echo
ls -ltr ${PROJECTS_FILE}*.*

# Creation eventuelle de './Products'
test -d Products || mkdir Products

cp -p ${PROJECTS_FILE}.hex ${PROJECTS_FILE}.lst ${PROJECTS_FILE}.map Products
echo
echo "List of files under './Products'"
ls -ltr Products

echo
echo "Build successful of project [${PROJECTS_FILE}] :-)"
echo

echo "################## End of production of '${PROJECTS_FILE}' ##################"

done

exit 0
