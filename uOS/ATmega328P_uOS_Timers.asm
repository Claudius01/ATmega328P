; "$Id: ATmega328P_uOS_Timers.asm,v 1.5 2026/02/18 18:01:34 administrateur Exp $"

#include "ATmega328P_uOS_Timers.h"

.cseg

; ---------
; Gestion des timers
; ---------
_uos_gestion_timer:
	; Comptabilisation dans tous les timers armes
	clr		REG_TEMP_R16

	ldi		REG_Z_LSB, (_uos_vector_timer_0_program % 256)	; Table des vecteurs d'execution des taches timer
	ldi		REG_Z_MSB, (_uos_vector_timer_0_program / 256)
	ldi		REG_Y_LSB, (G_TIMER_0 % 256)				; Table des valeurs sur 16 bits des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)	

_uos_gestion_timer_loop:
	ldd		REG_X_LSB, Y+0					; X = Duree du Timer #N
	ldd		REG_X_MSB, Y+1
	adiw		REG_X_LSB, 0					; Duree ?= 0
	breq		_uos_gestion_timer_next		; Passage au prochain timer si duree a 0

_uos_gestion_timer_decrement:
	; Le Timer #N est arme et non expire => Decrementation sur 16 bits et mise a jour duree
	sbiw		REG_X_LSB, 1

	std		Y+0, REG_X_LSB
	std		Y+1, REG_X_MSB

	brne		_uos_gestion_timer_next

	; Pas d'execution de la tache associee dans l'espace PROGRAM si RESET dans l'espace BOOTLOADER
	; => Protection lors du telechargement d'un code dans l'espace PROGRAM
	rcall		_uos_if_execution_into_zone_program
	breq		_uos_gestion_timer_in_bootloader_space_more		; Saut si "pas dans l'espace PROGRAM"

	; Sauvegarde du contexte
	push		REG_TEMP_R16
	push		REG_Z_LSB
	push		REG_Z_MSB
	push		REG_Y_LSB
	push		REG_Y_MSB
	push		REG_X_LSB
	push		REG_X_MSB

	; Timer #N expire => Execution de la tache associee dans l'espace PROGRAM
_uos_gestion_timer_in_program_space:

	; Determination de l'addresse du vecteur correspondant dans l'espace PROGRAM
	ldi		REG_X_MSB, high(_uos_reset_bootloader)
	ldi		REG_X_LSB, low(_uos_reset_bootloader)
	sub		REG_Z_LSB, REG_X_LSB
	sbc		REG_Z_MSB, REG_X_MSB

	movw		REG_X_LSB, REG_Z_LSB		; Sauvegarde de l'adresse du vecteur dans l'espace PROGRAM

	; Lecture de l'opcode @ 'Z' pour savoir si le chainage est valide
	; => Presence d'un 'rjmp' a un traitement (attendu) se terminant par un 'ret' (non teste)
	lsl		REG_Z_LSB
	rol		REG_Z_MSB
	lpm		REG_TEMP_R16, Z+
	lpm		REG_TEMP_R17, Z

	; Test si 'jmp' (1001 010k kkkk 110k -> 0x940C apres masque des 'k'))
	andi		REG_TEMP_R17, 0x94
	cpi		REG_TEMP_R17, 0x94
	brne		_uos_gestion_timer_in_bootloader_space

	andi		REG_TEMP_R16, 0x0C
	cpi		REG_TEMP_R16, 0x0C
	brne		_uos_gestion_timer_in_bootloader_space

_uos_gestion_timer_exec_in_program_space:
	; Execution de la tache timer dans l'espace PROGRAM (avant celle de BOOTLOADER)
	movw		REG_Z_LSB, REG_X_LSB		; Reprise de l'adresse du vecteur dans l'espace PROGRAM
	icall

	; Timer #N expire => Execution de la tache associee dans l'espace BOOTLOADER
_uos_gestion_timer_in_bootloader_space:

	; Restauration du contexte d'avant la determination de l'addresse du vecteur
	; correspondant dans l'espace PROGRAM
	pop		REG_X_MSB
	pop		REG_X_LSB
	pop		REG_Y_MSB
	pop		REG_Y_LSB
	pop		REG_Z_MSB
	pop		REG_Z_LSB
	pop		REG_TEMP_R16

_uos_gestion_timer_in_bootloader_space_more:
	; Sauvegarde du contexte
	push		REG_TEMP_R16
	push		REG_Z_LSB
	push		REG_Z_MSB
	push		REG_Y_LSB
	push		REG_Y_MSB
	push		REG_X_LSB
	push		REG_X_MSB

	; Execution de la tache timer dans l'espace BOOTLOADER (avant celle de PROGRAM)
_uos_gestion_timer_exec_in_bootloader_space:
	icall

	; Restauration du contexte
	pop		REG_X_MSB
	pop		REG_X_LSB
	pop		REG_Y_MSB
	pop		REG_Y_LSB
	pop		REG_Z_MSB
	pop		REG_Z_LSB
	pop		REG_TEMP_R16

_uos_gestion_timer_next:
	; Passage au prochain timer
	adiw		REG_Z_LSB, 2					; Adresse du traitement associe au prochain timer
	adiw		REG_Y_LSB, 2					; Acces au prochain timer de 16 bits SANS contexte

	inc		REG_TEMP_R16					; +1 dans le compteur de timer
	cpi		REG_TEMP_R16, NBR_TIMER		; Tous les timer sont maj [#0, #1, #(NBR_TIMER - 1)] ?
	breq		_uos_gestion_timer_rtn		; TODO: Gain d'une instruction avec 'brxxx'

	rjmp		_uos_gestion_timer_loop

_uos_gestion_timer_rtn:
	ret
; ---------

; ---------
; Armement d'un timer #N avec une duree sur 16 bits
; => La duree est ajoutee a celle restante permettant ainsi un rearmement
;    avant l'expiration a l'image d'un watchdog
;    => Warning: le timer peut ne jamais expirer si plusieurs armement sans un 'uos_stop_timer'
;                car la duree est augmentee a chaque armement
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      ldi			REG_TEMP_R18, <timer_value_lsb>   ; LSB value
;      ldi			REG_TEMP_R19, <timer_value_msb>   ; MSB value
;      rcall      uos_start_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N (1st argument inchange apres execution)
;    REG_TEMP_R18        -> Duration LSB (2nd argument)
;    REG_TEMP_R19        -> Duration MSB (3rd argument)
;    REG_TEMP_R20        -> Duration LSB restante avant ajout (duree totale apres ajout)
;    REG_TEMP_R21        -> Duration MSB restante avant ajout (duree totale apres ajout)
; ---------
uos_start_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_start_timer_err				; Saut si REG_TEMP_R17 >= NBR_TIMER ?

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0				; Maj dans R20:R21 de la duree restante du timer indexe par Y
	ldd		REG_TEMP_R21, Y+1

	add		REG_TEMP_R20, REG_TEMP_R18	; Ajout de la duree passee en argument a celle restante
	adc		REG_TEMP_R21, REG_TEMP_R19

	std		Y+0, REG_TEMP_R20				; Set add duration LSB
	std		Y+1, REG_TEMP_R21				; Set add duration MSB

_uos_start_timer_rtn:
	ret

_uos_start_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; Rearmement d'un timer #N avec une duree sur 16 bits
; => La nouvelle duree remplace la duree restante correspondant a un fonctionnement
;    'uos_stop_timer' + 'uos_start_timer'
;
; Usage:
;      ldi     REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      ldi		REG_TEMP_R18, <timer_value_lsb>   ; LSB value
;      ldi		REG_TEMP_R19, <timer_value_msb>   ; MSB value
;      rcall   uos_restart_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16          -> Registre de travail
;    REG_TEMP_R17          -> Num timer #N (1st argument)
;    REG_TEMP_R18          -> Duration LSB (2nd argument)
;    REG_TEMP_R19          -> Duration MSB (3rd argument)
; ---------
uos_restart_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_restart_timer_err				; Saut si REG_TEMP_R17 >= NBR_TIMER ?

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R18				; Set add duration LSB
	std		Y+1, REG_TEMP_R19				; Set add duration MSB

_uos_restart_timer_rtn:
	ret

_uos_restart_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; Arret d'un timer #N
;
; Usage:
;      ldi     REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall   uos_stop_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16          -> Registre de travail
;    REG_TEMP_R17          -> Num timer #N (1st argument)
; ---------
uos_stop_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_stop_timer_err					; Saut si REG_TEMP_R17 >= NBR_TIMER ?

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R16				; Raz duration LSB
	std		Y+1, REG_TEMP_R16				; Raz duration MSB

_uos_stop_timer_rtn:
	ret

_uos_stop_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; Test d'un timer #N
;
; => La duree est retournee (a zero si time non arme ou expire)
;
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall      uos_test_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N (1st argument inchange apres execution)
;    REG_TEMP_R20        -> Duration LSB restante ou 0
;    REG_TEMP_R21        -> Duration MSB restante ou 0
;
; Retour:
;    Bit T de SREG   -> 0/1: Non arme ou expire / Arme en cours de decrementation
; ---------
uos_test_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_test_timer_err					; Saut si REG_TEMP_R17 >= NBR_TIMER ?

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0				; Maj dans R20:R21 de la duree restante du timer indexe par Y
	ldd		REG_TEMP_R21, Y+1

	set											; Timer a priori arme et non expire ...
	tst		REG_TEMP_R20
	brne		_uos_test_timer_rtn
	tst		REG_TEMP_R21
	brne		_uos_test_timer_rtn

	clt											; ... et non => Timer non arme ou expire

_uos_test_timer_rtn:
	ret

_uos_test_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; Maj contexte d'un timer #N
;
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>        ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      ldi			REG_TEMP_R18, <context_lsb>   	; LSB value
;      ldi			REG_TEMP_R19, <contex_msb>   		; MSB value
;      rcall      uos_set_context_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N
;    REG_TEMP_R18        -> Byte LSB du contexte LSB (2nd argument)
;    REG_TEMP_R19        -> Byte MSB du contexte MSB (3rd argument)
; ---------
uos_set_context_timer:
	cpi		REG_TEMP_R17, NBR_TIMER			; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_set_context_timer_err			; Saut si REG_TEMP_R17 >= NBR_TIMER

	push		REG_TEMP_R17						; Sauvegarde Num Timer

	ldi		REG_Y_LSB, (G_TIMER_CONTEXT_0 % 256)	; Non: Adresse de base des contextes timers
	ldi		REG_Y_MSB, (G_TIMER_CONTEXT_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R18					; Set byte context LSB
	std		Y+1, REG_TEMP_R19					; Set byte context MSB

_uos_set_context_timer_rtn:
	pop		REG_TEMP_R17						; Restauration Num Timer
	ret

_uos_set_context_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; Get context d'un timer #N
;
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall      uos_get_context_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N
;    REG_TEMP_R20        -> Byte LSB du contexte associe au timer
;    REG_TEMP_R21        -> Byte MSB du contexte associe au timer
; ---------
uos_get_context_timer:
	cpi		REG_TEMP_R17, NBR_TIMER			; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		_uos_get_context_timer_err			; Saut si REG_TEMP_R17 >= NBR_TIMER

	push		REG_TEMP_R17						; Sauvegarde Num Timer

	ldi		REG_Y_LSB, (G_TIMER_CONTEXT_0 % 256)	; Non: Adresse de base des contextes timers
	ldi		REG_Y_MSB, (G_TIMER_CONTEXT_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R16						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0					; Maj dans R18:R19 du contexte
	ldd		REG_TEMP_R21, Y+1

_uos_get_context_timer_end:
	pop		REG_TEMP_R17						; Restauration Num Timer
	ret

_uos_get_context_timer_err:
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_0:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_1:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_2:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_3:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_4:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_5:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_6:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_7:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
_uos_callback_exec_timer_8:
	ret
; ---------

; ---------
; TIMER_TEST_LEDS
; ---------
_uos_callback_exec_timer_9:
	rjmp		exec_test_leds
	ret
; ---------

; ---------
; TIMER_GEST_BUTTON_LED
; ---------
_uos_callback_exec_timer_10:
	rjmp		_exec_ext_timer_10	; TODO: Integration du code ici des que place disponible ;-)
; ---------

; ---------
; TIMER_GEST_BUTTON
; ---------
_uos_callback_exec_timer_11:
	rjmp		_exec_timer_gest_button	; TODO: Integration du code ici des que place disponible ;-)
; ---------

; ---------
; TIMER_GEST_BUTTON_ACQ
; ---------
_uos_callback_exec_timer_12:
	rjmp		_exec_timer_gest_button_acq	; TODO: Integration du code ici des que place disponible ;-)
; ---------

; ---------
; TIMER_ERROR
; ---------
_uos_callback_exec_timer_13:
	; Fin de la presentation des erreurs
	cli

	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R16, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R16, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_callback_exec_timer_13_more

	setLedRedOff

_uos_callback_exec_timer_13_more:
	sei

	ret
; ---------

; ---------
; TIMER_LED_GREEN
; ---------
_uos_callback_exec_timer_14:
	; Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0> de Led RED
	; @ contenu de 'G_TEST_ERROR' (erreur permanente a acquiter)
	; => Synchronisation avec les flash Led GREEN
	; => Inversion de la presentation si 'FLG_2_CONNECTED' affirmee ou en cours de deconnexion @ 'TIMER_CONNECT'
	lds		REG_TEMP_R16, G_TEST_ERROR
	tst		REG_TEMP_R16
	breq		_uos_callback_exec_timer_led_green_cont_d_2

	; Au moins une erreur est presente dans 'G_TEST_ERROR'
	lds		REG_TEMP_R18, G_CHENILLARD_LSB		; 'G_CHENILLARD_MSB' inutile

	; Verification 'TIMER_CONNECT' arme (deconnexion en cours)
	ldi		REG_TEMP_R17, TIMER_CONNECT
	rcall		uos_test_timer
	brts		_uos_callback_exec_timer_led_green_inversion		; Saut si timer arme

	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	sbrs		REG_TEMP_R16, FLG_2_CONNECTED_IDX
	rjmp		_uos_callback_exec_timer_led_green_cont_d

_uos_callback_exec_timer_led_green_inversion:
	com		REG_TEMP_R18					; Connexion ou en cours de deconnexion

_uos_callback_exec_timer_led_green_cont_d:
	; Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0>
	; => Evite un flash car PORTB maj toutes les 100uS
_uos_callback_exec_timer_led_red_synchro:
	cli

	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R23, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R23, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_callback_exec_timer_led_red_synchro_more

   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED	; Extinction a priori Led RED ...
	sbrc		REG_TEMP_R18, IDX_BIT0
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_RED	; ... en fait, Allumage Led RED
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23

_uos_callback_exec_timer_led_red_synchro_more:
	sei
	; Fin: Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0> de Led RED (erreur permanente a acquiter)
	; Fin: Au moins une erreur est presente dans 'G_TEST_ERROR'

_uos_callback_exec_timer_led_green_cont_d_2:
	; Recuperation du chenillard de presentation de la Led GREEN
	lds		REG_TEMP_R16, G_CHENILLARD_MSB
	lds		REG_TEMP_R17, G_CHENILLARD_LSB

	; Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0>
	cli

	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R23, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R23, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_callback_exec_timer_led_green_cont_d_2_more

   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_GREEN	      ; Extinction a priori Led GREEN ...
	sbrc		REG_TEMP_R17, IDX_BIT0
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_GREEN	      ; ... en fait, Allumage Led GREEN
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23

_uos_callback_exec_timer_led_green_cont_d_2_more:
	sei
	; Fin: Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0>

	; Progression du chenillard
	lsr		REG_TEMP_R16							; G_CHENILLARD_MSB<0> -> Carry
	ror		REG_TEMP_R17							; Carry -> G_CHENILLARD_LSB<7> et G_CHENILLARD_LSB<0> -> Carry

	cbr		REG_TEMP_R16, MSK_BIT7				; Preparation '0' dans G_CHENILLARD_MSB<7> a priori ...
	brcc		_uos_callback_exec_timer_led_green_more
	sbr		REG_TEMP_R16, MSK_BIT7				; ... et non, '1' dans G_CHENILLARD_MSB<7>

_uos_callback_exec_timer_led_green_more:				; Ici, G_CHENILLARD_MSB<7> reflete la Carry
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R17
	; Fin: Chenillard de presentation de la Led GREEN

	; Armement du Timer 'TIMER_LED_GREEN'
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	rcall		uos_start_timer

	; Compteur du chenillard [0, 1, ..., 7]
	; => Servira pour extraire les patterns en lieu et place des decalages ;-)
	lds		REG_TEMP_R16, G_COUNTER_CHENILLARD
	inc		REG_TEMP_R16
	andi		REG_TEMP_R16, 0x07
	sts		G_COUNTER_CHENILLARD, REG_TEMP_R16

	ret
; ---------

; ---------
; TIMER_CONNECT
; ---------
_uos_callback_exec_timer_15:
	; Passage en mode non connecte pour une presentation Led GREEN __/--\_____
	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	cbr		REG_TEMP_R16, FLG_2_CONNECTED_MSK
	sts		UOS_G_FLAGS_2, REG_TEMP_R16

	; Retour a la presentation "Non Connecte" @ emplacement des vecteurs d'interruption
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	andi		REG_TEMP_R16, (FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK | FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK)
	cpi		REG_TEMP_R16, FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK
	breq		_uos_callback_exec_timer_connect_bootloader

	cpi		REG_TEMP_R16, FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK
	breq		_uos_callback_exec_timer_connect_program

	ldi		REG_TEMP_R17, CHENILLARD_UNKNOWN
	rjmp		_uos_callback_exec_timer_connect_cont_d

_uos_callback_exec_timer_connect_bootloader:
	ldi		REG_TEMP_R17, CHENILLARD_BOOTLOADER
	rjmp		_uos_callback_exec_timer_connect_cont_d

_uos_callback_exec_timer_connect_program:
	ldi		REG_TEMP_R17, CHENILLARD_PROGRAM
	;rjmp		_uos_callback_exec_timer_connect_cont_d

_uos_callback_exec_timer_connect_cont_d:
	sts		G_CHENILLARD_MSB, REG_TEMP_R17
	sts		G_CHENILLARD_LSB, REG_TEMP_R17
	; Fin: Retour a la presentation "Non Connecte" @ emplacement des vecteurs d'interruption

	ret
; ---------

; End of file

