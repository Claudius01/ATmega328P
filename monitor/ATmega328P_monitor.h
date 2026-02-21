; "$Id: ATmega328P_monitor.h,v 1.7 2026/02/18 17:31:06 administrateur Exp $"

#define	CHAR_NULL			0x00		; '\0'
#define	CHAR_LF				0x0A		; Line Feed ('\n')

#define	CHAR_SEPARATOR		0xFFFF	; Separateur section datas (0xffff opcode invalide ;-)

#define	CRC8_POLYNOMIAL	0x8C		; Masque pour le calcul du CR8-MAXIM

#define	IDX_BIT_BARGRAPH_0			IDX_BIT0
#define	IDX_BIT_BARGRAPH_1			IDX_BIT1
#define	IDX_BIT_BARGRAPH_2			IDX_BIT2
#define	IDX_BIT_BARGRAPH_3			IDX_BIT3

.dseg

; Adresse de debut des variables apres celle de uOS
G_SRAM_SPACE_OF_UOS:					.byte		(UOS_G_SRAM_BOOTLOADER_END_OF_USE - SRAM_START + 1)

; ---------
; Variables dediees l'espace PROGRAM
; => Suite des declarations a la suite de l'adresse en SRAM de 'G_SRAM_BOOTLOADER_END_OF_USE'
;    qui est la derniere adresse en SRAM du Micro OS
;
; ---------
G_CALC_CRC8:							.byte		1

G_BARGRAPH_COUNTER:					.byte		1
G_BARGRAPH_PASS_MSB:					.byte		1
G_BARGRAPH_PASS_LSB:					.byte		1
G_BARGRAPH_IMAGE:						.byte		1

; ---------
; Test des 2 instructions 'LAC - Load and Clear' et 'LAS - Load and Set"
; ---------
G_RESULT_LAC_LAS:						.byte		1

; Fin des variables propres au PROGRAM d'extension
G_SRAM_EXTENSION_END_OF_USE:		.byte		1		; Initialisee a 0xff pour reperage dans la SRAM
; ---------

; End of file

