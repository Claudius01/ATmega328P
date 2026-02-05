; "$Id: ATmega328P_uOS_Commands.asm,v 1.10 2026/02/04 16:21:42 administrateur Exp $"

#include "ATmega328P_uOS_Commands.h"

.cseg

; ---------
; Interpretation d'une commande "<X"
;
; Usage:
;		 rcall	_uos_interpret_command		; Lecture de la FIFO/Rx
;
; Registres utilises (sauvegarde/restaures):
;    REG_TEMP_R16 -> Caractere a convertir et a ajouter apres x10
;    REG_TEMP_R17 -> Working register
;    
; Warning: Pas de test du 'char' passe en argument dans la plage ['0,', '1', ..., '9']
; Remarque: Lecture de la FIFO/Rx jusqu'au vidage
;
; Retour ajoute a 'UOS_G_TEST_VALUE_MSB:UOS_G_TEST_VALUE_LSB' par decalage et sans raz
; => Raz a la charge de l'interpretation de la valeur
; ---------
_uos_interpret_command:
	nop

_uos_interpret_command_loop:
	cli
	rcall		_uos_uart_fifo_rx_read			; Lecture atomique
	sei

	brtc		_uos_interpret_command_rtn	; Nouvelle donnee disponible ?

	lds		REG_TEMP_R17, UOS_G_TEST_FLAGS

	; Oui. -> Caractere dans 'REG_R2'
	mov		REG_TEMP_R16, REG_R2
	cpi		REG_TEMP_R16, CHAR_COMMAND_REC
	brne		_uos_interpret_command_loop_more

	; Le prochain caractere sera le type de la commande
	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_TYPE_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R17
	rjmp		_uos_interpret_command_loop

_uos_interpret_command_loop_more:
	cpi		REG_TEMP_R16, CHAR_COMMAND_MORE
	brne		_uos_interpret_command_loop_more_2

	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_MORE_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R17
	rjmp		_uos_interpret_command_loop

_uos_interpret_command_loop_more_2:
	cpi		REG_TEMP_R16, CHAR_COMMAND_PLUS
	brne		_uos_interpret_command_loop_more_2A

	; Effacement de 'UOS_G_TEST_VALUES_ZONE' sur le 1st 'CHAR_COMMAND_PLUS
	sbrs		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		_uos_raz_value_into_zone

	; Ajout 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE' a 'UOS_G_TEST_VALUES_ZONE'
	; precedent 'CHAR_COMMAND_PLUS'
	sbrc		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		_uos_add_value_into_zone

	; Force maj 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE'
	sbr		REG_TEMP_R17, (FLG_TEST_COMMAND_MORE_MSK | FLG_TEST_COMMAND_PLUS_MSK)
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R17
	rjmp		_uos_interpret_command_loop

_uos_interpret_command_loop_more_2A:
	cpi		REG_TEMP_R16, CHAR_LF
	brne		_uos_interpret_command_loop_more_3

	; Ajout 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE' a 'UOS_G_TEST_VALUES_ZONE'
	sbrc		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		_uos_add_value_into_zone

	rcall		_uos_exec_command								; Execution de la commande

	; Lancement de l'emission
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	rjmp		_uos_interpret_command_rtn

_uos_interpret_command_loop_more_3:
	sbrs		REG_TEMP_R17, FLG_TEST_COMMAND_TYPE_IDX
	rjmp		_uos_interpret_command_loop_more_4

	sts		UOS_G_TEST_COMMAND_TYPE, REG_TEMP_R16	; Save command type

	; Raz des donnees de la commande a recevoir
	clr		REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_MSB, REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_LSB, REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_MSB_MORE, REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_LSB_MORE, REG_TEMP_R16

	lds		REG_TEMP_R16, UOS_G_TEST_VALUES_IDX_WRK
	sts		UOS_G_TEST_VALUES_IDX, REG_TEMP_R16

	; Effacement pour prendre la valeur qui suit avec eventuellement des donnees a suivre
	cbr		REG_TEMP_R17, (FLG_TEST_COMMAND_TYPE_MSK | FLG_TEST_COMMAND_MORE_MSK | FLG_TEST_COMMAND_PLUS_MSK)
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R17
	rjmp		_uos_interpret_command_loop

_uos_interpret_command_loop_more_4:
	rcall		_uos_char_to_hex_incremental		; Construction de 'UOS_G_TEST_VALUE_MSB:UOS_G_TEST_VALUE_LSB'
	rjmp		_uos_interpret_command_loop

_uos_interpret_command_rtn:
	ret
; ---------

; ---------
; - Echo de la commande avec ses parametres
; ---------
uos_print_command_ok:
	; Echo de la commande reconnue avec uniquement l'adresse
	; => ie. "[34>zA987-4321]"
	;
	lds		REG_TEMP_R17, UOS_G_TEST_FLAGS
	cbr		REG_TEMP_R17, FLG_TEST_COMMAND_ERROR_MSK

	ldi		REG_TEMP_R16, CHAR_COMMAND_SEND
	rjmp		uos_print_command

uos_print_command_ko:
	; Echo de la commande non reconnue avec ses parametres
	; => ie. "34?zA987-4321" si commande non reconnue
	;
	lds		REG_TEMP_R17, UOS_G_TEST_FLAGS
	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_ERROR_MSK

	ldi		REG_TEMP_R16, CHAR_COMMAND_UNKNOWN

uos_print_command:
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R17				; Maj Flag 'FLG_TEST_COMMAND_ERROR'

	rcall		uos_push_1_char_in_fifo_tx				; '>' eor '?'

	lds		REG_TEMP_R16, UOS_G_TEST_COMMAND_TYPE
	rcall		uos_push_1_char_in_fifo_tx

	; 1st argument sur 16 bits de la commande
	lds		REG_TEMP_R16, UOS_G_TEST_VALUE_MSB
	rcall		uos_convert_and_put_fifo_tx

	lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB
	rcall		uos_convert_and_put_fifo_tx
	; Fin: Echo de la commande avec uniquement l'adresse

	ldi		REG_Z_MSB, ((uos_text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((uos_text_hexa_value_lf_end << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	ret
; ---------

; ---------
; Execution de la commande recue
; ---------
_uos_exec_command:
	ldi		REG_TEMP_R16, '['
	rcall		uos_push_1_char_in_fifo_tx

	; Comptabilisation et print des executions
	lds		REG_TEMP_R16, G_NBR_VALUE_TRACE
	inc		REG_TEMP_R16
	sts		G_NBR_VALUE_TRACE, REG_TEMP_R16

	; Compteur d'execution commande sur 8 bits
	lds		REG_TEMP_R16, G_NBR_VALUE_TRACE
	rcall		uos_convert_and_put_fifo_tx

	; Fin: Comptabilisation et print des executions

	; Liste des commandes supportees
	lds		REG_TEMP_R16, UOS_G_TEST_COMMAND_TYPE

	cpi		REG_TEMP_R16, 'B'				; [B] (Set Bauds Rate)
	in			REG_TEMP_R17, SREG
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		_uos_exec_command_type_b_maj

	cpi		REG_TEMP_R16, 'p'				; [s] (Read from FLASH)
	in			REG_TEMP_R17, SREG
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		_uos_exec_command_type_p_read

	cpi		REG_TEMP_R16, 'P'				; [P] (Write into FLASH)
	in			REG_TEMP_R17, SREG
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		_uos_exec_command_type_p_write

	cpi		REG_TEMP_R16, 's'				; [s] (Read from SRAM)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		_uos_exec_command_type_s_min

	; Fin: Liste des commandes supportees

_uos_exec_command_unknown_here:
	; Commande non reconnue
	; => Execution de l'extension qui prendrait eventuellement en charge la commande !

	; ---------
	; Prolongement si le code est execute au RESET depuis l'espace PROGRAM et
	; si le vecteur commence par l'instruction 'rjmp'
	; ---------
	; Init a commande non reconnue ou pas d'execution de l'extension
	clt

	ldi		REG_Z_MSB, high(_uos_callback_command)	; Execution si possible de l'extension
	ldi		REG_Z_LSB, low(_uos_callback_command)	; dans l'espace PROGRAM
	call		_uos_exec_extension_into_program
	; ---------

	brts		_uos_exec_command_test_end	; Saut si commande reconnue dans l'espace PROGRAM

	rcall		uos_print_command_ko			; Commande NON reconnue dans les espaces BOOTLOADER et PROGRAM

_uos_exec_command_test_end:
	ret
; ---------

; ---------
; Execution de la commande 'p'
; => Dump de la memoire programme: "<pAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st word a lire
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;
; Reponse: "[NN>pAAAA-BBBB]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
_uos_exec_command_type_p_read:
	rcall		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	; Adresse sur des mots
	lsl		REG_X_LSB
	rol		REG_X_MSB

#if 0
	; Dump sur N x 16 bytes (N/2 x 8 words)
	lds		REG_TEMP_R17, UOS_G_TEST_VALUE_LSB_MORE
	tst		REG_TEMP_R17
	brne		_uos_exec_command_type_p_read_loop_0

	; Forcage 8 blocs si 'UOS_G_TEST_VALUE_LSB_MORE' est a 0
#endif

	ldi		REG_TEMP_R17, 8

_uos_exec_command_type_p_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	; Remarque: Division par 2 car dump de word ;-)
	push		REG_X_MSB
	push		REG_X_LSB

	lsr		REG_X_MSB
	ror		REG_X_LSB
	rcall		uos_print_2_bytes_hexa

	pop		REG_X_LSB
	pop		REG_X_MSB

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((uos_text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((uos_text_hexa_value << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

_uos_exec_command_type_p_read_loop_1:
	; Valeur de la memoire programme indexee par 'REG_X_MSB:REG_X_LSB'
	movw		REG_Z_LSB, REG_X_LSB
	adiw		REG_X_LSB, 1						; Preparation prochain byte

	lpm		REG_TEMP_R16, Z
	rcall		uos_convert_and_put_fifo_tx

	dec		REG_TEMP_R18
	brne		_uos_exec_command_type_p_read_loop_1

	ldi		REG_Z_MSB, ((uos_text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((uos_text_hexa_value_lf_end << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		_uos_exec_command_type_p_read_loop_0

	ret
; ---------

; ---------
; Execution de la commande 'P'
; => Ecriture d'une page dans la memoire programme: "<PAAAA-DDDD..." avec:
;    - 0xAAAA:    l'adresse du word a ecrire dans la memoire programme
;    - 0xDDDD...: les valeurs des mots a ecrire limite a 64 mots car
;                 ecriture d'une page de taille 'PAGESIZE'
;
; Usages:
;   - '_uos_exec_command_type_p_write': 'G_TEST_VALUE': Adresse de 1st opcode a ecrire
;     => Le traitement est poursuivi avec 'G_TEST_VALUE'
;		   => Si appele avec la commande "<D2", maj de 'G_TEST_VALUE'...
;
;     => La zone de copie des opcodes est a l'adresse 'UOS_G_TEST_VALUES_ZONE'
;		   => Si appele avec la commande "<D2", maj de 'UOS_G_TEST_VALUES_ZONE'...
;
;     => Affirmer 'FLG_2_ENABLE_DERIVATION' pour autoriser l'ecriture
;
; Warning: Cette adresse de 1st opcode a ecrire doit etre alignee sur une adresse 64 bytes
;
; Reponse: "[NN>PAAAA]" (adresse du mot a ecrire)
; ---------
_uos_exec_command_type_p_write:
	; Recuperation de l'adresse du 1st word a ecrire
	lds		REG_Z_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_Z_LSB, UOS_G_TEST_VALUE_LSB

	; Test de 'REG_Z_MSB:REG_Z_LSB' aligne sur des pages de 64 bytes
	mov		REG_TEMP_R16, REG_Z_LSB
	andi		REG_TEMP_R16, 0x1F						; TODO: Change 0x1F to 0x3F
	breq		_uos_exec_command_type_p_write_cont_d

	rjmp		_uos_exec_command_type_p_write_invalid_address
	; Fin: Test de 'REG_Z_MSB:REG_Z_LSB' aligne sur des pages de 64 bytes

_uos_exec_command_type_p_write_cont_d:
	; Test de 'REG_Z_MSB:REG_Z_LSB' dans la plage [end_of_program + 1, ..., (FLASHEND - 125)]
	; Test si autorisation d'ecriture avant l'adresse 'end_of_program' pour la derivation de code ;-)
	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	sbrc		REG_TEMP_R16, UOS_FLG_2_ENABLE_DERIVATION_IDX
	rjmp		_uos_exec_command_type_p_write_bypass

	ldi		REG_TEMP_R16, low(end_of_program + 1)
	ldi		REG_TEMP_R17, high(end_of_program + 1)
	cp			REG_Z_LSB, REG_TEMP_R16		
	cpc		REG_Z_MSB, REG_TEMP_R17		
	brmi		_uos_exec_command_type_p_write_out_of_range

_uos_exec_command_type_p_write_bypass:
	ldi		REG_TEMP_R16, low(FLASHEND + 2 - 128)		; Place pour une page de 64 mots
	ldi		REG_TEMP_R17, high(FLASHEND + 2 - 128)
	cp			REG_Z_LSB, REG_TEMP_R16		
	cpc		REG_Z_MSB, REG_TEMP_R17		
	brpl		_uos_exec_command_type_p_write_out_of_range		; 'X' >= (FLASHEND - 126) = 0x0fe1
	; Fin: Test de 'REG_Z_MSB:REG_Z_LSB' dans la plage [end_of_program + 1, ..., (FLASHEND - 125)]

	; TODO: Deplacer le retour Ok pour etre parfaitement synchrone des commandes/reponses ;-)
	rcall		uos_print_command_ok			; Commande reconnue

	; Attente du vidage de la FIFO/Tx avant de continuer
	rcall		uos_fifo_tx_to_send_sync
	; Fin: Attente du vidage de la FIFO/Tx avant de continuer

	; Sequence interruptible
	cli

	; Reprise de l'adresse du 1st word a ecrire
	lds		REG_Z_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_Z_LSB, UOS_G_TEST_VALUE_LSB

	; Adresse sur des mots
	lsl		REG_Z_LSB
	rol		REG_Z_MSB

	; Recopie des 64 mots de la SRAM
	ldi		REG_Y_MSB, high(UOS_G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(UOS_G_TEST_VALUES_ZONE)

	;-the routine writes one page of data from RAM to Flash
	; the first data location in RAM is pointed to by the Y pointer
	; the first data location in Flash is pointed to by the Z-pointer
	;-error handling is not included
	;-the routine must be placed inside the Boot space
	; (at least the Do_spm sub routine). Only code inside NRWW section can
	; be read during Self-Programming (Page Erase and Page Write).
	;-registers used: r0, r1, temp1 (r16), temp2 (r17), looplo (r24),
	; loophi (r25), spmcrval (r20)
	; storing and restoring of registers is not included in the routine
	; register usage can be optimized at the expense of code size
	;-It is assumed that either the interrupt table is moved to the Boot
	; loader section or that the interrupts are disabled.

;.equ   PAGESIZEB = PAGESIZE*2     ;PAGESIZEB is page size in BYTES, not words
;.org SMALLBOOTSTART

_uos_write_page:
	;Page Erase
	ldi		REG_TEMP_R20, (1<<PGERS) | (1<<SELFPRGEN)
	rcall		_uos_do_spm

	;re-enable the RWW section
	ldi		REG_TEMP_R20, (1<<RWWSRE) | (1<<SELFPRGEN)
	rcall		_uos_do_spm

	;transfer data from RAM to Flash page buffer
	ldi		REG_X_LSB, low(PAGESIZE_BYTES)     ;init loop variable
	ldi		REG_X_MSB, high(PAGESIZE_BYTES)    ;not required for PAGESIZE_BYTES<=256

_uos_write_page_loop:
	ld			r0, Y+
	ld			r1, Y+
	ldi		REG_TEMP_R20, (1<<SELFPRGEN)
	rcall		_uos_do_spm

	adiw		ZH:ZL, 2
	sbiw		REG_X_LSB, 2           ;use subi for PAGESIZE_BYTES<=256
	brne		_uos_write_page_loop

	;execute Page Write
	subi		ZL, low(PAGESIZE_BYTES)         ;restore pointer
	sbci		ZH, high(PAGESIZE_BYTES)        ;not required for PAGESIZE_BYTES<=256
	ldi		REG_TEMP_R20, (1<<PGWRT) | (1<<SELFPRGEN)
	rcall		_uos_do_spm

	;re-enable the RWW section
	ldi		REG_TEMP_R20, (1<<RWWSRE) | (1<<SELFPRGEN)
	rcall		_uos_do_spm

	;read back and check, optional
	ldi		REG_X_LSB, low(PAGESIZE_BYTES)     ;init loop variable
	ldi		REG_X_MSB, high(PAGESIZE_BYTES)    ;not required for PAGESIZE_BYTES<=256
	subi		YL, low(PAGESIZE_BYTES)         ;restore pointer
	sbci		YH, high(PAGESIZE_BYTES)

_uos_read_loop:
	lpm		r0, Z+
	ld			r1, Y+
	cpse		r0, r1
	rjmp		_uos_exec_command_type_p_write_error

	sbiw  	 REG_X_LSB, 1           ;use subi for PAGESIZE_BYTES<=256
	brne  	 _uos_read_loop
	;return to RWW section
	;verify that RWW section is safe to read

_uos_read_rtn:
	in			REG_TEMP_R16, SPMCSR
	sbrs		REG_TEMP_R16, RWWSB        ; If RWWSB is set, the RWW section is not ready yet
	ret

	;re-enable the RWW section
	ldi		REG_TEMP_R20, (1<<RWWSRE) | (1<<SELFPRGEN)
	rcall		_uos_do_spm
	rjmp		_uos_read_rtn

	; Remarque: Attention, ecriture de la FIFO/Tx dans une sequence interruptible
	;           => Blocage si remplissage de la FIFO/Tx a 50% qui ne pourra pas se vider ;-)
_uos_exec_command_type_p_write_invalid_address:
_uos_exec_command_type_p_write_out_of_range:
	sei										; Set interrupt flag @ remark

	rcall		uos_print_command_ko			; Commande non executee

_uos_exec_command_type_p_write_error:
	ldi      REG_Z_MSB, ((_uos_text_flash_error << 1) / 256)
	ldi      REG_Z_LSB, ((_uos_text_flash_error << 1) % 256)
	rcall    uos_push_text_in_fifo_tx

	movw		REG_X_LSB, REG_Z_LSB
	rcall		uos_print_2_bytes_hexa
	rcall    uos_print_line_feed

	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS
	sbr		REG_TEMP_R16, FLG_TEST_PROGRAMING_ERROR_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R16
	; End: Read back and check the programming

_uos_exec_command_type_p_write_end:
	sei
	; Fin: Sequence interruptible

	ret
; ---------

; ---------
; Execution de la commande 'B'
;
; Reprogrammation du Baud Rate
; - "<B0": 19200 bauds
; - "<B1":  9600 bauds
; - "<B2":  4800 bauds
; - "<B3":  2400 bauds
; - "<B4":  1200 bauds
; - "<B5":   600 bauds
; - "<B6":   300 bauds
; ---------
_uos_exec_command_type_b_maj:
	; Recuperation de l'index
	; Update EEPROM
	ldi		REG_X_MSB, (EEPROM_ADDR_BAUDS_IDX / 256)
	ldi		REG_X_LSB, (EEPROM_ADDR_BAUDS_IDX % 256)
	lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB
	rcall		uos_eeprom_write_byte
	; End: Update EEPROM

	clr		REG_X_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

_uos_set_bauds_rate:
	; Multiplication par 2 pour acceder a chaque doublets de la table 'const_for_bauds_rate'
	; => Pas de report dans 'REG_X_MSB' car 7 resultats dans la plage [0, 2, 4, 6, 8, 10 et 12]
	lsl		REG_X_LSB

	ldi		REG_Z_MSB, high(const_for_bauds_rate << 1)
	ldi		REG_Z_LSB, low(const_for_bauds_rate << 1)
	add		REG_Z_LSB, REG_X_LSB	
	adc		REG_Z_MSB, REG_X_MSB	

	; Adresse du dernier doublet cadree sur un mot
	ldi		REG_TEMP_R17, low((const_for_bauds_rate_end - 1) << 1)
	cp			REG_TEMP_R17, REG_Z_LSB
	ldi		REG_TEMP_R17, high((const_for_bauds_rate_end - 1) << 1)
	cpc		REG_TEMP_R17, REG_Z_MSB
	brmi		_uos_exec_command_type_b_maj_ko	; Z <= 'Adresse du dernier doublet' ?

_uos_exec_command_type_b_maj_ok:					; -> Yes (adresse de copie dans la plage ;-)
	; Ecriture atomique dans [UBRR0H:UBRR0L]
	cli
	lpm		REG_TEMP_R16, Z+				; LSB value
	lpm		REG_TEMP_R17, Z				; MSB value

	; Ajustement 8/16 MHz @ 'FLG_0_RC_OSC_8MHZ'
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrs		REG_TEMP_R23, FLG_0_RC_OSC_8MHZ_IDX

	rjmp		_uos_exec_command_type_b_maj_no_rc_osc_8mhz

	; Division par 2 de la valeur a configurer ;-)
	lsr		REG_TEMP_R17
	ror		REG_TEMP_R16

	; Fin: Ajustement 8/16 MHz @ 'FLG_0_RC_OSC_8MHZ'

_uos_exec_command_type_b_maj_no_rc_osc_8mhz:
	sts		UBRR0H, REG_TEMP_R17
	sts		UBRR0L, REG_TEMP_R16
	sei
	; Fin: Ecriture atomique dans [UBRR0H:UBRR0L]

	; Commande executee
	; => Pas d'appel a 'uos_print_command_ok' car changement de la vitesse en cours
	; => TODO: Allumage fugitif de la Led RED ?!..
	set
	ret

_uos_exec_command_type_b_maj_ko:				; Commande non executee (index trop grand)
	ret
; ---------

; ---------
read_and_set_bauds_rate_from_eeprom:
	; Lecture de l'index des Bauds
	ldi		REG_X_MSB, high(EEPROM_ADDR_BAUDS_IDX);
	ldi		REG_X_LSB, low(EEPROM_ADDR_BAUDS_IDX);
	rcall		uos_eeprom_read_byte

	; Maj de 'UBRR0H:UBRR0L' si dans la plage supportee
	clr		REG_X_MSB
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		_uos_set_bauds_rate

	ret
; ---------

; ---------
; Execution de la commande 's'
; => Dump de la SRAM: "<sAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st byte a lire (si 0xAAAA == 0x0000 => Debut en SRAM_START
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;      avec une limitation des adresses dans la plage [SRAM_START, ..., RAMEND]
;
; Reponse: "[NN>sAAAA-BBBB]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
_uos_exec_command_type_s_min:
	rcall		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	tst		REG_X_MSB
	brne		_uos_exec_command_type_s_read_cont_d
	tst		REG_X_LSB
	brne		_uos_exec_command_type_s_read_cont_d

	ldi		REG_X_MSB, (SRAM_START / 256)
	ldi		REG_X_LSB, (SRAM_START % 256)

	; Dump de toute la SRAM
	; TODO: Calcul @ 'SRAM_START' et 'RAMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		_uos_exec_command_type_s_read_loop_0

_uos_exec_command_type_s_read_cont_d:
	; Dump sur 8 x 16 bytes
	; TODO: Get 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

_uos_exec_command_type_s_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	rcall		uos_print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

_uos_exec_command_type_s_read_loop_1:
	; Valeur de la SRAM indexee par 'REG_X_MSB:REG_X_LSB'
	ld			REG_TEMP_R16, X+
	rcall		uos_convert_and_put_fifo_tx

	; Test limite 'RAMEND'
	; => On suppose qu'au depart 'X <= RAMEND'
	cpi		REG_X_MSB, ((RAMEND + 1) / 256)
	brne		_uos_exec_command_type_s_read_more2
	cpi		REG_X_LSB, ((RAMEND + 1) % 256)
	brne		_uos_exec_command_type_s_read_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

_uos_exec_command_type_s_read_more2:
	dec		REG_TEMP_R18
	brne		_uos_exec_command_type_s_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		_uos_exec_command_type_s_read_loop_0

	set													; Commande reconnue
	ret
; ---------

; ---------
; Conversion ASCII -> Hexa-16 bits
;
; Usage:
;		 rcall	_uos_char_to_hex_incremental	; 'REG_R2' in ['0,', '1', ..., '9', 'A', ..., 'F'
;
; Registres utilises (sauvegarde/restaures):
;    REG_TEMP_R16 -> Caractere a convertir et a ajouter apres x16
;    REG_TEMP_R17 -> Working register
;    
; Warning: Pas de test du 'char' passe en argument dans la plage ['0,', '1', ..., '9', 'A', ..., 'F']
;
; Retour ajoute a 'UOS_G_TEST_VALUE_MSB:UOS_G_TEST_VALUE_LSB'
; ---------
_uos_char_to_hex_incremental:
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	; Discrimination...
	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS
	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_MORE_IDX
	rjmp		_uos_char_to_hex_incremental_more

	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB			; Reprise valeur -> X
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	rjmp		_uos_char_to_hex_incremental_cont_d

_uos_char_to_hex_incremental_more:
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB_MORE		; Reprise valeur -> X
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB_MORE
	; Fin: Discrimination...

_uos_char_to_hex_incremental_cont_d:
	mov		REG_TEMP_R16, REG_R2				; Recuperation valeur a concatener

	; REG_TEMP_R17 = 4: 1st pass: X = 2X
	; REG_TEMP_R17 = 3: 2nd pass: X = 4X
	; REG_TEMP_R17 = 2: 3rd pass: X = 8X
	; REG_TEMP_R17 = 1: 4th pass: X = 16X => Fin

	ldi		REG_TEMP_R17, 4

_uos_char_to_hex_incremental_loop:
	lsl		REG_X_LSB				; X *= 2
	rol		REG_X_MSB
	dec		REG_TEMP_R17
	brne		_uos_char_to_hex_incremental_loop

	; Conversion ['0', ... , '9'] = [0x30, ... , 0x39] -> [0x0, ..., 0x9]
	;            ['A', ... , 'F'] = [0x41, ... , 0x46] -> [0xa, ..., 0xf]
	;            ['a', ... , 'f'] = [0x61, ... , 0x66] -> [0xa, ..., 0xf]
	;
	sbrc		REG_TEMP_R16, IDX_BIT6			; ['0', ... , '9'] ?
	rjmp		_uos_char_to_hex_incremental_a_f	; Non

_uos_char_to_hex_incremental_0_9:					; Oui
	subi		REG_TEMP_R16, '0'
	rjmp		_uos_char_to_hex_incremental_add

_uos_char_to_hex_incremental_a_f:
	cbr		REG_TEMP_R16, MSK_BIT5			; Lowercase -> Uppercase ('a' (0x61) -> 'A' (0x41))
	subi		REG_TEMP_R16, ('A' - 0xa)		; 'A' -> 0xa, ..., 'F' -> 0xf

_uos_char_to_hex_incremental_add:
	andi		REG_TEMP_R16, 0x0f				; Filtre Bits<3,0> (precaution ;-)
	or			REG_X_LSB, REG_TEMP_R16			; X |= REG_TEMP_R16

	; Discrimination...
	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS
	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_MORE_IDX
	rjmp		_uos_char_to_hex_incremental_more_2

	sts		UOS_G_TEST_VALUE_LSB, REG_X_LSB
	sts		UOS_G_TEST_VALUE_MSB, REG_X_MSB
	rjmp		_uos_char_to_hex_incremental_end

_uos_char_to_hex_incremental_more_2:
	sts		UOS_G_TEST_VALUE_LSB_MORE, REG_X_LSB
	sts		UOS_G_TEST_VALUE_MSB_MORE, REG_X_MSB
	; Fin: Discrimination...

_uos_char_to_hex_incremental_end:

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	ret
; ---------

; ---------
; Raz de 'UOS_G_TEST_VALUES_ZONE'
; ---------
_uos_raz_value_into_zone:
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	clr		REG_TEMP_R16
	sts		UOS_G_TEST_VALUES_IDX_WRK, REG_TEMP_R16

	ldi		REG_Y_MSB, high(UOS_G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(UOS_G_TEST_VALUES_ZONE)

	ldi		REG_TEMP_R16, 64
	clr		REG_TEMP_R17

_uos_raz_value_into_zone_loop:
	st			Y+, REG_TEMP_R17
	st			Y+, REG_TEMP_R17

	dec		REG_TEMP_R16
	brne		_uos_raz_value_into_zone_loop

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB

	ret
; ---------

; Recopie de 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE' a 'UOS_G_TEST_VALUES_ZONE'
; ---------
_uos_add_value_into_zone:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	lds		REG_TEMP_R16, UOS_G_TEST_VALUES_IDX_WRK
	ldi		REG_Y_MSB, high(UOS_G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(UOS_G_TEST_VALUES_ZONE)
	clr		REG_TEMP_R17
	add		REG_Y_LSB, REG_TEMP_R16
	adc		REG_Y_MSB, REG_TEMP_R17

	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB_MORE
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB_MORE

	std		Y+0, REG_X_LSB			; LSB en tete
	std		Y+1, REG_X_MSB

	inc		REG_TEMP_R16			; Next word
	inc		REG_TEMP_R16
	sts		UOS_G_TEST_VALUES_IDX_WRK, REG_TEMP_R16

	; Raz donnee
	clr		REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_MSB_MORE, REG_TEMP_R16
	sts		UOS_G_TEST_VALUE_LSB_MORE, REG_TEMP_R16

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB

	ret
; ---------

; ---------
; Lecture d'un byte de l'EEPROM a l'adresse 'REG_X_MSB:REG_X_LSB'
; => Valeur retournee dans 'REG_TEMP_R16'
; ---------
uos_eeprom_read_byte:
	; Set address
	out		EEARL, REG_X_LSB
	out		EEARH, REG_X_MSB

	; Lecture a l'adresse 'REG_X_MSB:REG_X_LSB'
_uos_eeprom_read_byte_wait:
	sbic		EECR, EEPE
	rjmp		_uos_eeprom_read_byte_wait

	sbi		EECR, EERE
	in			REG_TEMP_R16, EEDR
	; Fin: Lecture a l'adresse 'REG_X_MSB:REG_X_LSB'

	ret
; ---------

; ---------
_uos_do_spm:

	; Awaiting the previous SPM complete
_uos_wait_spm:
	in			REG_TEMP_R16, SPMCSR
	sbrc		REG_TEMP_R16, SELFPRGEN
	rjmp		_uos_wait_spm
	; End: Awaiting the previous SPM complete

	; Input: REG_TEMP_R20 determines SPM action
	;        => Disable interrupts if enabled, save status in 'REG_TEMP_R17'
	in			REG_TEMP_R17, SREG
	cli

_uos_wait_ee:
	sbic		EECR, EEPE
	rjmp		_uos_wait_ee

	; SPM timed sequence
	out		SPMCSR, REG_TEMP_R20
	spm

	; Restore SREG (to enable interrupts if originally enabled)
	out		SREG, REG_TEMP_R17	; Restore 'SREG' from 'REG_TEMP_R17'
	ret
; ---------

const_for_bauds_rate:
; Durees en uS d'un bit a 16 MHz sur UART/Tx et UART/Rx
; => Division par 2 pour 8 MHz dans le cas du RC Osc interne (cf. 'init_hard')
.dw	  52				; #0: 19200 bauds
.dw	 104				; #1:  9600 bauds
.dw	 208				; #2:  4800 bauds
.dw	 416				; #3:  2400 bauds
.dw	 832				; #4:  1200 bauds
.dw	1664				; #5:   600 bauds
.dw	3328				; #6:   300 bauds
const_for_bauds_rate_end:

text_hexa_value:
.db	"[0x", CHAR_NULL
   
text_hexa_value_lf_end:
.db	"]", CHAR_LF, CHAR_NULL, CHAR_NULL

; End of file
