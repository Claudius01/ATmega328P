; "$Id: ATmega328P_monitor.asm,v 1.19 2026/02/18 18:01:31 administrateur Exp $"

; 2024/06/01 - Add description...
; 2024/06/07 - Test sections for CRC8-MAXIM calculataion...
; 2024/09/05 - Ajout de la commande "<i" pour dumper la SRAM [0x00, ..., 0xFF]
; 2024/11/03 - Ajout de la commande "<thhhl-HhHl" pour tester la sequence:
;                 ldi   r18, hl
;                 ldi   r20, hh
;                 ldi   r19, Hl
;                 ldi   r21, Hh
;                 cp    r18, r20
;                 -> Print SREG
;                 cpc   r19, r21
;                 -> Print SREG
;
;              => Peut etre completee/modifiee pour valider @ a la vrai vie ;-)
; 2024/11/04 - Deplacement de 'uos_puts' dans 'ATmega328P_monitor_P8.pub' avec un
;              un forcage de l'emission (cf. affirmation de 'FLG_1_UART_FIFO_TX_TO_SEND_MSK')
;
; 2025/09/23 - Accueil de la commande "<I" pour une ecriture dans un registre I/O
;
; 2026/01/19 - Reprise du projet 'ATmega328P_monitor_P8A'

.include		"m328Pdef.inc"				; Labels and identifiers for ATmega328p
.include		"ATmega328P_uOS.def"		; Definitions propres a 'ATmega328P_uOS'
.include		"ATmega328P_monitor.h"	; Definitions propres a 'ATmega328P_monitor'

#define USE_TRACE_BUTTON					1
#define USE_PRINT_BARGRAPH_COUNTER		0
#define USE_TEST_LAC_LAS					1

.cseg

.org	0x0000 

; ---------
; Vecteurs d'interruptions
; ---------
	; Code a telecharger en 0x0000 en remplacement de celui existant
	; => Marquage du numero de l'It en hexadecimal pour faciliter
	;    la lecture de 'UOS_G_STATES_POST_MORTEM'
	;    => Origine: 'FLG_WRONG_IT_PROGRAM' (Bit<7>)
	;       Num It:  Bits<0-5>
	;
	jmp		uos_main_program					; # 1 RESET (Mandatory)

	ldi		REG_TEMP_R17, 0x02
	rjmp		monitor_invalid_it_near			; # 2 INT0

	ldi		REG_TEMP_R17, 0x03
	rjmp		monitor_invalid_it_near			; # 3 INT1

	ldi		REG_TEMP_R17, 0x04
	rjmp		monitor_invalid_it_near			; # 4 PCINT0

	ldi		REG_TEMP_R17, 0x05
	rjmp		monitor_invalid_it_near			; # 5 PCINT1

	jmp		uos_pcint2_isr_program			; # 6 PCINT2 (Mandatory)

	ldi		REG_TEMP_R17, 0x07
	rjmp		monitor_invalid_it_near			; # 7 WDT

	ldi		REG_TEMP_R17, 0x08
	rjmp		monitor_invalid_it_near			; # 8 TIMER2 COMPA

	ldi		REG_TEMP_R17, 0x09
	rjmp		monitor_invalid_it_near			; # 9 TIMER2 COMPB

	ldi		REG_TEMP_R17, 0x10
	rjmp		monitor_invalid_it_near			; #10 TIMER2 OVF

	ldi		REG_TEMP_R17, 0x11
	rjmp		monitor_invalid_it_near			; #11 TIMER1 CAPT

	jmp		uos_tim1_compa_isr_program		; #12 TIMER1 COMPA (Mandatory)

	ldi		REG_TEMP_R17, 0x13
	rjmp		monitor_invalid_it_near			; #13 TIMER1 COMPB

	ldi		REG_TEMP_R17, 0x14
	rjmp		monitor_invalid_it_near			; #14 TIMER1 OVF

	ldi		REG_TEMP_R17, 0x15
	rjmp		monitor_invalid_it_near			; #15 TIMER0 COMPA

	ldi		REG_TEMP_R17, 0x16
	rjmp		monitor_invalid_it_near			; #16 TIMER0 COMPB

	ldi		REG_TEMP_R17, 0x17
	rjmp		monitor_invalid_it_near			; #17 TIMER0 OVF

	ldi		REG_TEMP_R17, 0x18
	rjmp		monitor_invalid_it_near			; #18 SPI, SPC

	jmp		uos_usart_rx_complete_isr_program	; #19 USART, RX (Mandatory)

	ldi		REG_TEMP_R17, 0x20
	rjmp		monitor_invalid_it_near			; #20 USART, UDRE

	ldi		REG_TEMP_R17, 0x21
	rjmp		monitor_invalid_it_near			; #21 USART, TX

	ldi		REG_TEMP_R17, 0x22
	rjmp		monitor_invalid_it_near			; #22 ADC

	ldi		REG_TEMP_R17, 0x23
	rjmp		monitor_invalid_it_near			; #23 EE READY

	ldi		REG_TEMP_R17, 0x24
	rjmp		monitor_invalid_it_near			; #24 ANALOG COMP

	ldi		REG_TEMP_R17, 0x25
	rjmp		monitor_invalid_it_near			; #25 TWI

	ldi		REG_TEMP_R17, 0x26
	rjmp		monitor_invalid_it_near			; #26 SPM READY

; Reservation 2 bytes pour s'aligner sur le 'main' du Langage C
; => TODO: Saut vers '_uos_forever'
	nop
	rjmp		monitor_invalid_it_near			; Ne sera jamais execute (adresse du 'main()' d'un programme C)

; ---------
; Table des vecteurs d'execution des taches timer codees dans l'espace PROGRAM
; en "prolongement" des executions depuis l'espace BOOTLOADER
; => Cf. '_uos_vector_timer_0_bootloader'
; ---------
	; 9 Timers destines au MONITOR (pas de prolongement defini)
	; => Car pas d'opcode "jmp xxx"
	nop				; Prolongement de l'execution du Timer #0
	nop
	nop				; Prolongement de l'execution du Timer #1
	nop
	nop				; Prolongement de l'execution du Timer #2
	nop
	nop				; Prolongement de l'execution du Timer #3
	nop
	nop				; Prolongement de l'execution du Timer #4
	nop
	nop				; Prolongement de l'execution du Timer #5
	nop
	nop				; Prolongement de l'execution du Timer #6
	nop
	nop				; Prolongement de l'execution du Timer #7
	nop
	nop				; Prolongement de l'execution du Timer #8
	nop

	; 7 Timers utilises par uOS (pas de prolongement defini)
	; => Car pas d'opcode "jmp xxx"
	nop				; Prolongement de l'execution du Timer #9
	nop
	nop				; Prolongement de l'execution du Timer #10
	nop
	nop				; Prolongement de l'execution du Timer #11
	nop
	nop				; Prolongement de l'execution du Timer #12
	nop
	nop				; Prolongement de l'execution du Timer #13
	nop
	nop				; Prolongement de l'execution du Timer #14
	nop
	nop				; Prolongement de l'execution du Timer #15
	nop

; ---------
; Table de 6 vecteurs d'execution en prolongement de celui de l'espace BOOTLOADER
; => Terminaison de la 1st page de 64 mots pour la programmation interne au moyen
;    l'instruction 'stm'
; => Remarque: Pas de prolongement lorsque pas d'opcode "rjmp xxx"
; => Les 6 methodes sont interruptibles sauf inhibition ponctuelle...
; ---------
	jmp		callback_init		; Prolongement de l'execution de l'initialisation

	nop								; Prolongement de l'execution en fond de tache (pas de prolongement)
	nop

	nop								; Prolongement de l'execution du tick de cadencement (pas de prolongement)
	nop

	jmp		callback_1_ms				; Prolongement de l'execution toutes les 1mS

	jmp		callback_gest_buttons	; Prolongement de la gestion des boutons (pas de prolongement)
				 								; => appropriation possible car appele AVANT traitement BOOTLOADER ;-)

	jmp		callback_command			; Prolongement de l'interpreteur de commande non prise en compte dans l'espace BOOTLOADER

monitor_invalid_it_near:
	jmp		monitor_invalid_it

; Exexution a une adresse "haute" et proche de uOS pour laisser le maximum
; de place au programme C qui sera telecharge en "bas" de la flash
.org	0x1000 

; ---------
; Code d'extension en prologement de celui execute dans l'espace BOOTLOADER
; => Doit imperativement se terminer par un 'ret'
;
; Warning: Imperatif en attendant le prolongement de l'initialisation de la SRAM
;          apres l'appel de '_uos_init_sram_fill' ;-)
;
; Add initialisations materielles propres au Monitor
; ---------
callback_init:
	; Initialisations propres au moniteur (Inhibition des Its)
	cli

	lds		REG_TEMP_R16, UOS_G_FLAGS_EXTENSIONS
	sbr		REG_TEMP_R16, UOS_FLG_EXTENSIONS_INIT_MSK		; Initialisation effectuee
	sts		UOS_G_FLAGS_EXTENSIONS, REG_TEMP_R16

	; Raz des variables propres aux extensions
	; => RAZ qui ne doit pas etre fait au RESET
	rcall		monitor_init_sram_fill

	; Add initialisations materielles propres au Monitor
	; - 4 led du bargraphe sur PORTC<3:0>
	ldi		REG_TEMP_R16, (1 << IDX_BIT_BARGRAPH_0) | (1 << IDX_BIT_BARGRAPH_1) | (1 << IDX_BIT_BARGRAPH_2) | (1 << IDX_BIT_BARGRAPH_3)
	out		DDRC, REG_TEMP_R16

	; Extinction des 4 premieres Leds du bargraphe
	ldi		REG_TEMP_R16, 0x0F
	out		PORTC, REG_TEMP_R16

	clr		REG_TEMP_R16
	sts		G_BARGRAPH_PASS_MSB, REG_TEMP_R16
	sts		G_BARGRAPH_PASS_LSB, REG_TEMP_R16

	ldi		REG_TEMP_R16, 0x0F
	sts		G_BARGRAPH_IMAGE, REG_TEMP_R16
	; Fin: Add initialisations materielles propres au Monitor

	sei
	; Fin: Initialisations propres au moniteur (Inhibition des Its)

	; Print du passage dans l'initialisation 'text_monitor_init'
	ldi		REG_Z_MSB, high(text_monitor_init << 1)
	ldi		REG_Z_LSB, low(text_monitor_init << 1)
	call		uos_push_text_in_fifo_tx

	; TODO: Si pas d'appel a 'uos_fifo_tx_to_send_sync'
	;       => Emission differe suite a d'autres ecriture dans le FIFO/Tx ?!..
	call		uos_fifo_tx_to_send_sync

;callback_init_end:
	ret
; ---------

callback_1_ms:
	; Test de clignotement sur le bargraphe
	lds		REG_X_MSB, G_BARGRAPH_PASS_MSB
	lds		REG_X_LSB, G_BARGRAPH_PASS_LSB
	adiw		REG_X_LSB, 1
	sts		G_BARGRAPH_PASS_MSB, REG_X_MSB
	sts		G_BARGRAPH_PASS_LSB, REG_X_LSB

	; Clignotement a 1Hz
	cpi		REG_X_MSB, (1000 / 256)
	brne		callback_1_ms_end

	cpi		REG_X_LSB, (1000 % 256)
	brne		callback_1_ms_end

	clr		REG_TEMP_R16
	sts		G_BARGRAPH_PASS_MSB, REG_TEMP_R16
	sts		G_BARGRAPH_PASS_LSB, REG_TEMP_R16

	; Methode sans image (generation par 'avr-gcc')
	in		r16, 0x08		; Read PORTC
	ldi	r17, 0x04 		; 3rd Led
	eor	r16, r17			; Clignotement
	out	0x08, r16		; Write PORTC
	; Fin: Test de clignotement sur le bargraphe

#if USE_PRINT_BARGRAPH_COUNTER
	; Test d'emission d'un message "court"
	ldi		REG_Z_MSB, high(text_monitor_short_message << 1)
	ldi		REG_Z_LSB, low(text_monitor_short_message << 1)
	call		uos_push_text_in_fifo_tx

	lds		REG_X_LSB, G_BARGRAPH_COUNTER
	inc		REG_X_LSB
	sts		G_BARGRAPH_COUNTER, REG_X_LSB
	call		uos_print_1_byte_hexa
	call		uos_print_line_feed

	;call		uos_fifo_tx_to_send_sync
#endif

callback_1_ms_end:
	ret
; ---------

; ---------
; Code d'extension en prologement de celui execute dans l'espace BOOTLOADER
; => Doit imperativement se terminer par un 'ret'
; ---------
callback_gest_buttons:

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, '-'
	ldi		REG_TEMP_R18, 'p'				; Marquage 'p' avant 'P'
	ldi		REG_TEMP_R19, '-'
	call		uos_print_mark_3_char
	call		uos_print_line_feed

	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF

	movw		REG_X_LSB, REG_TEMP_R16		; Recopie de 'G_STATES_BUTTON' et 'G_STATES_BUTTON_NBR_TOUCH'
	call		uos_print_2_bytes_hexa		; Trace du bouton "courant" [0x<States+Num Button><Counter>] (ie. "B[0xc301]")

	call		uos_print_line_feed
#endif

	; Determination si appui court; sinon ignore
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	sbrs		REG_TEMP_R17, UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX
	rjmp		callback_gest_buttons_end

	; Determination du bouton #N [1, 2, 3, 4]
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	andi		REG_TEMP_R17, 0x0F						; Button #1, #2, #3 or #4

	; Origine de l'appui bouton
	; => Button #1 -> IDX_BIT_BARGRAPH_0 ('R17' = 1 -> PORTC = 0x7)
	; => Button #2 -> IDX_BIT_BARGRAPH_1 ('R17' = 2 -> PORTC = 0xB)
	; => Button #3 -> IDX_BIT_BARGRAPH_2 ('R17' = 3 -> PORTC = 0xD)
	; => Button #4 -> IDX_BIT_BARGRAPH_3 ('R17' = 4 -> PORTC = 0xE)
	; WARNING: PORTC<4:5> -> SDA:SCL de l'I2C
	;          PORTC<6>   -> RESET

callback_gest_buttons_bargraph:
	mov		REG_TEMP_R16, REG_TEMP_R17
	breq		callback_gest_buttons_bargraph_end

	dec		REG_TEMP_R16

	ldi		REG_Z_MSB, high(text_convert_for_bargraph_table << 1)
	ldi		REG_Z_LSB, low(text_convert_for_bargraph_table << 1)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16
	lpm      REG_TEMP_R16, Z

	;out		PORTC, REG_TEMP_R16			; Inhibition @ 'callback_1_ms'
	; Fin: Origine de l'appui bouton

callback_gest_buttons_bargraph_end:

	cpi		REG_TEMP_R17, UOS_BUTTON_1_NUM
	brne		callback_gest_buttons_more			; Saut si bouton #1 non appuye

	; Appui "court" du bouton #1
	; => Saut en 0x0000
	;    => Execution du programme C si telecharge
	;    => Sinon execution de Monitor via uOS (cf. 'uos_main_program')

	cli

	; Reinitialisation de la stack d'appel et saut...
	ldi		REG_TEMP_R16, high(RAMEND)
	out		SPH, REG_TEMP_R16

	ldi		REG_TEMP_R16, low(RAMEND)
	out		SPL, REG_TEMP_R16

	jmp		0x0000
	; Fin: Reinitialisation de la stack d'appel et saut...

callback_gest_buttons_more:
	; Code de test d'acquitement button #3
	cpi		REG_TEMP_R17, UOS_BUTTON_3_NUM
	rjmp		callback_gest_buttons_end

	; Effacement button #3 dans 'UOS_G_STATES_BUTTON' pour ne pas traiter l'appui dans uOS ;-)
	; TODO: Inoperant -> Le bouton est traite egalement dans uOS ;-(
	clr		REG_TEMP_R17
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R17	

callback_gest_buttons_end:
	ret
; ---------

; ---------
; Code d'extension en prologement de celui execute dans l'espace BOOTLOADER
; => Doit imperativement se terminer par un 'ret'
; ---------
callback_command:
	; Marquage du passage dans l'extension
	lds		REG_TEMP_R16, UOS_G_FLAGS_EXTENSIONS
	sbr		REG_TEMP_R16, UOS_FLG_EXTENSIONS_EXEC_COMMAND_MSK
	sts		UOS_G_FLAGS_EXTENSIONS, REG_TEMP_R16

	; Interpretation des commandes etendues
	lds		REG_TEMP_R16, UOS_G_TEST_COMMAND_TYPE

	clt											; Commande non reconnue a priori

	; Switch/Case @ commande 'UOS_G_TEST_COMMAND_TYPE'
	; => Code minimal utilisant 'r17' en recopie de 'SREG' qui evite des etiquettes intermediaires
	;    et permettant une implementation dans la limite de +/- 2K mots instructions ;-))
	; => Remarque: SREG (0x3F) ne permet pas l'utilisation de "sbic ..." ;-((
	; => TODO: Evolution de l'assembleur 'avra' pour accueillir la syntaxe "breq  $+/-xx"

	cpi		REG_TEMP_R16, '?'				; Print prompt
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_prompt

	cpi		REG_TEMP_R16, 'a'				; [a] (Calcul du CRC8-MAXIM d'une zone programme)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_a_min

	cpi		REG_TEMP_R16, 'e'				; [e] (Dump de l'eeprom)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_e_min

	cpi		REG_TEMP_R16, 'E'				; [E] (Ecriture dans l'eeprom)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_e_maj

	cpi		REG_TEMP_R16, 'S'				; [S] (Write into SRAM)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_s_maj

	cpi		REG_TEMP_R16, 'I'				; [I] (Write byte in SRAM @ I/O)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_i_maj

	cpi		REG_TEMP_R16, 'J'				; [J] (Write word in SRAM @ I/O)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_j_maj

	cpi		REG_TEMP_R16, 'i'				; [i] (Read from SRAM @ I/O)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_i_min

#if USE_TEST_LAC_LAS
	cpi		REG_TEMP_R16, 'l'				; [l] (Load and clear with LAC instruction)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_l_min

	cpi		REG_TEMP_R16, 'L'				; [l] (Load and set with LAS instruction)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_l_maj
#endif

	cpi		REG_TEMP_R16, 't'				; [t] (Test sequence)
	in			REG_TEMP_R17, SREG	
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_t_min

	cpi		REG_TEMP_R16, 'f'				; [f] (Lecture des fuses)
	in			REG_TEMP_R17, SREG
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_f_min

	cpi		REG_TEMP_R16, 'x'				; [x] (Execution a une adresse)
	in			REG_TEMP_R17, SREG
	sbrc		REG_TEMP_R17, SREG_Z
	rjmp		monitor_command_x_min
	; Fin: Switch/Case @ commande 'UOS_G_TEST_COMMAND_TYPE'

callback_command_end:
	ret
; ---------

; ---------
; Print bloquant d'une chaine de caracteres definie en memoire flash
;
; Usage:
;      ldi		REG_Z_MSB, <address MSB>
;      ldi		REG_Z_LSB, <address LSB>
;      rcall   uos_print_blocking_string
;
; Registres utilises
;    REG_Z_LSB:REG_Z_LSB -> Pointeur sur le texte en memoire programme (preserve)
;    REG_TEMP_R16        -> Working register (preserve)
; ---------
print_blocking_string:
	push		REG_Z_MSB
	push		REG_Z_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

print_blocking_string_loop:
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, CHAR_NULL		; '\0' terminal ?
	breq		print_blocking_string_end

	; Attente fin du precedent caractere emis
print_blocking_string_wait:
	lds		REG_TEMP_R17, UCSR0A
	sbrs		REG_TEMP_R17, UDRE0
	rjmp		print_blocking_string_wait
	; Fin: Attente fin du precedent caractere emis

	sts		UDR0, REG_TEMP_R16

	rjmp		print_blocking_string_loop

print_blocking_string_end:
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
monitor_command_prompt:
	call		uos_print_command_ok

	; Print de 'text_monitor_prompt' en mode non bloquant
	ldi		REG_Z_MSB, high(text_monitor_prompt << 1)
	ldi		REG_Z_LSB, low(text_monitor_prompt << 1)
	call		uos_push_text_in_fifo_tx_skip

	; Suite avec le detail des fonctionnalites supportees
	ldi		REG_Z_MSB, high(text_monitor_desc << 1)
	ldi		REG_Z_LSB, low(text_monitor_desc << 1)
	call		uos_push_text_in_fifo_tx_skip

	set													; Commande reconnue
	ret
; ---------

; ---------
; Initialisation de la SRAM dans la plage ]G_SRAM_EXTENSION_END_OF_USE, ..., UOS_G_SRAM_BOOTLOADER_END_OF_USE[
; => On suppose que 'G_SRAM_EXTENSION_END_OF_USE' > 'UOS_G_SRAM_BOOTLOADER_END_OF_USE'
; ---------
monitor_init_sram_fill:
	clr		REG_TEMP_R16
	ldi		REG_X_MSB, high(G_SRAM_EXTENSION_END_OF_USE - 1)
	ldi		REG_X_LSB, low(G_SRAM_EXTENSION_END_OF_USE - 1)

monitor_init_sram_fill_loop_a:
	st			X, REG_TEMP_R16
	sbiw		REG_X_LSB, 1
	cpi		REG_X_MSB, high(UOS_G_SRAM_BOOTLOADER_END_OF_USE)
	brne		monitor_init_sram_fill_loop_a
	cpi		REG_X_LSB, low(UOS_G_SRAM_BOOTLOADER_END_OF_USE)
	brne		monitor_init_sram_fill_loop_a

	ret
; ---------

; ---------
; Mise sur voie de garage avec clignotement "lent" de la Led RED
; ---------
monitor_invalid_it:
	cli
	ldi		REG_TEMP_R16, 80

monitor_invalid_it_more:
	; Memorisation du numero de l'It non attendue dans l'espace programme
	cbr		REG_TEMP_R17, UOS_FLG_WRONG_IT_BOOLOADER_MSK
	sbr		REG_TEMP_R17, UOS_FLG_WRONG_IT_PROGRAM_MSK
	sts		UOS_G_STATES_POST_MORTEM, REG_TEMP_R17

	; Extinction de toutes les Leds
	setLedBlueOff
	setLedYellowOff
	setLedGreenOff
	setLedRedOff

monitor_invalid_it_loop:
	push		REG_TEMP_R16			; Save/Restore temporisation dans REG_TEMP_R16
	setLedRedOn
	call		uos_delay_big_2
	pop		REG_TEMP_R16
	push		REG_TEMP_R16
	setLedRedOff
	call		uos_delay_big_2
	pop		REG_TEMP_R16
	rjmp		monitor_invalid_it_loop
; ---------

; ======================================================= Monitoring des commandes
; ---------
; Execution de la commande 'a'
; => Calcul du CRC8-MAXIM d'une zone programme
;    - 0xAAAA: l'adresse du 1st byte a lire et calculer
;    - 0xBBBB: l'adresse du dernier byte inclus a lire et calculer
;
; Reponse: "[NN>aAAAA]"
;          "TODO"
; ---------
monitor_command_a_min:
	call		uos_print_command_ok			; Commande acceptee

	; Prises des parametres
	; => 
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB			; Adresse du 1st byte a lire et calculer
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	lds		REG_Y_MSB, UOS_G_TEST_VALUE_MSB_MORE	; Adresse du dernier byte inclus a lire et calculer
	lds		REG_Y_LSB, UOS_G_TEST_VALUE_LSB_MORE

	; TODO: Test si Adresse TO > Adresse FROM
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB

	call		uos_print_2_bytes_hexa		; Adresse FROM

	pop		REG_X_LSB						; Recuperation adresse du dernier byte inclus a lire et calculer
	pop		REG_X_MSB
	push		REG_X_MSB
	push		REG_X_LSB

	call		uos_print_2_bytes_hexa		; Adresse TO
	call		uos_print_line_feed

	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB

	; Si les 2 adresses 'FROM' et 'TO' sont a zero
	; => Calcul sur la plage [0x0000, ..., ('end_of_program' - 1)]
	tst		REG_X_MSB
	brne		monitor_command_a_min_calcul
	tst		REG_X_LSB
	brne		monitor_command_a_min_calcul

	tst		REG_Y_MSB
	brne		monitor_command_a_min_calcul
	tst		REG_Y_LSB
	brne		monitor_command_a_min_calcul
	
	clr		REG_X_MSB			; Calcul a partir de l'adresse 0x0000
	clr		REG_X_LSB			; jusqu'a 'end_of_program' non incluse par defaut

	ldi		REG_Y_MSB, high(end_of_program - 1)
	ldi		REG_Y_LSB, low(end_of_program - 1)

monitor_command_a_min_calcul:
	; Adresse sur des mots en flash
	lsl		REG_X_LSB
	rol		REG_X_MSB

	; Raz CRC8
	clr		REG_TEMP_R16
	sts		G_CALC_CRC8, REG_TEMP_R16

monitor_command_a_min_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	; Remarque: Division par 2 car dump de word ;-)
	lsr		REG_X_MSB
	ror		REG_X_LSB
	call		uos_print_2_bytes_hexa

	; Retablissement de 'X' qui est toujours pair ici
	lsl		REG_X_LSB
	rol		REG_X_MSB

	; Impression du dump ("[0x....]")
	; => TODO: Si saut 'end_of_program' est de la forme 0xhhh0, pas de valeur apres [0x...]
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	call		uos_push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 32

monitor_command_a_min_loop_1:
	; Valeur de la memoire programme indexee par 'REG_X_MSB:REG_X_LSB'
	movw		REG_Z_LSB, REG_X_LSB
	adiw		REG_X_LSB, 1								; Preparation prochain byte

	; Calcul jusqu'a l'adresse 'end_of_program' non incluse
	ldi		REG_TEMP_R16, 0x01
	and		REG_TEMP_R16, REG_X_LSB
	breq		monitor_command_a_min_loop_1_cont_d	; Lecture par mot

	push		REG_X_MSB
	push		REG_X_LSB
	lsr		REG_X_MSB
	ror		REG_X_LSB

	; TODO: 'end_of_program' a saisir en parametre
	mov		REG_TEMP_R16, REG_Y_LSB
	cp			REG_TEMP_R16, REG_X_LSB

	mov		REG_TEMP_R16, REG_Y_MSB
	cpc		REG_TEMP_R16, REG_X_MSB

	pop		REG_X_LSB
	pop		REG_X_MSB
	brmi		monitor_command_a_min_end
	; Fin: Calcul jusqu'a l'adresse contenue dans 'Y'

monitor_command_a_min_loop_1_cont_d:
	ldi		REG_TEMP_R16, 0x01
	eor		REG_Z_LSB, REG_TEMP_R16		; Lecture MSB puis LSB
	lpm		REG_TEMP_R16, Z
	push		REG_TEMP_R16
	call		uos_convert_and_put_fifo_tx

	pop		REG_TEMP_R16
	rcall		calc_crc8_maxim

	dec		REG_TEMP_R18
	brne		monitor_command_a_min_loop_1

	ldi		REG_TEMP_R16, ']'
	call		uos_push_1_char_in_fifo_tx

	push		REG_X_LSB
	lds		REG_X_LSB, G_CALC_CRC8
	call		uos_print_1_byte_hexa
	call		uos_print_line_feed
	pop		REG_X_LSB

	rjmp		monitor_command_a_min_loop_0

monitor_command_a_min_end:
	ldi		REG_TEMP_R16, ']'
	call		uos_push_1_char_in_fifo_tx
	push		REG_X_LSB
	lds		REG_X_LSB, G_CALC_CRC8
	call		uos_print_1_byte_hexa
	call		uos_print_line_feed
	pop		REG_X_LSB

monitor_command_a_min_rtn:
	ldi		REG_Z_MSB, ((text_crc8_maxim << 1) / 256)
	ldi		REG_Z_LSB, ((text_crc8_maxim << 1) % 256)
	call		uos_push_text_in_fifo_tx

	; Reprise et print de la 1st adresse testee
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB			; Adresse du 1st byte a lire et calculer
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB
	call		uos_print_2_bytes_hexa

	; Print de la derniere adresse testee
	movw		REG_X_LSB, REG_Y_LSB
	call		uos_print_2_bytes_hexa

	; Print du CRC8-MAXIM final
	lds		REG_X_LSB, G_CALC_CRC8
	call		uos_print_1_byte_hexa

	call		uos_print_line_feed

	set											; Commande reconnue
	ret
; ---------

; ---------
; Calcul du CRC8-MAXIM
;
; Input:  G_CALC_CRC8 and REG_TEMP_R16
; Output: G_CALC_CRC8 updated for retry
; ---------
calc_crc8_maxim:
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19

	mov		REG_TEMP_R17, REG_TEMP_R16
	lds		REG_TEMP_R19, G_CALC_CRC8

	ldi		REG_TEMP_R18, 8

calc_crc8_maxim_loop_bit:
	mov		REG_TEMP_R16, REG_TEMP_R19	; 'REG_TEMP_R19' contient le CRC8 calcule
	eor		REG_TEMP_R16, REG_TEMP_R17	; 'REG_TEMP_R17' contient le byte a inserer dans le polynome
	andi		REG_TEMP_R16, 0x01			; carry = ((crc ^ i__byte) & 0x01);

	clt											; 'T' determine le report de la carry	
	breq		calc_crc8_maxim_a
	set

calc_crc8_maxim_a:
	lsr		REG_TEMP_R19					; crc >>= 1;
	brtc		calc_crc8_maxim_b

	ldi		REG_TEMP_R16, CRC8_POLYNOMIAL
	eor		REG_TEMP_R19, REG_TEMP_R16					; crc ^= (carry ? CRC8_POLYNOMIAL: 0x00);

calc_crc8_maxim_b:
	sts		G_CALC_CRC8, REG_TEMP_R19

	lsr		REG_TEMP_R17									; i__byte >>= 1

	dec		REG_TEMP_R18
	brne		calc_crc8_maxim_loop_bit

	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16

	ret
; ---------

; ---------
; Execution de la commande 'e'
; => Dump de l'EEPROM: "<eAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st byte a lire (si 0xAAAA == 0x0000 => Debut a l'adresse 0 de l'EEPROM
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;      avec une limitation des adresses dans la plage [0, ..., EEPROMEND]
;
; Reponse: "[NN>eAAAA]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
monitor_command_e_min:
	call		uos_print_command_ok			; Commande acceptee

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	tst		REG_X_MSB
	brne		monitor_command_e_min_cont_d
	tst		REG_X_LSB
	brne		monitor_command_e_min_cont_d

	; Dump de toute l'EEPROM
	; TODO: Calcul @ 'EEPROMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		monitor_command_e_min_loop_0

monitor_command_e_min_cont_d:
	; Dump sur 8 x 16 bytes
	; TODO: Get 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

monitor_command_e_min_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	call		uos_print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	call		uos_push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

monitor_command_e_min_loop_1:
	; Valeur de l'EEPROM indexee par 'REG_X_MSB:REG_X_LSB'
	call		uos_eeprom_read_byte
	call		uos_convert_and_put_fifo_tx

	adiw		REG_X_LSB, 1

	; Test limite 'EEPROMEND'
	; => On suppose qu'au depart 'X <= EEPROMEND'
	cpi		REG_X_MSB, ((EEPROMEND + 1) / 256)
	brne		monitor_command_e_min_more2
	cpi		REG_X_LSB, ((EEPROMEND + 1) % 256)
	brne		monitor_command_e_min_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

monitor_command_e_min_more2:
	dec		REG_TEMP_R18
	brne		monitor_command_e_min_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	call		uos_push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		monitor_command_e_min_loop_0

	set											; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'E'
; => Ecriture d'une suite de N bytes dans l'EEPROM (N dans [1, 2, ...])
;    - 0xAAAA:    l'adresse du byte a ecrire dans l'EEPROM
;
; Reponse: "[NN>EAAAA]" (Adresse du byte a ecrire)
; ---------
monitor_command_e_maj:
	lds		REG_X_LSB, UOS_G_TEST_VALUES_IDX_WRK
	lsr		REG_X_LSB									; REG_X_LSB /= 2 pour nbr de bytes a ecrire

	mov		REG_TEMP_R18, REG_X_LSB
	; Fin: Prise du nombre de mots passes en arguments

	; Recuperation de l'adresse du 1st byte a ecrire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	; Test de 'REG_X_MSB:REG_X_LSB' dans la plage [0, ..., EEPROMEND] @ 'REG_TEMP_R18'
	ldi		REG_TEMP_R16, low(EEPROMEND + 2)
	ldi		REG_TEMP_R17, high(EEPROMEND + 2)
	sub		REG_TEMP_R16, REG_TEMP_R18
	sbci		REG_TEMP_R17, 0					; Soustraction 16 bits (report de la Carry)

	cp			REG_X_LSB, REG_TEMP_R16		
	cpc		REG_X_MSB, REG_TEMP_R17		
	brpl		monitor_command_e_maj_out_of_range
	; Fin: Test de 'REG_X_MSB:REG_X_LSB' dans la plage [0, ..., EEPROMEND] @ 'REG_TEMP_R18'

	call		uos_print_command_ok			; Commande reconnue

	; Lecture des 'REG_TEMP_R18' mots de la SRAM dont seule la partie LSB sera ecrite
	mov		REG_TEMP_R17, REG_TEMP_R18
	ldi		REG_Y_MSB, high(UOS_G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(UOS_G_TEST_VALUES_ZONE)

	; Clear error
	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS
	cbr		REG_TEMP_R16, UOS_FLG_TEST_EEPROM_ERROR_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R16

monitor_command_e_maj_loop:
	ld			REG_TEMP_R16, Y
	rcall		eeprom_write_byte

	; Verification de l'ecriture
	mov		REG_TEMP_R18, REG_TEMP_R16		; Save data writed
	clr		REG_TEMP_R16						; Raz before read eeprom @ 'X'
	call		uos_eeprom_read_byte	

	cpse		REG_TEMP_R16, REG_TEMP_R18
	rjmp		monitor_command_e_maj_ko
	; Fin: Verification de l'ecriture

	adiw		REG_X_LSB, 1			; Adresse EEPROM suivante
	adiw		REG_Y_LSB, 2			; Saut au prochain mot
	dec		REG_TEMP_R17
	brne		monitor_command_e_maj_loop

	rjmp		monitor_command_e_maj_end

monitor_command_e_maj_ko:
	ldi      REG_Z_MSB, ((text_eeprom_error << 1) / 256)
	ldi      REG_Z_LSB, ((text_eeprom_error << 1) % 256)
	call		uos_push_text_in_fifo_tx
	call		uos_print_2_bytes_hexa
	call		uos_print_line_feed

	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS
	sbr		REG_TEMP_R16, UOS_FLG_TEST_EEPROM_ERROR_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R16
	rjmp		monitor_command_e_maj_end

monitor_command_e_maj_out_of_range:
	call		uos_print_command_ko			; Commande non executee

monitor_command_e_maj_end:
	set											; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'i'
; => Dump de la SRAM: "<iAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st byte a lire (si 0xAAAA == 0x0000 => Debut en 0x00
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;      avec une limitation des adresses dans la plage [0x00, ..., 0xFF]
;
; Reponse: "[NN>iAAAA-BBBB]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
monitor_command_i_min:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	tst		REG_X_MSB
	brne		_uos_exec_command_type_i_read_cont_d
	tst		REG_X_LSB
	brne		_uos_exec_command_type_i_read_cont_d

	clr		REG_X_MSB
	clr		REG_X_LSB

	; Dump de toute la SRAM
	; TODO: Calcul @ 'SRAM_START' et 'RAMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		_uos_exec_command_type_i_read_loop_0

_uos_exec_command_type_i_read_cont_d:
	; Dump sur 8 x 16 bytes
	; TODO: Get 'UOS_G_TEST_VALUE_MSB_MORE:UOS_G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

_uos_exec_command_type_i_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	call		uos_print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	call		uos_push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

_uos_exec_command_type_i_read_loop_1:
	; Valeur de la SRAM indexee par 'REG_X_MSB:REG_X_LSB'
	ld			REG_TEMP_R16, X+
	call		uos_convert_and_put_fifo_tx

	; Test limite '0xFF'
	; => On suppose qu'au depart 'X <= 0xFF'
	cpi		REG_X_MSB, ((0xFF + 1) / 256)
	brne		_uos_exec_command_type_i_read_more2
	cpi		REG_X_LSB, ((0xFF + 1) % 256)
	brne		_uos_exec_command_type_i_read_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

_uos_exec_command_type_i_read_more2:
	dec		REG_TEMP_R18
	brne		_uos_exec_command_type_i_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	call		uos_push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		_uos_exec_command_type_i_read_loop_0

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'I'
; => Ecriture d'un byte dans la SRAM @ I/O: "<IAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du byte a ecrire
;    - 0xBBBB: la valeur du byte a ecrire (partie LSB)
;
; Reponse: "[NN>IAAAA-BBBB]"
; ---------
monitor_command_i_maj:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du byte a ecrire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	; Valeur a ecrire
	; Fix: Harmonisation des commandes d'ecritures '<SAddress-Value' et '<EAddress+Value'
	;      => '+Value' semble correct d'un point de vue ergonomique ;-)

	;lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB_MORE	; Syntaxe "<IAddress-Value"
	lds		REG_TEMP_R16, UOS_G_TEST_VALUES_ZONE		; Syntaxe "<IAddress+Value"
	st			X, REG_TEMP_R16

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'J'
; => Ecriture d'un word dans la SRAM @ I/O d'une maniere atomique: "<JAAAA+BBBB" avec:
;    - 0xAAAA: l'adresse du word a ecrire
;    - 0xBBBB: la valeur des 2 bytes (MSB:LSB) a ecrire aux adresses (0xAAAA) + 1 et 0xAAAA
;              car les registres sont definis comme [0xAAAA:(0xAAAA + 1)] <- [LSB:MSB]
;              => La partie MSB est ecrite avant la partie LSB
;                 => Exemple donne dans la datasheet pour [UBRR0H:UBRR0L]
;
; Reponse: "[NN>J [Ok]]"
; ---------
monitor_command_j_maj:
	; Print de la reponse en mode bloquant car certains registres peuvent
	; affecter la vitesse de transmission ;-)
	ldi		REG_Z_MSB, high(text_response_j_maj << 1)
	ldi		REG_Z_LSB, low(text_response_j_maj << 1)
	rcall		print_blocking_string

	; Recuperation de l'adresse du word a ecrire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	; Valeur a ecrire
	; Fix: Harmonisation des commandes d'ecritures '<SAddress+Value' et '<EAddress+Value'
	;      => '+Value' semble correct d'un point de vue ergonomique ;-)

	cli		; Ecriture atomique

	lds		REG_TEMP_R16, (UOS_G_TEST_VALUES_ZONE + 1)	; Ecriture de la partie MSB
	st			X, REG_TEMP_R16

	sbiw		REG_X_LSB, 1											; Acces a l'adresse LSB
	lds		REG_TEMP_R16, UOS_G_TEST_VALUES_ZONE			; Ecriture de la partie LSB
	st			X, REG_TEMP_R16

	sei		; Fin: Ecriture atomique

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'S'
; => Ecriture d'un byte dans la SRAM: "<SAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du byte a ecrire
;    - 0xBBBB: la valeur du byte a ecrire (partie LSB)
;
; Reponse: "[NN>SAAAA-BBBB]"
; ---------
monitor_command_s_maj:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du byte a ecrire
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB

	; Valeur a ecrire
	; Fix: Harmonisation des commandes d'ecritures '<SAddress-Value' et '<EAddress+Value'
	;      => '+Value' semble correct d'un point de vue ergonomique ;-)

	;lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB_MORE	; Syntaxe "<SAddress-Value"
	lds		REG_TEMP_R16, UOS_G_TEST_VALUES_ZONE		; Syntaxe "<SAddress+Value"
	st			X, REG_TEMP_R16

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 't'
;          "TODO"
; ---------
monitor_command_t_min:
	call		uos_print_command_ok			; Commande acceptee

	; Prises des parametres
	; => 
	lds		REG_X_MSB, UOS_G_TEST_VALUE_MSB			; hh
	lds		REG_X_LSB, UOS_G_TEST_VALUE_LSB			; hl

	lds		REG_Y_MSB, UOS_G_TEST_VALUE_MSB_MORE	; Hh
	lds		REG_Y_LSB, UOS_G_TEST_VALUE_LSB_MORE	; Hl

	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB

	call		uos_print_2_bytes_hexa		; Print 'hhhl' contenu dans 'X'

	pop		REG_X_LSB						; Recuperation 'HhHl'
	pop		REG_X_MSB
	push		REG_X_MSB
	push		REG_X_LSB

	call		uos_print_2_bytes_hexa		; Print 'HhHl' contenu dans 'X'
	call		uos_print_line_feed

	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB

	lds		REG_TEMP_R18, UOS_G_TEST_VALUE_LSB			; hl
	lds		REG_TEMP_R20, UOS_G_TEST_VALUE_LSB_MORE	; Hl
	cp 		REG_TEMP_R18, REG_TEMP_R20

	in			r0, SREG
	rcall		extract_and_print_sreg

	lds		REG_TEMP_R19, UOS_G_TEST_VALUE_MSB			; hl
	lds		REG_TEMP_R21, UOS_G_TEST_VALUE_MSB_MORE	; Hl

	out		SREG, r0
	cpc		REG_TEMP_R19, REG_TEMP_R21

	rcall		extract_and_print_sreg

	set											; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'f'
; => Lecture des fuses
; ---------
monitor_command_f_min:
	call		uos_print_command_ok			; Commande reconnue

	; Signature...
	ldi		REG_TEMP_R16, (1 << SIGRD) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x00
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	ldi		REG_TEMP_R16, (1 << SIGRD) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x02
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	ldi		REG_TEMP_R16, (1 << SIGRD) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x04
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	call		uos_print_line_feed
	; Fin: Signature...

	; Read Fuse Low Byte
	ldi		REG_TEMP_R16, (1 << BLBSET) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x00
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	; Read Lock bits
	ldi		REG_TEMP_R16, (1 << BLBSET) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x01
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	; Read Read Fuse Extended Byte
	ldi		REG_TEMP_R16, (1 << BLBSET) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x02
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	; Read Fuse High Byte
	ldi		REG_TEMP_R16, (1 << BLBSET) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x03
	lpm		REG_X_LSB, Z
	call		uos_print_1_byte_hexa

	call		uos_print_line_feed

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'x'
; => Execution a une adresse
; ---------
monitor_command_x_min:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de l'adresse d'execution
	lds      REG_Z_MSB, UOS_G_TEST_VALUE_MSB
	lds      REG_Z_LSB, UOS_G_TEST_VALUE_LSB

	; Si execution du 'Reset' (adresse 0x0000)
	; => Reinitialisation de 'SPH:SPL' a 'RAMEND'
	adiw		REG_Z_LSB, 0
	brne		monitor_command_x_min_more

	ldi		REG_TEMP_R16, high(RAMEND)
	out		SPH, REG_TEMP_R16

	ldi		REG_TEMP_R16, low(RAMEND)
	out		SPL, REG_TEMP_R16
	; Fin: Si execution du 'Reset' (adresse 0x0000)

	; Saut a un programme dont l'adresse est passe en argument
	; avec d'eventuels parametres apres 'CHAR_COMMAND_PLUS'
	; => Remarque: Le 'ret' en fin de programme fera retourner apres
	;              l'instruction 'rcall exec_command'

monitor_command_x_min_more:
	icall

	set											; Commande reconnue
	ret
; ---------

; ---------
; Extraction de SREG [ITHSVNZC] passe dans 'REG_X_LSB'
; ---------
extract_and_print_sreg:
	; Valeur de SREG
	in			REG_X_LSB, SREG
	push		REG_X_LSB

	ldi		REG_Z_MSB, high(text_sreg << 1)
	ldi		REG_Z_LSB, low(text_sreg << 1)
	call		uos_push_text_in_fifo_tx

	pop		REG_X_LSB
	push		REG_X_LSB
	call		uos_print_1_byte_hexa

	pop		REG_X_LSB
	mov		REG_TEMP_R17, REG_X_LSB

	ldi		REG_TEMP_R16, '['
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_i
	ldi		REG_TEMP_R16, 'I'

extract_and_print_sreg_no_i:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_t
	ldi		REG_TEMP_R16, 'T'

extract_and_print_sreg_no_t:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_h
	ldi		REG_TEMP_R16, 'H'

extract_and_print_sreg_no_h:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_s
	ldi		REG_TEMP_R16, 'S'

extract_and_print_sreg_no_s:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_v
	ldi		REG_TEMP_R16, 'V'

extract_and_print_sreg_no_v:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_n
	ldi		REG_TEMP_R16, 'N'

extract_and_print_sreg_no_n:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_z
	ldi		REG_TEMP_R16, 'Z'

extract_and_print_sreg_no_z:
	call		uos_push_1_char_in_fifo_tx

	rol		REG_TEMP_R17
	ldi		REG_TEMP_R16, '.'
	brcc		extract_and_print_sreg_no_c
	ldi		REG_TEMP_R16, 'C'

extract_and_print_sreg_no_c:
	call		uos_push_1_char_in_fifo_tx

	ldi		REG_TEMP_R16, ']'
	call		uos_push_1_char_in_fifo_tx

	call		uos_print_line_feed

	ret
; ---------

; ======================================================= Monitoring des commandes

; ---------
; Ecriture d'un byte contenu dans 'REG_TEMP_R16' a l'adresse 'REG_X_MSB:REG_X_LSB' de l'EEPROM
; ---------
eeprom_write_byte:
	; Set address
	out		EEARL, REG_X_LSB
	out		EEARH, REG_X_MSB

	; Set data
	out		EEDR, REG_TEMP_R16

	; Ecriture a l'adresse 'REG_X_MSB:REG_X_LSB' d'un byte
	cbi		EECR, EEPM1
	cbi		EECR, EEPM0

	; Sequence interruptible
	cli
	sbi		EECR, EEMPE		; Start EEPROM write
	sbi		EECR, EEPE
	sei
	; Fin: Sequence interruptible
	; Fin: Ecriture a l'adresse 'REG_X_MSB:REG_X_LSB' d'un byte

eeprom_write_byte_wait:
	sbic		EECR, EEPE
	rjmp		eeprom_write_byte_wait

	ret
; ---------

#if USE_TEST_LAC_LAS
; ---------
; Test des 2 instructions 'LAC - Load and Clear' et 'LAS - Load and Set'
; ---------
monitor_command_l_min:
test_lac:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de la valeur a "clear"
	lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB
	push		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	call		uos_print_1_byte_hexa
	pop		REG_TEMP_R16

	; Adresse du resultat initialise a 0
	ldi		REG_Z_MSB, high(G_RESULT_LAC_LAS)
	ldi		REG_Z_LSB, low(G_RESULT_LAC_LAS)

#if 1
	;lac		Z, REG_TEMP_R16				; Execute (Z) <- ($FF - Rd) and (Z), Rd <- (Z)

	; Simulation ecriture avec changement
	inc		REG_TEMP_R16
	st			Z, REG_TEMP_R16
	
#else
	;.dw		0x0693			; 1001 001r rrrr 0110 -> 1001 0011 0000 110
	.dw		0x9306			; 1001 001r rrrr 0110 -> 1001 0011 0000 110
#endif

	lds		REG_X_LSB, G_RESULT_LAC_LAS
	call		uos_print_1_byte_hexa
	call		uos_print_line_feed

test_lac_rtn:
	set											; Commande executee
	ret
; ---------

; ---------
monitor_command_l_maj:
test_las:
	call		uos_print_command_ok			; Commande reconnue

	; Recuperation de la valeur a "seter"
	lds		REG_TEMP_R16, UOS_G_TEST_VALUE_LSB
	push		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	call		uos_print_1_byte_hexa
	pop		REG_TEMP_R16

	; Adresse du resultat initialise a 0
	ldi		REG_Z_MSB, high(G_RESULT_LAC_LAS)
	ldi		REG_Z_LSB, low(G_RESULT_LAC_LAS)

#if 1
	;las		Z, REG_TEMP_R16				; Execute (Z) <- ($FF or Rd) & (Z), Rd <- (Z)

	; Simulation ecriture avec changement
	dec		REG_TEMP_R16
	st			Z, REG_TEMP_R16
#else
	;.dw		0x0593			; 1001 001r rrrr 0101 -> 1001 0011 0000 0101
	.dw		0x9305			; 1001 001r rrrr 0101 -> 1001 0011 0000 0101
#endif

	lds		REG_X_LSB, G_RESULT_LAC_LAS
	call		uos_print_1_byte_hexa
	call		uos_print_line_feed

test_las_rtn:
	set											; Commande executee
	ret
; ---------
#endif

; Constantes et textes definis naturellement (MSB:LSB et ordre naturel du texte)
; => Remarque: Nombre pair de caracteres pour eviter le message:
;              "Warning : A .DB segment with an odd number..."
;
; Warning: Adresse multiple de 64 pour etre programme page par page par uOS

.dw	CHAR_SEPARATOR		; Debut section datas	; NE PAS SUPPRIMER ;-)

text_monitor_prompt:
.db	"### Monitor $Revision: 1.19 $", CHAR_LF, CHAR_NULL, CHAR_NULL

text_monitor_init:
.db	"### Initialization...", CHAR_LF, CHAR_NULL, CHAR_NULL

text_monitor_desc:
.db	"### - '<?'                   Whoami", CHAR_LF
.db	"### - '<a[AddrFrom-AddrTo]'  Calculate CRC8-MAXIM", CHAR_LF
.db	"### - '<e[AddrFrom]'         Dump of EEPROM", CHAR_LF
.db	"### - '<EAddress+v0+v1+...'  Writes values in EEPROM ", CHAR_LF
.db	"### - '<f'                   Read signature [#0][#1][#2] and the fuses [Low][Lock][Ext][High]", CHAR_LF
.db	"### - '<i[AddrFrom]'         Dump of I/O ", CHAR_LF
.db	"### - '<IAddress+Value'      Write byte in I/O ", CHAR_LF
.db	"### - '<JAddress+Value'      Write word MSB:LSB in I/O at [Address:(Address-1)]", CHAR_LF

#if USE_TEST_LAC_LAS
.db	"### - '<lValue'              Load and clear test ", CHAR_LF, 
.db	"### - '<LValue'              Load and set test ", CHAR_LF
#endif

.db	"### - '<SAddress+Value'      Write in SRAM ", CHAR_LF
.db	"### - '<tValue1-Value2'      Test compare", CHAR_LF
.db	"### - '<xAddress'            Call to Address", CHAR_LF, CHAR_NULL

text_crc8_maxim:
.db	"CRC8-MAXIM ", CHAR_NULL

text_hexa_value:
.db	"[0x", CHAR_NULL

text_hexa_value_lf_end:
.db	"]", CHAR_LF, CHAR_NULL, CHAR_NULL

text_eeprom_error:
.db	"Err: EEPROM at ", CHAR_NULL

text_convert_for_bargraph_table:
.db   0x7, 0xB, 0xD, 0xE				; [0, 1, 2, 3] -> [0x7, 0xB, 0xD, 0xE]

text_monitor_short_message:
.db	"### ", CHAR_NULL, CHAR_NULL

text_sreg:
.db	"SREG ", CHAR_NULL

text_response_j_maj:
.db   ">J [Ok]", CHAR_LF, CHAR_NULL, CHAR_NULL

#if USE_TEST_LAC_LAS
text_test_lac:
.db	"Test LAC", CHAR_LF, CHAR_NULL

text_test_las:
.db	"Test LAS", CHAR_LF, CHAR_NULL
#endif

monitor_magic_const:
.dw	0x1234

end_of_program:

; End of file

