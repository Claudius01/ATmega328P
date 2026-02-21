; "$Id: ATmega328P_uOS.h,v 1.17 2026/02/21 13:46:51 administrateur Exp $"

#define	USE_END_ADDRESS		0		; Retour en 'forever_2' a la derniere adresse de la flash
#define	USE_PRG_ALL_CODE		0		; Restriction du code pour un develeoppement progressif

#define	USE_TRACE_BUTTON				0
#define	USE_TRACE_BUTTON_ERROR		0

#define	USE_COMMAND_B_MAJ				1

#define	USE_MARK_IN_TIM1_COMPA		1

#define	PAGESIZE_BYTES			(2 * PAGESIZE)

; Presentation de la Led GREEN @ emplacement des vecteurs d'interruption
#define	CHENILLARD_PROGRAM		0x01	; 1 creneau de 125mS _/--\_______ toutes les 1 Sec (mode non connecte)
#define	CHENILLARD_BOOTLOADER	0x55	; 1 creneau de 125mS _/--\_______ toutes les 250mS (mode non connecte)
#define	CHENILLARD_UNKNOWN		0x0F	; 1 creneau de 500mS _/--\_______ toutes les 1 Sec (mode non connecte)
#define	CHENILLARD_CONNECTED		0xFE	; 1 creneau de 125mS -\__/------- toutes les 1 Sec (mode connecte)

#define	EEPROM_ADDR_VERSION		0
#define	EEPROM_ADDR_TYPE			8
#define	EEPROM_ADDR_ID				9
#define	EEPROM_ADDR_BAUDS_IDX	10
#define	EEPROM_ADDR_PRIMES		16		; Reserve @ gestion des capteurs DS18B20

#define	CHAR_NULL				0x00		; '\0'
#define	CHAR_TAB					0x09		; Tabulation ('\t')
#define	CHAR_LF					0x0A		; Line Feed ('\n')
#define	CHAR_CR					0x0D		; Carriage Return ('\r')
#define	CHAR_SPACE				0x20		; Space (' ')

#define	CHAR_SEPARATOR			0xFFFF	; Separateur section datas (0xffff opcode invalide ;-)

; Definition des masques de bits [0x00, 0x01, ..., 0xff] pour les opcodes suivants:
; - ori  -> Logical OR with Immediate
; - andi -> Logical AND with Immediate (Faire le complement a 1 ou (0xFF - MSK_BITX))
; - cbr  -> Clear Bits in Register (= andi avec constante complementee a (0xFF - K))
; - sbr  -> Set Bits in Register (= ori)
;
#define	MSK_BIT7				(1 << 7)
#define	MSK_BIT6				(1 << 6)
#define	MSK_BIT5				(1 << 5)
#define	MSK_BIT4				(1 << 4)
#define	MSK_BIT3				(1 << 3)
#define	MSK_BIT2				(1 << 2)
#define	MSK_BIT1				(1 << 1)
#define	MSK_BIT0				(1 << 0)

; Definition des index de bits [0, 1, ..., 7] pour les opcodes suivants:
; - bld       -> Bit Load from the T Flag in SREG to a Bit in Register
; - bst       -> Bit Store from Bit in Register to T Flag in SREG
; - cbi/sbi   -> Clear Bit in I/O Register / Set Bit in I/O Register
; - sbic/sbis -> Skip if Bit in I/O Register is Cleared / Skip if Bit in I/O Register is Set
; - sbrc/sbrs -> Skip if Bit in Register is Cleared / Skip if Bit in Register is Set
; - bclr/bset -> Bit Clear / Bit Set in SREG
; - brbc/brbs -> Branch if Bit in SREG is Cleared / Set
;
#define	IDX_BIT7				7
#define	IDX_BIT6				6
#define	IDX_BIT5				5
#define	IDX_BIT4				4
#define	IDX_BIT3				3
#define	IDX_BIT2				2
#define	IDX_BIT1				1
#define	IDX_BIT0				0

; Definitions @ l'espace d'execution (Bootloader eor Programme)
; Constat:
; - Si le fuse 'BOOTRST' est programme a 0 (Select reset vector)
;   => 'G_STATES_AT_RESET' est "vu" a 0x86
;      => Vecteur RESET dans l'espace BOOTLOADER
;      => Execution des autres vecteurs d'interruption dans l'espace PROGRAM
;         => Si sequence d'ecriture dans 'MCUCR' (bits 'IVCE' et 'IVSEL')
;            => 'G_STATES_AT_RESET' est "vu" a 0x60 apres raz de 'G_STATES_AT_RESET'
;               => Execution des autres vecteurs d'interruption dans l'espace PROGRAM
;
; - Si le fuse 'BOOTRST' est programme a 1 (unprogramming)
;   => 'G_STATES_AT_RESET' est "vu" a 0x0e
;      => Vecteur RESET dans l'espace PROGRAM
;      => Execution des autres vecteurs d'interruption dans l'espace PROGRAM
;
; Marquage de l'etat au reset @ BOOTRST
#define	FLG_STATE_AT_RESET_BOOTLOADER_MSK					MSK_BIT7
#define	FLG_STATE_AT_RESET_BOOTLOADER_IDX					IDX_BIT7

#define	FLG_STATE_AT_RESET_PROGRAM_MSK						MSK_BIT3
#define	FLG_STATE_AT_RESET_PROGRAM_IDX						IDX_BIT3

; Marquage de l'etat d'execution de l'It 'tim1_compa_isr'
#define	FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK			MSK_BIT6
#define	FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_IDX			IDX_BIT6

#define	FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK				MSK_BIT2
#define	FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_IDX				IDX_BIT2

; Marquage de l'etat d'execution de l'It 'usart_rx_complete_isr'
#define	FLG_STATE_AT_IT_UART_COMPLETE_BOOTLOADER_MSK		MSK_BIT5
#define	FLG_STATE_AT_IT_UART_COMPLETE_BOOTLOADER_IDX		IDX_BIT5

#define	FLG_STATE_AT_IT_UART_COMPLETE_PROGRAM_MSK			MSK_BIT1
#define	FLG_STATE_AT_IT_UART_COMPLETE_PROGRAM_IDX			IDX_BIT1

; Marquage de l'etat d'execution de l'It 'pcint2_isr'
#define	FLG_STATE_AT_IT_PCINT2_BOOTLOADER_MSK				MSK_BIT4
#define	FLG_STATE_AT_IT_PCINT2_BOOTLOADER_IDX				IDX_BIT4

#define	FLG_STATE_AT_IT_PCINT2_PROGRAM_MSK					MSK_BIT0
#define	FLG_STATE_AT_IT_PCINT2_PROGRAM_IDX					IDX_BIT0
; Fin: Definitions @ l'espace d'execution (Bootloader eor Programme)

; Flags generaux FLG_0 (masques et index)
#define	FLG_0_PERIODE_1MS_MSK				MSK_BIT0

#define	FLG_0_SPARE_1_MSK						MSK_BIT1
#define	FLG_0_SPARE_2_MSK						MSK_BIT2
#define	FLG_0_SPARE_3_MSK						MSK_BIT3
#define	FLG_0_UART_TX_TO_SEND_MSK			MSK_BIT4		; Donnees Data/Tx a emettre
#define	UOS_FLG_0_PRINT_SKIP_MSK			MSK_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_SPARE_6_MSK						MSK_BIT6

; Synthese du fusible 'LOW' (CKSEL3..0)
; - 1 pour CKSEL3..0 a 0010 (Oscillateur RC interne a 8 MHz)
; - 0 pour CKSEL3..0 programme differement (notamment oscillateur externe a 16 MHz)
#define	FLG_0_RC_OSC_8MHZ_MSK					MSK_BIT7

#define	FLG_0_PERIODE_1MS_IDX					IDX_BIT0
#define	FLG_0_SPARE_1_IDX							IDX_BIT1
#define	FLG_0_SPARE_2_IDX							IDX_BIT2
#define	FLG_0_SPARE_3_IDX							IDX_BIT3
#define	FLG_0_UART_TX_TO_SEND_IDX				IDX_BIT4		; Donnees Data/Tx a emettre
#define	UOS_FLG_0_PRINT_SKIP_IDX				IDX_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_SPARE_6_IDX							IDX_BIT6
#define	FLG_0_RC_OSC_8MHZ_IDX					IDX_BIT7

; Flags generaux FLG_1 (masques et index)
; Etats des FIFO/UART/Rx et Tx + Donnees Rx recues et Tx a emettre
#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		MSK_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_MSK			MSK_BIT1
#define	FLG_1_UART_RX_RECEIVE_MSK				MSK_BIT2		; Donnees Data/Rx recues
#define	FLG_1_SPARE_3_MSK							MSK_BIT3
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		MSK_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_MSK			MSK_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_MSK		MSK_BIT6
#define	UOS_FLG_1_LED_RED_ON_MSK				MSK_BIT7

#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX		IDX_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_IDX			IDX_BIT1
#define	FLG_1_UART_RX_RECEIVE_IDX				IDX_BIT2		; Donnees Data/Rx recues
#define	FLG_1_SPARE_3_IDX							IDX_BIT3	
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX		IDX_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_IDX			IDX_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_IDX		IDX_BIT6
#define	UOS_FLG_1_LED_RED_ON_IDX				IDX_BIT7

; Flags generaux G_FLAGS_2 (masques et index)
#define	FLG_2_CONNECTED_MSK						MSK_BIT0		; Passage en mode connecte sur reception d'une donnee Rx
#define	FLG_2_BLINKING_LED_RED_MSK				MSK_BIT1
#define	FLG_2_BLINKING_LED_YELLOW_MSK			MSK_BIT2
#define	FLG_2_SPARE_3_MSK							MSK_BIT3
#define	FLG_2_SPARE_4_MSK							MSK_BIT4
#define	FLG_2_SPARE_5_MSK							MSK_BIT5
#define	FLG_2_SPARE_6_MSK							MSK_BIT6
#define	UOS_FLG_2_ENABLE_DERIVATION_MSK		MSK_BIT7		; Autorisation d'ecriture dans le programme

#define	FLG_2_CONNECTED_IDX						IDX_BIT0		; Passage en mode connecte sur reception d'une donnee Rx
#define	FLG_2_BLINKING_LED_RED_IDX				IDX_BIT1
#define	FLG_2_BLINKING_LED_YELLOW_IDX			IDX_BIT2
#define	FLG_2_SPARE_3_IDX							IDX_BIT3
#define	FLG_2_SPARE_4_IDX							IDX_BIT4
#define	FLG_2_SPARE_5_IDX							IDX_BIT5
#define	FLG_2_SPARE_6_IDX							IDX_BIT6
#define	UOS_FLG_2_ENABLE_DERIVATION_IDX		IDX_BIT7		; Autorisation d'ecriture dans le programme

.def		REG_SAVE_SREG		= r0		; Sauvegarde temporaire de SREG dans les methodes ISR

;.def		REG_R0				= r0		; Warning: Used by program C
;.def		REG_R1				= r1		; Warning: Used by program C
.def		REG_R2				= r2
.def		REG_R3				= r3
.def		REG_R4				= r4
.def		REG_R5				= r4
.def		REG_R6				= r6
.def		REG_R7				= r7
.def		REG_R8				= r8
.def		REG_R9				= r9
.def		REG_R10				= r10
.def		REG_R11				= r11
.def		REG_R12				= r12
.def		REG_R13				= r13
.def		REG_R14				= r14
.def		REG_R15				= r15

; Registres de travail temporaires (dedies et banalises)
.def		REG_TEMP_R16		= r16
.def		REG_TEMP_R17		= r17
.def		REG_TEMP_R18		= r18
.def		REG_TEMP_R19		= r19
.def		REG_TEMP_R20		= r20
.def		REG_TEMP_R21		= r21
.def		REG_TEMP_R22		= r22
.def		REG_TEMP_R23		= r23		; Registre de travail en remplacement de 'REG_PORTB_OUT', 'REG_FLAGS_0' et 'REG_FLAGS_1'
.def		REG_TEMP_R24		= r24		; Warning: Used by program C
.def		REG_TEMP_R25		= r25		; Warning: Used by program C
.def		REG_X_LSB			= r26		; XL
.def		REG_X_MSB			= r27		; XH
.def		REG_Y_LSB			= r28		; YL
.def		REG_Y_MSB			= r29		; YH
.def		REG_Z_LSB			= r30		; ZL
.def		REG_Z_MSB			= r31		; ZH

.dseg

; Zones de travail en SRAM
; Debut de la partie [0x100...] de la SRAM (possibilite d'optimisation des indexations par X, Y et Z )
#define	UOS_FLG_WRONG_IT_BOOLOADER_MSK		MSK_BIT7
#define	UOS_FLG_WRONG_IT_PROGRAM_MSK			MSK_BIT6

; Variables dediees au BOOTLOADER
; ---------
; Reservation pour la section '.bss' des programmes C et C++ avec par exemple
; => Adresses SRAM [0x100...0x4FF] (4 * 256 bytes)
;    Cette zone de [0x100...0x4FF] n'est pas initialisee par l'uOS
;    => Permet de connaitre son contenu au moyen de 'ATmega328P_monitor' ;-)
G_BSS_SPARE:					.byte		(4 * 256)	; 1st adresse de la SRAM + reservation de 4 * 256 = 1280 bytes

G_STATES_AT_RESET:			.byte		1		; Etats au reset @ au fusible BOOTRST a l'adresse 0x600
UOS_G_STATES_POST_MORTEM:	.byte		1		; Byte indiquant des etats pour l'analyse post mortem

G_TICK_1MS:						.byte		1		; Compatbilisation des mS a partir du tick de 100uS
G_TICK_1MS_INIT:				.byte		1

G_COUNTER_1MS_MSB:			.byte		1		; Compatbilisation des mS a concurence de 1 Sec
G_COUNTER_1MS_LSB:			.byte		1		; pour la synchronisation timer d'erreur

G_COUNTER_CHENILLARD:		.byte		1		; Compteur de progression du chenillard

G_CHENILLARD_MSB:				.byte		1		; Chenillard d'allumage/extinction Led GREEN
G_CHENILLARD_LSB:				.byte		1		; au travers d'un mot de 16 bits (16 x 125mS = 2 Sec)

G_NBR_VALUE_TRACE:			.byte		1
G_NBR_ERRORS:					.byte		1

UOS_G_HEADER_TYPE_PLATINE:		.byte		1	; Type de la platine lu de l'EEPROM
UOS_G_HEADER_INDEX_PLATINE:	.byte		1	; Index de la platine lu de l'EEPROM
UOS_G_HEADER_BAUDS_VALUE:		.byte		1	; Valeur de la vitesse lue de l'EEPROM [0, 1, ...]

; Erreur maj depuis l'exterieur de 'uOS' (ie. Language C)
#define	FLG_TEST_ERR_EXTERNAL_MSK				MSK_BIT7
#define	FLG_TEST_ERR_EXTERNAL_IDX				IDX_BIT7

G_TEST_ERROR:					.byte		1
; Fin: Definition des erreurs permanentes necessitant un effacement avec le Bouton #2 (appui "court")

; ---------
; Fin: Variables dediees au BOOTLOADER

UOS_G_PORTB_IMAGE:			.byte		1

UOS_G_FLAGS_0:					.byte		1
UOS_G_FLAGS_1:					.byte		1
UOS_G_FLAGS_2:					.byte		1

#define DURATION_TIMER_TEST_LEDS		500

#define FLG_GESTION_TEST_LEDS_MSK	MSK_BIT7
#define FLG_GESTION_TEST_LEDS_IDX	IDX_BIT7

UOS_G_GESTION_TEST_LEDS:	.byte    1

; Variables dediees aux extensions (espace programme)
#define	UOS_FLG_EXTENSIONS_INIT_MSK					MSK_BIT7		; Contexte initialise (Variable, traitements specifiques, ...)
#define	UOS_FLG_EXTENSIONS_EXEC_BACKGROUND_MSK		MSK_BIT3		; Passage dans 'callback_background'
#define	UOS_FLG_EXTENSIONS_EXEC_TICK_MSK				MSK_BIT2		; Passage dans 'callback_tick'
#define	UOS_FLG_EXTENSIONS_EXEC_1_MS_MSK				MSK_BIT1		; Passage dans 'callback_1_ms'
#define	UOS_FLG_EXTENSIONS_EXEC_COMMAND_MSK			MSK_BIT0		; Passage dans 'callback_command'

#define	UOS_FLG_EXTENSIONS_INIT_IDX					IDX_BIT7		; Contexte initialise (Variable, traitements specifiques, ...)
#define	UOS_FLG_EXTENSIONS_EXEC_BACKGROUND_IDX		IDX_BIT3		; Passage dans 'callback_background'
#define	UOS_FLG_EXTENSIONS_EXEC_TICK_IDX				IDX_BIT2		; Passage dans 'callback_tick'
#define	UOS_FLG_EXTENSIONS_EXEC_1_MS_IDX				IDX_BIT1		; Passage dans 'callback_1_ms'
#define	UOS_FLG_EXTENSIONS_EXEC_COMMAND_IDX			IDX_BIT0		; Passage dans 'callback_command'

UOS_G_SAVE_R0:								.byte		1
UOS_G_SAVE_R1:								.byte		1
UOS_G_SAVE_R2:								.byte		1
UOS_G_SAVE_R3:								.byte		1
UOS_G_SAVE_R4:								.byte		1
UOS_G_SAVE_R5:								.byte		1
UOS_G_SAVE_R6:								.byte		1
UOS_G_SAVE_R7:								.byte		1
UOS_G_SAVE_R8:								.byte		1
UOS_G_SAVE_R9:								.byte		1
UOS_G_SAVE_R10:							.byte		1
UOS_G_SAVE_R11:							.byte		1
UOS_G_SAVE_R12:							.byte		1
UOS_G_SAVE_R13:							.byte		1
UOS_G_SAVE_R14:							.byte		1
UOS_G_SAVE_R15:							.byte		1
UOS_G_SAVE_R16:							.byte		1
UOS_G_SAVE_R17:							.byte		1
UOS_G_SAVE_R18:							.byte		1
UOS_G_SAVE_R19:							.byte		1
UOS_G_SAVE_R20:							.byte		1
UOS_G_SAVE_R21:							.byte		1
UOS_G_SAVE_R22:							.byte		1
UOS_G_SAVE_R23:							.byte		1
UOS_G_SAVE_R24:							.byte		1
UOS_G_SAVE_R25:							.byte		1
UOS_G_SAVE_R26:							.byte		1
UOS_G_SAVE_R27:							.byte		1
UOS_G_SAVE_R28:							.byte		1
UOS_G_SAVE_R29:							.byte		1
UOS_G_SAVE_R30:							.byte		1
UOS_G_SAVE_R31:							.byte		1

UOS_G_FLAGS_EXTENSIONS:					.byte		1				; Progression de l'execution des extensions
; ---------

; Fin: Zones de travail en SRAM

; Definitions pour le pilotage avec ori/and/cbr/sbr
; - PORTB<0>: Non utilise (Reserve pour la sortie CLKOUT @ fusible 'LOW')
; - PORTB<1>: Led RED				0/1: Eteinte/Allumee
; - PORTB<2>: Led GREEN				0/1: Eteinte/Allumee
; - PORTB<3>: Pulse IT				0: IT in progress 1: IT not in progress
; - PORTB<4>: Led BUE				0/1: Eteinte/Allumee
; - PORTB<5>: Led YELLOW			0/1: Eteinte/Allumee

#define	MSK_BIT_PULSE_IT			MSK_BIT3

#define	UOS_MSK_BIT_LED_RED		MSK_BIT1
#define	UOS_MSK_BIT_LED_GREEN	MSK_BIT2
#define	UOS_MSK_BIT_LED_BLUE		MSK_BIT4
#define	UOS_MSK_BIT_LED_YELLOW	MSK_BIT5

#define	IDX_BIT_PULSE_IT			IDX_BIT3

#define	UOS_IDX_BIT_LED_RED		IDX_BIT1
#define	UOS_IDX_BIT_LED_GREEN	IDX_BIT2
#define	UOS_IDX_BIT_LED_BLUE		IDX_BIT4
#define	UOS_IDX_BIT_LED_YELLOW	IDX_BIT5

; --------
; Macros de pilotage du PORTB en sortie 
.macro setLedsOff				; 0/1: On/Off
	ldi		REG_TEMP_R23, (UOS_MSK_BIT_LED_RED | UOS_MSK_BIT_LED_GREEN | UOS_MSK_BIT_LED_YELLOW | UOS_MSK_BIT_LED_BLUE)
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedRedOff			; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, UOS_FLG_1_LED_RED_ON_MSK	; Led RED eteinte (Pulse --\_/--- possible)
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedRedOn			; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, UOS_FLG_1_LED_RED_ON_MSK	; Led RED allumee (Pulse --\_/--- inhibee)
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedYellowOff		; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedYellowOn		; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedGreenOff		; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_GREEN	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedGreenOn			; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_GREEN
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedBlueOn			; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_BLUE
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setLedBlueOff			; 0/1: On/Off
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_BLUE	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setPulseItUp			; Sortie au niveau haut de la pulse It
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, MSK_BIT_PULSE_IT	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm

.macro setPulseItDown		; Sortie au niveau bas de la pulse It
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, MSK_BIT_PULSE_IT	
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB
.endm
; Fin: Macros de pilotage du PORTB en sortie

; End of file
