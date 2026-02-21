; "$Id: ATmega328P_uOS_Buttons.asm,v 1.3 2026/02/18 18:01:34 administrateur Exp $"

#include "ATmega328P_uOS_Buttons.h"

.cseg

; ======================================================= Gestion des 4 boutons
; ---------
; Gestion boutons
; ---------
_uos_gest_buttons_ret:
	rjmp		_uos_gest_buttons_rtn

_uos_gest_buttons:
	; Acquitement et action de(s) appui(s) boutons appele toutes les 1mS
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NOTIF
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF
	tst		REG_TEMP_R16
	breq		_uos_gest_buttons_ret

	tst		REG_TEMP_R17
	breq		_uos_gest_buttons_ret

	; Appui bouton a traiter et a acquiter
	;
	; ---------
	; Prolongement si le code est execute au RESET depuis l'espace PROGRAM et
	; si le vecteur commence par l'instruction 'rjmp'
	; ---------
	ldi		REG_Z_MSB, high(_uos_callback_gest_buttons)	; Execution si possible de l'extension
	ldi		REG_Z_LSB, low(_uos_callback_gest_buttons)		; dans l'espace PROGRAM
	rcall		_uos_exec_extension_into_program
	; ---------

	; Apres l'eventuel execution dan le program, l'appui bouton peut ne pas avoir ete
	; traite ni acquite
	; => Si pas traite ni acquite => Continue dans le BOOTLOADER
	;    Sinon => retour
	;
	; L'acquitement a t'il ete effectue dans l'espace PROGRAM ?
	;
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NOTIF
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF
	tst		REG_TEMP_R16
	breq		_uos_gest_buttons_ret

	tst		REG_TEMP_R17
	breq		_uos_gest_buttons_ret

	; Non => Bouton a traite et a acquiter

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, '-'
	ldi		REG_TEMP_R18, 'B'
	ldi		REG_TEMP_R19, '-'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed

	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF

	movw		REG_X_LSB, REG_TEMP_R16		; Recopie de 'G_STATES_BUTTON' et 'UOS_G_STATES_BUTTON_NBR_TOUCH'
	rcall		uos_print_2_bytes_hexa		; Trace du bouton "courant" [0x<States+Num Button><Counter>] (ie. "B[0xc301]")

	rcall		uos_print_line_feed
#endif

	; Notification vers 'DigiSpark-Monitoring'
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	sbrc		REG_TEMP_R17, UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX
	rjmp		_uos_gest_buttons_short

	sbrc		REG_TEMP_R17, FLG_STATE_BUTTON_LONG_TOUCH_IDX
	rjmp		_uos_gest_buttons_long
	rjmp		_uos_gest_buttons_rtn

_uos_gest_buttons_short:
	ldi		REG_Z_MSB, high(_uos_text_press_button_short << 1)
	ldi		REG_Z_LSB, low(_uos_text_press_button_short << 1)
	rjmp		_uos_gest_buttons_print_text

_uos_gest_buttons_long:
	ldi		REG_Z_MSB, high(_uos_text_press_button_long << 1)
	ldi		REG_Z_LSB, low(_uos_text_press_button_long << 1)

_uos_gest_buttons_print_text:
	rcall		uos_push_text_in_fifo_tx_skip						; Print message "### Press button..."

	lds		REG_TEMP_R17, UOS_G_FLAGS_2						; Reset 'FLG_2_ENABLE_DERIVATION'
	cbr		REG_TEMP_R17, UOS_FLG_2_ENABLE_DERIVATION_MSK		; a chaque appui bouton
	sts		UOS_G_FLAGS_2, REG_TEMP_R17

	; Determination du bouton #N [1, 2, 3, 4]
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	andi		REG_TEMP_R17, 0x0F						; Button #1, #2, #3 or #4

	; Determination de l'origine de l'execution
	rcall		_uos_if_execution_into_zone_bootloader	; Code si execute depuis l'espace BOOTLOADER

	ldi		REG_TEMP_R18, 'P'							; A priori dans l'espace "PROGRAM"
	breq		_uos_gest_buttons_program				; Saut si pas dans l'espace "BOOTLOADER"

	ldi		REG_TEMP_R18, 'B'							; Et non, dans l'espace BOOTLOADER
	rjmp		_uos_gest_buttons_bootloader
	; Fin: Determination de l'origine de l'execution

_uos_gest_buttons_program:
	cpi		REG_TEMP_R17, UOS_BUTTON_1_NUM
	brne		_uos_gest_buttons_more					; Saut si bouton #1 non appuye

	; Appui "court" du bouton #1 dans l'espace PROGRAM ?
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	sbrs		REG_TEMP_R17, UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX
	rjmp		_uos_gest_buttons_more					; Ignore si appui "long" dans l'espace PROGRAM

	; Oui: Bascule via le 'jump reset' de l'espace PROGRAM vers l'espace BOOTLOADER
	cli

	; Reinitialisation de la stack d'appel et saut au BOOTLOADER
	ldi		REG_TEMP_R16, high(RAMEND)
	out		SPH, REG_TEMP_R16

	ldi		REG_TEMP_R16, low(RAMEND)
	out		SPL, REG_TEMP_R16

	rjmp		_uos_main_bootloader
	; Fin: Reinitialisation de la stack d'appel et saut au BOOTLOADER

_uos_gest_buttons_bootloader:
	cpi		REG_TEMP_R17, UOS_BUTTON_1_NUM
	brne		_uos_gest_buttons_more					; Saut si bouton #1 non appuye

	; Appui "court" du bouton #1 dans l'espace BOOTLOADER ?
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	sbrs		REG_TEMP_R17, UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX
	rjmp		_uos_gest_buttons_1_long				; Non: Programmation de l'addon

	; Oui: Bascule via le 'jump reset' de l'espace BOOTLOADER vers l'espace PROGRAM
	cli

	; Reinitialisation de la stack d'appel et saut dans le PROGRAM
	ldi		REG_TEMP_R16, high(RAMEND)
	out		SPH, REG_TEMP_R16

	ldi		REG_TEMP_R16, low(RAMEND)
	out		SPL, REG_TEMP_R16


	; TODO: Changer avec un saut a l'adresse 0x0000 a laquelle
	;       un '[r]jmp uos_main_program' est defini
	;       => Cf. 'ATmega328P_monitor.asm'
#if 0
	rjmp		uos_main_program
#else
	jmp		reset_addr_0x0
#endif
	; Fin: Reinitialisation de la stack d'appel et saut dans le PROGRAM

_uos_gest_buttons_1_long:
	; L'appui "long" du bouton #1 ne doit etre pris en compte que depuis BOOTLOADER ;-)
	; => Evite le "bypass" dans PROGRAM (cf. 'ATmega328P_uOS_P1.addons')
	rcall		_uos_if_execution_into_zone_bootloader
	breq		_uos_gest_buttons_more

	; Autorisation d'ecriture dans le programme si appui long bouton #1 dans BOOTLOADER
	lds		REG_TEMP_R17, UOS_G_FLAGS_2
	sbr		REG_TEMP_R17, UOS_FLG_2_ENABLE_DERIVATION_MSK
	sts		UOS_G_FLAGS_2, REG_TEMP_R17
	;rjmp		_uos_gest_buttons_more
	; Fin: Autorisation d'ecriture dans le programme si appui long bouton #1 dans BOOTLOADER

_uos_gest_buttons_more:
	cpi		REG_TEMP_R17, UOS_BUTTON_2_NUM
	brne		_uos_gest_buttons_more_2				; Saut si bouton #2 non appuye

	; Appui "court" du bouton #2 dans l'espace PROGRAM ou BOOTLOADER ?
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	sbrs		REG_TEMP_R17, UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX
	rjmp		_uos_gest_buttons_more_2				; Ignore si appui "long"

	; Reset de l'erreur
	; => Arret des flash Led RED
	clr		REG_TEMP_R17
	sts		G_TEST_ERROR, REG_TEMP_R17

_uos_gest_buttons_more_2:
	mov		REG_TEMP_R16, REG_TEMP_R18		; Print 'REG_TEMP_R18' ([B]ootloader ou [P]rogram)
	lds		REG_TEMP_R17, UOS_G_FLAGS_2
	rcall		uos_push_1_char_in_fifo_tx_skip

	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NOTIF
	andi		REG_TEMP_R17, 0x0F	; Button #1, #2, #3 or #4
	ldi		REG_TEMP_R16, '0'
	add		REG_TEMP_R16, REG_TEMP_R17
	rcall		uos_push_1_char_in_fifo_tx_skip

	; Ajout nombre d'appuis "court" ou "long" si >= 2
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF
	cpi		REG_TEMP_R17, 2
	brlo		_uos_gest_buttons_end

	ldi		REG_TEMP_R16, ' '
	rcall		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF
	rcall		uos_print_1_byte_hexa_skip

_uos_gest_buttons_end:
	rcall		uos_print_line_feed_skip
	; Fin: Notification vers 'DigiSpark-Monitoring'

	clr		REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NOTIF, REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF, REG_TEMP_R16

	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	sbrs		REG_TEMP_R16, UOS_FLG_2_ENABLE_DERIVATION_IDX
	rjmp		_uos_gest_buttons_rtn

	ldi		REG_TEMP_R17, 'P'				; Trace [P]rogrammation
	rcall		uos_print_mark_skip

_uos_gest_buttons_rtn:
	ret

; ---------
; Etats des boutons
; ---------
_uos_get_states_buttons:
	; Lecture PORTD
	in			REG_TEMP_R16, PIND
	andi		REG_TEMP_R16, (BUTTON_1_MSK | BUTTON_2_MSK | BUTTON_3_MSK | BUTTON_4_MSK)

#if USE_TRACE_BUTTON
	push		REG_TEMP_R16
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'i'
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_X_LSB						; Print states of PIND
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
	pop		REG_TEMP_R16					; Restore states of PIND
#endif

	clr		REG_TEMP_R17		; Effacement numero du bouton

	cpi		REG_TEMP_R16, (BUTTON_1_MSK | BUTTON_2_MSK | BUTTON_3_MSK | BUTTON_4_MSK)
	brne		_uos_get_states_button_pressed

	rjmp		_uos_get_states_buttons_all_high

_uos_get_states_button_pressed:
	; Complement pour determiner l'entree a l'etat bas
	com		REG_TEMP_R16
	andi		REG_TEMP_R16, (BUTTON_1_MSK | BUTTON_2_MSK | BUTTON_3_MSK | BUTTON_4_MSK)

	; 1 bouton est au moins appuye
	; => Appui valide si un seul est appuye
	ldi		REG_TEMP_R17, UOS_BUTTON_1_NUM			; A priori bouton #1 appuye
	cpi		REG_TEMP_R16, BUTTON_1_MSK
	breq		_uos_get_states_button_low

	ldi		REG_TEMP_R17, UOS_BUTTON_2_NUM			; Non -> A priori bouton #2 appuye
	cpi		REG_TEMP_R16, BUTTON_2_MSK
	breq		_uos_get_states_button_low

	ldi		REG_TEMP_R17, UOS_BUTTON_3_NUM			; Non -> A priori bouton #3 appuye
	cpi		REG_TEMP_R16, BUTTON_3_MSK
	breq		_uos_get_states_button_low

	ldi		REG_TEMP_R17, UOS_BUTTON_4_NUM			; Non -> A priori bouton #4 appuye
	cpi		REG_TEMP_R16, BUTTON_4_MSK
	breq		_uos_get_states_button_low

	clr		REG_TEMP_R16
	sts		G_NUM_BUTTON, REG_TEMP_R16
	rjmp		_uos_get_states_buttons_end

_uos_get_states_button_low:
	clr		REG_TEMP_R16
	sbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_VALID_MSK
	sbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_LOW_MSK
	cbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_HIGH_MSK
	or			REG_TEMP_R16, REG_TEMP_R17
	sts		G_NUM_BUTTON, REG_TEMP_R16		; New 'G_NUM_BUTTON'

	; Verification pendant 'DURATION_BUTTON_ACQ' de 'G_NUM_BUTTON' @ 'G_NUM_BUTTON_PRE' si significatif
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_ACQ
	rcall		uos_test_timer
	brtc		_uos_get_states_button_low_valid				; Saut si timer expire

	lds		REG_TEMP_R18, G_NUM_BUTTON
	andi		REG_TEMP_R18, 0x0F
	lds		REG_TEMP_R19, G_NUM_BUTTON_PRE
	andi		REG_TEMP_R19, 0x0F

#if USE_TRACE_BUTTON
	push		REG_TEMP_R18
	push		REG_TEMP_R19

	push		REG_TEMP_R18
	push		REG_TEMP_R19
	ldi		REG_TEMP_R16, 'b'
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_X_LSB						; Print 'G_NUM_BUTTON_PRE & 0x0F'
	rcall		uos_print_1_byte_hexa
	pop		REG_X_LSB						; Print 'G_NUM_BUTTON & 0x0F'
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed

	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
#endif

	tst		REG_TEMP_R19
	breq		_uos_get_states_button_low_valid

	cpse		REG_TEMP_R18, REG_TEMP_R19
	rjmp		_uos_get_states_buttons_error
	; Fin: Verification pendant 'DURATION_BUTTON_ACQ' de 'G_NUM_BUTTON' @ 'G_NUM_BUTTON_PRE' si significatif

_uos_get_states_button_low_valid:

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R16, 'l'
	rcall		uos_push_1_char_in_fifo_tx
	lds		REG_X_LSB, G_NUM_BUTTON
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
#endif

	rjmp		_uos_get_states_buttons_end

_uos_get_states_buttons_all_high:
	lds		REG_TEMP_R16, G_NUM_BUTTON
	sbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_VALID_MSK
	cbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_LOW_MSK
	sbr		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_HIGH_MSK
	sts		G_NUM_BUTTON, REG_TEMP_R16

#if USE_TRACE_BUTTON
	push		REG_TEMP_R16					; Save 'REG_TEMP_R16' (G_NUM_BUTTON)
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'h'
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_X_LSB						; Print 'G_NUM_BUTTON'
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
	pop		REG_TEMP_R16					; Restore 'REG_TEMP_R16' (G_NUM_BUTTON)
#endif

	rjmp		_uos_get_states_buttons_end

_uos_get_states_buttons_error:
#if USE_TRACE_BUTTON_ERROR
	ldi		REG_TEMP_R16, 'd'
	rcall		uos_push_1_char_in_fifo_tx
	rcall		uos_print_line_feed
#endif

	clr		REG_TEMP_R16
	sts		G_NUM_BUTTON_PRE, REG_TEMP_R16
	sts		G_NUM_BUTTON, REG_TEMP_R16

   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

_uos_get_states_buttons_end:
	ret
; ---------

; ---------
; TIMER_GEST_BUTTON
;
; Chronograme de l'appui bouton avec ses anti-rebonds
;
;  (1)      (2)           (3)      (4)      (5)
; --\_/-\________________________/-\_/-\_/-------------
;
; Appui  Stabilite de l'appui    Relacher Stabilite du relacher
;
;  (1) Entree(s) dans l'It PCINT2 (Changement(s) d'etat de l'entree)
;      => Rearmement du timer a 'DURATION_WAIT_STABILITY' a chaque changement (dernier --\__ ou __/--)
;
;  (2) A l'expiration et si l'entree est a 0 => Armement du timer a 'DURATION_WAIT_ACTION'
;         State: FLG_BUTTON_WAIT_DONE
;
;  (3) A l'expiration et si l'entree est a 0 => Execution de l'action + armement du timer a 'DURATION_WAIT_ACTION'
;      (Ignore si entree a 1) permettant la prise en compte d'un appui long
;         State: FLG_STATE_BUTTON_ACTION
;
;  (4) Entree(s) dans l'It PCINT2 (Changement(s) d'etat de l'entree)
;         State: FLG_BUTTON_WAIT_DONE
;      => Rearmement du timer a 'DURATION_WAIT_STABILITY' a chaque changement (dernier --\__ ou __/--)
;
;  (5) A l'expiration et si l'entree est a 1
;      => Fin de l'appui
; ---------
_exec_timer_gest_button:
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19

	; Determination de l'entree a l'etat bas
	rcall		_uos_get_states_buttons

	; Test de coherence
#if USE_TRACE_BUTTON_ERROR
	ldi		REG_TEMP_R17, 'a'		; Preparation source de l'erreur
#endif

	lds		REG_TEMP_R16, G_NUM_BUTTON
	sbrs		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_VALID_IDX
	rjmp		_exec_timer_gest_button_error

#if USE_TRACE_BUTTON_ERROR
	ldi		REG_TEMP_R17, 'b'		; Preparation source de l'erreur
#endif

	sbrc		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_LOW_IDX
	rjmp		_exec_timer_gest_button_pin_low

	sbrc		REG_TEMP_R16, FLG_BUTTONS_1_2_3_4_HIGH_IDX
	rjmp		_exec_timer_gest_button_pin_high

#if USE_TRACE_BUTTON_ERROR
	ldi		REG_TEMP_R17, 'c'		; Preparation source de l'erreur
#endif

	rjmp		_exec_timer_gest_button_error

	; Entree du bouton a l'etat LOW
_exec_timer_gest_button_pin_low:
	; Update num button
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	lds		REG_TEMP_R17, G_NUM_BUTTON
	or			REG_TEMP_R16, REG_TEMP_R17
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R16

	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbrs		REG_TEMP_R16, FLG_BUTTON_WAIT_DONE_IDX
	rjmp		_exec_timer_gest_button_end_of_done_on
	;rjmp		_exec_timer_gest_button_end_of_stability_on

_exec_timer_gest_button_end_of_stability_on:
	sbr		REG_TEMP_R16, FLG_BUTTON_FALLING_EDGE_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16

#if USE_TRACE_BUTTON
	; Fin des rebonds a l'appui boutton
	ldi		REG_TEMP_R17, '-'
	ldi		REG_TEMP_R18, '\'
	ldi		REG_TEMP_R19, '_'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	cbr		REG_TEMP_R16, FLG_BUTTON_WAIT_DONE_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16

	; Armement a 'DURATION_WAIT_ACTION'
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON
	ldi		REG_TEMP_R18, (DURATION_WAIT_ACTION % 256)
	ldi		REG_TEMP_R19, (DURATION_WAIT_ACTION / 256)
	rcall		uos_restart_timer

	; Comptabilisation des appuis fugitifs durant 'DURATION_BUTTON_ACQ'
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_ACQ
	rcall		uos_test_timer
	brtc		_exec_timer_gest_button_end_of_stability_on_end				; Saut si timer expire

	; Repetition des appuis "courts"
	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbr		REG_TEMP_R16, FLG_BUTTON_REPEAT_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16

	; Incrementation des appuis
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH
	inc		REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH, REG_TEMP_R16

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R16, 's'
	rcall		uos_push_1_char_in_fifo_tx						; Marquage appuis "court" repetitifs
	lds		REG_X_LSB, UOS_G_STATES_BUTTON
	rcall		uos_print_1_byte_hexa							; Etats
	lds		REG_X_LSB, UOS_G_STATES_BUTTON_NBR_TOUCH
	rcall		uos_print_1_byte_hexa							; Compteur
	rcall		uos_print_line_feed
#endif
	; Fin: Incrementation des appuis
	; Fin: Comptabilisation des appuis fugitifs durant 'DURATION_BUTTON_ACQ'

_exec_timer_gest_button_end_of_stability_on_end:
	clr		REG_TEMP_R16
	sts		G_BUTTON_NBR_LONG_TOUCH, REG_TEMP_R16
	rjmp		_exec_timer_gest_button_end

_exec_timer_gest_button_end_of_done_on:
	; Le bouton est vu appuye durant 'DURATION_WAIT_ACTION' (appui "long")
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	sbr		REG_TEMP_R16, FLG_STATE_BUTTON_ACTION_MSK
	cbr		REG_TEMP_R16, FLG_STATE_BUTTON_SHORT_TOUCH_MSK
	sbr		REG_TEMP_R16, FLG_STATE_BUTTON_LONG_TOUCH_MSK
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R16

	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbr		REG_TEMP_R16, FLG_BUTTON_PRESSED_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16	

	; Incrementation des appuis "long"
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH
	inc		REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH, REG_TEMP_R16

	lds		REG_TEMP_R16, G_BUTTON_NBR_LONG_TOUCH
	inc		REG_TEMP_R16
	sts		G_BUTTON_NBR_LONG_TOUCH, REG_TEMP_R16

#if USE_TRACE_BUTTON
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'L'
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
#endif
	; Fin: Incrementation "long"

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, '_'
	ldi		REG_TEMP_R18, '_'
	ldi		REG_TEMP_R19, '_'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	; Presentation d'un flash de la Led YELLOW
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_LED
	ldi		REG_TEMP_R18, (DURATION_BUTTON_LED % 256)
	ldi		REG_TEMP_R19, (DURATION_BUTTON_LED / 256)
	rcall		uos_restart_timer

	; Armement a 'DURATION_WAIT_ACTION'
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON
	ldi		REG_TEMP_R18, (DURATION_WAIT_ACTION % 256)
	ldi		REG_TEMP_R19, (DURATION_WAIT_ACTION / 256)
	rcall		uos_restart_timer

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, 'T'
	ldi		REG_TEMP_R18, '5'
	ldi		REG_TEMP_R19, 'L'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	; Armement pour la detection des appuis "long"
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_ACQ
	ldi		REG_TEMP_R18, (DURATION_BUTTON_ACQ % 256)
	ldi		REG_TEMP_R19, (DURATION_BUTTON_ACQ / 256)
	rcall		uos_restart_timer

	rjmp		_exec_timer_gest_button_end
	; Fin: Entree du bouton a l'etat LOW

	; Entree du bouton a l'etat HIGH
_exec_timer_gest_button_pin_high:
	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbrs		REG_TEMP_R16, FLG_BUTTON_WAIT_DONE_IDX
	rjmp		_exec_timer_gest_button_end_of_done_off
	;rjmp		_exec_timer_gest_button_end_of_stability_off

_exec_timer_gest_button_end_of_stability_off:
	; Fin des rebonds au relacher du boutton
	cbr		REG_TEMP_R16, FLG_BUTTON_WAIT_DONE_MSK
	sbr		REG_TEMP_R16, FLG_BUTTON_RISING_EDGE_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16

	; Relacher de l'appui
#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, '_'
	ldi		REG_TEMP_R18, '/'
	ldi		REG_TEMP_R19, '-'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	; Le bouton est vu relache apres un appui "court" ou apres le dernier appui "long"
	; => Pas d'incrementation si dernier appui "long"

	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	sbr		REG_TEMP_R16, FLG_STATE_BUTTON_ACTION_MSK
	sbr		REG_TEMP_R16, FLG_STATE_BUTTON_SHORT_TOUCH_MSK
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R16

	; Incrementation des appuis si pas en 'FLG_STATE_BUTTON_LONG_TOUCH'
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	sbrc		REG_TEMP_R16, FLG_STATE_BUTTON_LONG_TOUCH_IDX
	rjmp		_exec_timer_gest_button_end_of_stability_off_no_inc

	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbrc		REG_TEMP_R16, FLG_BUTTON_REPEAT_IDX
	rjmp		_exec_timer_gest_button_end_of_stability_off_no_inc

	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH
	inc		REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH, REG_TEMP_R16

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R16, 'S'
	rcall		uos_push_1_char_in_fifo_tx						; Marquage "Short"
	lds		REG_X_LSB, UOS_G_STATES_BUTTON
	rcall		uos_print_1_byte_hexa							; Etats
	lds		REG_X_LSB, UOS_G_STATES_BUTTON_NBR_TOUCH
	rcall		uos_print_1_byte_hexa							; Compteur
	rcall		uos_print_line_feed
#endif
	; Fin: Incrementation des appuis si pas en 'FLG_STATE_BUTTON_LONG_TOUCH'

_exec_timer_gest_button_end_of_stability_off_no_inc:
	clr		REG_TEMP_R16
	sts		G_BUTTON_NBR_LONG_TOUCH, REG_TEMP_R16

	;rjmp		_exec_timer_gest_button_end_of_stability_off_more

_exec_timer_gest_button_end_of_stability_off_more:

	; Presentation d'un flash de la Led YELLOW
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_LED
	ldi		REG_TEMP_R18, (DURATION_BUTTON_LED % 256)
	ldi		REG_TEMP_R19, (DURATION_BUTTON_LED / 256)
	rcall		uos_restart_timer
	; Fin: Presentation d'un flash de la Led YELLOW

	; Armement pour la detection des appuis fugitifs successifs
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	sbrc		REG_TEMP_R16, FLG_STATE_BUTTON_LONG_TOUCH_IDX
	rjmp		_exec_timer_gest_button_end_of_stability_off_no_armed

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, 'T'
	ldi		REG_TEMP_R18, '5'
	ldi		REG_TEMP_R19, 'S'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON_ACQ
	ldi		REG_TEMP_R18, (DURATION_BUTTON_ACQ % 256)
	ldi		REG_TEMP_R19, (DURATION_BUTTON_ACQ / 256)
	rcall		uos_restart_timer

_exec_timer_gest_button_end_of_stability_off_no_armed:
	rjmp		_exec_timer_gest_button_end

_exec_timer_gest_button_end_of_done_off:
	; Le bouton est vu relache durant 'DURATION_WAIT_STABILITY' => Fin de(s) appui(s)
	; => Etat non detecte systematiquement

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R17, '-'
	ldi		REG_TEMP_R18, '-'
	ldi		REG_TEMP_R19, '-'
	rcall		uos_print_mark_3_char
	rcall		uos_print_line_feed
#endif

	rjmp		_exec_timer_gest_button_end
	; Fin: Entree du bouton a l'etat HIGH

_exec_timer_gest_button_error:
#if USE_TRACE_BUTTON_ERROR
	mov		REG_TEMP_R16, REG_TEMP_R17
	rcall		uos_push_1_char_in_fifo_tx
	rcall		uos_print_line_feed
#endif

   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23
	;rjmp		_exec_timer_gest_button_end

_exec_timer_gest_button_end:
	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	ret
; ---------

; ---------
; TIMER_GEST_BUTTON_LED
;
; Flash Led YELLOW a chaque prise en compte d'un appui bouton ("court" ou "long")
; ---------
_exec_ext_timer_10:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; TIMER_GEST_BUTTON_ACQ
;
; Recopie des etats d'un bouton pour traitement en fond de tache
;
; Mise a disposition si 'G_FLAGS_BUTTON'est egal a ('FLG_BUTTON_WAIT_DONE' toujours a 0):
;                D4                     D3                 D2                      D1 D0
; ----------------- ---------------------- ------------------ ----------------------- --
; FLG_BUTTON_REPEAT FLG_BUTTON_RISING_EDGE FLG_BUTTON_PRESSED FLG_BUTTON_FALLING_EDGE
;                 0                      1                  0                       1  0 => Appui "court"
;                 1                      1                  0                       1  0 => Appuis "court" successif
;                 0                      0                  1                       1  0 => 1st appui "long"
;                 0                      1                  1                       1  0 => 1st appui "long"
;                 0                      0                  1                       X  0 => Appuis "long" suivants
; ---------
_exec_timer_gest_button_acq:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	lds		REG_TEMP_R16, G_FLAGS_BUTTON

#if USE_TRACE_BUTTON
	push		REG_TEMP_R16
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'F'
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_X_LSB
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
	pop		REG_TEMP_R16
#endif

	; Appui "court" unique ?
	cpi		REG_TEMP_R16, (FLG_BUTTON_RISING_EDGE_MSK | FLG_BUTTON_FALLING_EDGE_MSK)
	breq		_exec_timer_gest_button_acq_available

	; Appuis "court" successif ?
	cpi		REG_TEMP_R16, (FLG_BUTTON_REPEAT_MSK | FLG_BUTTON_RISING_EDGE_MSK | FLG_BUTTON_FALLING_EDGE_MSK)
	breq		_exec_timer_gest_button_acq_available

	; Appuis "long" repetitifs ?
	cpi		REG_TEMP_R16, (FLG_BUTTON_PRESSED_MSK)
	breq		_exec_timer_gest_button_acq_long_touch

	; 1st appui "long" ?
	cpi		REG_TEMP_R16, (FLG_BUTTON_PRESSED_MSK | FLG_BUTTON_FALLING_EDGE_MSK)
	breq		_exec_timer_gest_button_acq_long_touch

	; 1st appui "long" ?
	cpi		REG_TEMP_R16, (FLG_BUTTON_RISING_EDGE_MSK | FLG_BUTTON_PRESSED_MSK | FLG_BUTTON_FALLING_EDGE_MSK)
	breq		_exec_timer_gest_button_acq_long_touch

	rjmp		_exec_timer_gest_button_acq_not_available

_exec_timer_gest_button_acq_long_touch:
	; Increment 'G_BUTTON_NBR_LONG_TOUCH' @ 'G_STATES_BUTTON'
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	andi		REG_TEMP_R16, (FLG_STATE_BUTTON_ACTION_MSK | FLG_STATE_BUTTON_SHORT_TOUCH_MSK | FLG_STATE_BUTTON_LONG_TOUCH_MSK)
	cpi		REG_TEMP_R16, (FLG_STATE_BUTTON_ACTION_MSK | FLG_STATE_BUTTON_SHORT_TOUCH_MSK | FLG_STATE_BUTTON_LONG_TOUCH_MSK)
	brne		_exec_timer_gest_button_acq_long_touch_more

	lds		REG_TEMP_R16, G_BUTTON_NBR_LONG_TOUCH
	inc		REG_TEMP_R16
	sts		G_BUTTON_NBR_LONG_TOUCH, REG_TEMP_R16
	; Fin: Increment 'G_BUTTON_NBR_LONG_TOUCH' @ 'G_STATES_BUTTON'

_exec_timer_gest_button_acq_long_touch_more:
	lds		REG_TEMP_R16, G_BUTTON_NBR_LONG_TOUCH
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH, REG_TEMP_R16

	; Effacement 'FLG_STATE_BUTTON_SHORT_TOUCH'
	; => Permet de gerer que les 2 etats 'FLG_STATE_BUTTON_SHORT_TOUCH' eor 'FLG_STATE_BUTTON_LONG_TOUCH'
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON
	cbr		REG_TEMP_R16, FLG_STATE_BUTTON_SHORT_TOUCH_MSK
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R16
	; Fin: Effacement 'FLG_STATE_BUTTON_SHORT_TOUCH'

_exec_timer_gest_button_acq_available:
	; Test si la notification precedente a ete acquitee
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NOTIF
	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF
	tst		REG_TEMP_R16
	brne		_exec_timer_gest_button_acq_available_error

	tst		REG_TEMP_R17
	brne		_exec_timer_gest_button_acq_available_error

	lds		REG_TEMP_R17, UOS_G_STATES_BUTTON
	sts		UOS_G_STATES_BUTTON_NOTIF, REG_TEMP_R17
	lds		REG_TEMP_R16, UOS_G_STATES_BUTTON_NBR_TOUCH
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF, REG_TEMP_R16

#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R16, 'B'
	rcall		uos_push_1_char_in_fifo_tx

	movw		REG_X_LSB, REG_TEMP_R16		; Recopie de 'G_STATES_BUTTON' et 'UOS_G_STATES_BUTTON_NBR_TOUCH'
	rcall		uos_print_2_bytes_hexa		; Trace du bouton "courant" [0x<States+Num Button><Counter>] (ie. "B[0xc301]")

	rcall		uos_print_line_feed
#endif

	rjmp		_exec_timer_gest_button_acq_end

_exec_timer_gest_button_acq_available_error:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23
	;rjmp		_exec_timer_gest_button_acq_not_available

_exec_timer_gest_button_acq_not_available:
#if USE_TRACE_BUTTON
	ldi		REG_TEMP_R16, '!'
	rcall		uos_push_1_char_in_fifo_tx

	lds		REG_X_LSB, G_FLAGS_BUTTON
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
#endif

_exec_timer_gest_button_acq_end:
	lds		REG_TEMP_R16, G_NUM_BUTTON
	sts		G_NUM_BUTTON_PRE, REG_TEMP_R16

	clr		REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON_NBR_TOUCH, REG_TEMP_R16
	sts		UOS_G_STATES_BUTTON, REG_TEMP_R16
	sts		G_FLAGS_BUTTON, REG_TEMP_R16
	sts		G_NUM_BUTTON, REG_TEMP_R16

	ret
; ---------
; ======================================================= Gestion des 4 boutons

; End of file
