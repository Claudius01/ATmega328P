#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProject4Simu.sh,v 1.3 2026/02/25 13:31:32 administrateur Exp $"

# Script de production d'un projet passe en argument
# Exemples:
#   $ ./goGenerate.sh ATmega328P_uOS_P1                       -> Production du Micro OS
#   $ ./goGenerate.sh ATmega328P_monitor_P1                   -> Production de l'extension "Moniteur" s'appuyant sur Micro OS
#   $ ./goGenerate.sh ATmega328P_uOS_P1 ATmega328P_monitor_P1 -> Production multiple

# Remarque: L'ordre de la production doit dependre des dependances (ie. 'ATmega328P_uOS_P1' avant 'ATmega328P_monitor_P1')

# Abandon des programmes "addons" au profit de programmes "autonomes" s'appuyant ou non sur le Micro OS
# avec l'inclusion du fichier 'ATmega328P_uOS_P1.pub' genere automatiquement ;-))

# TODO: Tester les inclusions des fichiers qui doivent etre coherentes...
# $ 2>/dev/null grep ATmega328P_uOS_P ATmega328P_uOS_P2* ATmega328P_monitor_P3* | grep include | cut -d'"' -f2 | cut -d'.' -f1
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2
# ATmega328P_uOS_P2

# $ 2>/dev/null grep ATmega328P_monitor ATmega328P_uOS_P2* ATmega328P_monitor_P3* | grep include | cut -d'"' -f2 | cut -d'.' -f1
# ATmega328P_monitor_P3
# ATmega328P_monitor_P3

# => Il ne doit y avoir d'autres patterns que ceux passer en argument de la commande
#    => Ici: $ ./goGenerateProject.sh ATmega328P_uOS_P2 ATmega328P_monitor_P3

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
	echo "  - $0 ATmega328P"
	exit 2
elif [ "${1}" == "clean" ]; then
        echo "Clean project..."

        BASE_PROJECT=`basename $PWD`
        echo "Remove files produced from [${BASE_PROJECT}]..."

        rm -f *.hex *.obj *.map *.lst *.tag *.pub *.eep.hex *_for_C.def *.opcodes *.disa

        exit 0
else
	echo "List of project produced:"
	echo $*
fi

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
EXT_OPCODES="opcodes"
EXT_DISA="disa"
EXT_DECODE="decode"
EXT_DECODE_HEX="decode.hex"
EXT_DECODE_MAP="decode.map"
EXT_TAG="tag"

rm -f ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_MAP} ${PROJECTS_FILE}.${EXT_PUB} ${PROJECTS_FILE}.${EXT_OBJ} ${PROJECTS_FILE}.${EXT_HEX} ${PROJECTS_FILE}.${EXT_OPCODES} ${PROJECTS_FILE}.${EXT_DISA} ${PROJECTS_FILE}.${EXT_DECODE} ${PROJECTS_FILE}.${EXT_DECODE_MAP} 

echo
echo "################## Production of '${PROJECTS_FILE}' ##################"

# Warning: USE_AVRSIMU=0 pour la cible et USE_AVRSIMU=1 pour la simulation
${AVRA_BIN} -D USE_AVRSIMU=1 -I ${PROJECTS} -I ${AVRA_INC} -m ${PROJECTS_FILE}.${EXT_MAP} -l ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_ASM}

if [ ! -f ${PROJECTS_FILE}.${EXT_LST} ]; then
	echo "Error: No build ;-("	
	exit 1
fi

echo "Generation du fichier de televersement '${PROJECTS_FILE}.opcodes' pour 'avrprog-flash"
./extractOpcodes.sh ${PROJECTS_FILE}

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

# Desassemblage...
avrdisas ${PROJECTS_FILE}

echo
ls -ltr ${PROJECTS_FILE}*.*

# Creation eventuelle de './Products4Simu'
test -d Products4Simu || mkdir Products4Simu

cp -p ${PROJECTS_FILE}.hex ${PROJECTS_FILE}.lst ${PROJECTS_FILE}.map ${PROJECTS_FILE}.disa Products4Simu 
echo
echo "List of files under './Products4Simu'"
ls -ltr Products4Simu

echo
echo "Build successful of project [${PROJECTS_FILE}] :-)"
echo

echo "################## End of production of '${PROJECTS_FILE}' ##################"

done

exit 0
