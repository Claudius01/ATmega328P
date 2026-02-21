; "$Id: ATmega328P_uOS_Uart.asm,v 1.6 2026/02/18 18:01:34 administrateur Exp $"

#include "ATmega328P_uOS_Uart.h"

.cseg

; ---------
; Gestion des FIFOs UART/Rx et UART/Tx
;
; Usages:
;      mov		REG_R5, <data>			; Donnee a ecrire
;      rcall   _uos_uart_fifo_rx|tx_write
;      => Retour: SREG<Bit> = 1 si FIFO/Rx|Tx pleine
;
;      rcall	_uos_uart_fifo_rx|tx_read
;      => Retour: Donnee dans G_STACK_RESULTS si SREG<Bit> = 1
;
; Registres utilises (non sauvegardes/restaures):
;    REG_X_LSB:REG_X_LSB -> Pointeur sur les pointeurs ecriture/lecture/data
;    REG_TEMP_R16        -> Working register
;    REG_TEMP_R17        -> Pointeur d'ecriture courant
;    REG_TEMP_R18        -> Pointeur de lecture courant
;
; Warning: Methode appelee sous l'It 'tim1_compa_isr'
; ---------
_uos_uart_fifo_rx_write:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17	; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	st			X, REG_R5			; Ecriture donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_RX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Rx non vide
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	; Indication si FIFO/Rx pleine
	; => FIFO/Rx pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, FLG_1_UART_FIFO_RX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		_uos_uart_fifo_rx_write_rtn

	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_RX_FULL_MSK		; ... et non, FIFO/Rx pleine
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	set																	; SREG<T> = 1

#if 0
	; Maj compteur d'erreurs
	rcall		update_errors
#endif

_uos_uart_fifo_rx_write_rtn:
	ret
; ---------

; ---------
_uos_uart_fifo_rx_read:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	; Sortie prematuree si rien a lire
	clt													; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		_uos_uart_fifo_rx_read_end				; Pointeurs egaux => FIFO/Rx trouvee vide

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R2, X					; Lecture de la donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]
	set										; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_RX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_READ, REG_TEMP_R18

	; Indication FIFO/Rx vide ou non vide apres la lecture
	; => FIFO/Rx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
_uos_uart_fifo_rx_read_test_empty:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	sts		UOS_G_FLAGS_1, REG_TEMP_R23
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		_uos_uart_fifo_rx_read_rtn

_uos_uart_fifo_rx_read_end:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

_uos_uart_fifo_rx_read_rtn:
	ret
; ---------

; ---------
uos_uart_fifo_tx_write:
_uos_uart_fifo_tx_write:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17			; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16			; XH += 0 + Carry

	st			X, REG_R3			; Ecriture donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_TX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Tx non vide
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	; Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier des que le pointeur d'ecriture (REG_TEMP_R17)
	; atteint le pointeur de lecture (REG_TEMP_R18) -(SIZE_UART_FIFO_TX / 2) modulo SIZE_UART_FIFO_TX
	; => Revient a vider la FIFO/Tx des que celle-ci est pleine a 50%
	;    => Au dessous des 50%, les caracteres seront emis en fond de tache grace a l'appel de 'fifo_tx_to_send_async'
	;    => Evite d'appeler dans le code la methode 'fifo_tx_to_send_sync' pour ne pas saturer la FIFO/Tx ;-)
	mov		REG_TEMP_R16, REG_TEMP_R18
	subi		REG_TEMP_R16, (SIZE_UART_FIFO_TX / 2)		; Seuil a 50 % d'occupation de la FIFO/Tx
	andi		REG_TEMP_R16, (SIZE_UART_FIFO_TX - 1)		; Modulo SIZE_UART_FIFO_TX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brne		_uos_uart_fifo_tx_write_skip

	rcall		uos_fifo_tx_to_send_sync

_uos_uart_fifo_tx_write_skip:
	; Fin: Emision de tous les caracteres de la FIFO/Tx...

	; Indication si FIFO pleine
	; => FIFO pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	sts		UOS_G_FLAGS_1, REG_TEMP_R23
	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		_uos_uart_fifo_tx_write_rtn

	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_FULL_MSK		; ... et non, FIFO/Rx pleine
	sts		UOS_G_FLAGS_1, REG_TEMP_R23
	set																	; SREG<T> = 1

#if 0
#if 1
	; Ne doit jamais arrive ;-)...
	; Mise sur voie de garage si FIFO/Tx pleine
	jmp		forever_1
	; Fin: Mise sur voie de garage si FIFO/Tx pleine
#else
	; Maj atomique du compteur d'erreurs 
	cli
	rcall		update_errors
	sei
#endif
#endif

_uos_uart_fifo_tx_write_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
_uos_uart_fifo_tx_read:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur d'ecriture courant

	; Sortie prematuree si rien a lire
	clt														; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		_uos_uart_fifo_tx_read_end					; Pas de lecture => maj flags

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R4, X			; Lecture de la donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]
	set								; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_TX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_READ, REG_TEMP_R18

	; Indication FIFO/Tx vide ou non vide apres la lecture
	; => FIFO/Tx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
_uos_uart_fifo_tx_read_test_empty:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	sts		UOS_G_FLAGS_1, REG_TEMP_R23
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		_uos_uart_fifo_tx_read_rtn

_uos_uart_fifo_tx_read_end:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

_uos_uart_fifo_tx_read_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Emission d'un caractere sur Tx
; => Initialise 'G_UART_BYTE_TX' et positionne 'FLG_1_UART_TX_TO_SEND' a 1
;
; Usage:
;      mov		REG_TEMP_R16, <data>
;      rcall   _uos_uart_tx_send
;
; Registres utilises (sauvegardes/restaures):
; ---------
_uos_uart_tx_send:
	sts		G_UART_BYTE_TX, REG_TEMP_R16

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbr		REG_TEMP_R23, FLG_0_UART_TX_TO_SEND_MSK		; Positionnement donnee a emettre
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

	ret
; ---------

; ---------
; Emission asynchrone caractere par caractere de la FIFO/Tx
;
; Remarque: Methode a appeler en fond de tache permettant de vider et
;           emettre tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Usage:
;      rcall   _uos_fifo_tx_to_send_async
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
uos_fifo_tx_to_send_async:
_uos_fifo_tx_to_send_async:
	; Caractere de la FIFO/Tx a emettre ?
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbrs		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_IDX

	rjmp		_uos_fifo_tx_to_send_async_rtn

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, FLG_0_UART_TX_TO_SEND_IDX		; Caractere emis ?

	rjmp		_uos_fifo_tx_to_send_async_rtn

	rcall		_uos_uart_fifo_tx_read					; Oui => Lecture du caractere suivant dans FIFO/Tx
	brtc		_uos_fifo_tx_to_send_async_end		; Caractere disponible ?

	mov		REG_TEMP_R16, REG_R4				; Oui => Emission de celui-ci
	rcall		_uos_uart_tx_send
	rjmp		_uos_fifo_tx_to_send_async_rtn		; Retour et attente que ce caractere soit emis...

_uos_fifo_tx_to_send_async_end:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	cbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_MSK		; Non => Arret de la demande d'emission
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

_uos_fifo_tx_to_send_async_rtn:
	ret
; ---------

; ---------
; Emission synchrone caractere par caractere jusqu'a vidage de la FIFO/Tx
;
; Remarque: Methode a appeler apres un appel a 'uos_push_1_char_in_fifo_tx'
;           => Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Permet un forcage de l'emission pour eviter la saturation de la FIFO/Tx
; => En effet, la lecture de la FIFO/Tx et l'emission ne commence qu'au
;    retour en fond de tache (cf. 'rcall fifo_tx_to_send_async')
;
; Usage:
;      rcall   _uos_fifo_tx_to_send_sync
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
uos_fifo_tx_to_send_sync:
_uos_fifo_tx_to_send_sync:
_uos_fifo_tx_to_send_sync_retry:
	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R23, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R23, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_fifo_tx_to_send_sync_retry_more

	; Presentation passage en mode synchrone de l'emission TX
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

_uos_fifo_tx_to_send_sync_retry_more:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	rcall		_uos_fifo_tx_to_send_async

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, FLG_0_UART_TX_TO_SEND_IDX				; Caractere emis ?

	rjmp		_uos_fifo_tx_to_send_sync_retry								; Non => Retry

	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbrc		REG_TEMP_R23, FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX	; FIFO/Tx vide ?

	rjmp		_uos_fifo_tx_to_send_sync_retry								; Non => Retry
	; Fin: Emission, attente FIFO/Tx vide et dernier caractere emis

	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R23, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R23, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_fifo_tx_to_send_sync_rtn

	; Fin de la presentation passage en mode synchrone de l'emission TX
	; TODO: - Si peu de caracteres ont ete empiles + vitesse rapide (ie. 19200 bauds)
	;       => Effacement premature de la presentation
	;          => Implementation d'un timer d'une duree minimale (ie. 100 mS)
	;       - Comportement constaste avec les commandes a reponse "courte"
	;         du monitor comme "<f", "<S", "<t", etc.
   lds      REG_TEMP_R23, UOS_G_PORTB_IMAGE
	sbr		REG_TEMP_R23, UOS_MSK_BIT_LED_YELLOW
   sts      UOS_G_PORTB_IMAGE, REG_TEMP_R23

_uos_fifo_tx_to_send_sync_rtn:
	ret
; ---------

; End of file
