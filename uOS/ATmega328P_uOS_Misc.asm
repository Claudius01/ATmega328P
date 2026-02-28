; "$Id: ATmega328P_uOS_Misc.asm,v 1.7 2026/02/25 16:40:59 administrateur Exp $"

; ---------
_uos_init_hard:
   ; Lecture du fusible 'LOW' pour determiner 8/16 MHz
   ldi      REG_TEMP_R16, (1 << BLBSET) | (1 << SELFPRGEN)
   out      SPMCSR, REG_TEMP_R16

   ldi      REG_Z_MSB, 0x00
   ldi      REG_Z_LSB, 0x00
   lpm      REG_TEMP_R16, Z

   andi     REG_TEMP_R16, 0x0F
   cpi      REG_TEMP_R16, (1 << CKSEL1)
   brne     _uos_init_hard_no_rc_osc_8mhz

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbr		REG_TEMP_R23, FLG_0_RC_OSC_8MHZ_MSK
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

_uos_init_hard_no_rc_osc_8mhz:
   ; Fin: Lecture du fusible 'LOW' pour determiner 8/16 MHz

	; Cadencement a xxx uS
	; TCCR1A/B: Timer/Counter1 Control Register A/B
	clr		REG_TEMP_R16
	sts		TCCR1A, REG_TEMP_R16
	sts		TCCR1B, REG_TEMP_R16

	; TCNT1H/L: Timer/Counter1
	ldi		REG_TEMP_R16, 0	
	sts		TCNT1H, REG_TEMP_R16
	sts		TCNT1L, REG_TEMP_R16

	; OCR1A: Avec un ATmega328p cadence a 16MHz (1 Cycle = 62 nS):
	; o  1600 and (CLK_IO / 1):  (16000000 / 1600)       = 10000 (10 kHz) => 100 uS
	; o 16000 and (CLK_IO / 1):  (16000000 / 16000)      =  1000 ( 1 kHz) =>   1 mS
	; o 31250 and (CLK_IO / 64): (16000000 / 31250 / 64) =     8 ( 8  Hz) => 125 mS (TBC)

   ; A priori 16 MHz ...
	ldi		REG_TEMP_R16, (1600 / 256)
	ldi		REG_TEMP_R17, (1600 % 256)

   sbrs     REG_TEMP_R23, FLG_0_RC_OSC_8MHZ_IDX
   rjmp     _uos_init_hard_ocr1a_init

   ; ... et non -> 8 MHz
	ldi		REG_TEMP_R16, (800 / 256)
	ldi		REG_TEMP_R17, (800 % 256)

_uos_init_hard_ocr1a_init:
	sts		OCR1AH, REG_TEMP_R16
	sts		OCR1AL, REG_TEMP_R17

	; TCCR1B: Timer/Counter1 Control Register B
	; - WGM12: 1: CTC mode
	; - CS12 CS11 CS10:
	;      0    0    0: No clock source
	;      0    0    1: CLK_IO / 1
	;      0    1    0: CLK_IO / 8
	;      0    1    1: CLK_IO / 64
	;      1    0    0: CLK_IO / 256
	;      1    0    1: CLK_IO / 1024
	;      1    1    0: External clock source on T1 pin. Clock on falling edge.
	;      1    1    1: External clock source on T1 pin. Clock on rising edge.

	ldi		REG_TEMP_R16, (1 << WGM12) | (1 << CS10)
	sts		TCCR1B, REG_TEMP_R16

	; TIMSK1: Timer/Counter Interrupt Mask Register
	; - OCIE1A: Timer/Counter1 Output Compare Interrupt Enable
	ldi		REG_TEMP_R16, (1 << OCIE1A)
	sts		TIMSK1, REG_TEMP_R16
	; Fin: Cadencement a xxx uS

	; Initialisation de l'UART
        ; Valeurs de programmation pour:
        ; - 4800 bauds: 208
        ; - 9600 bauds: 104
        ; - 19200 bauds: 52
	; Set baud rate (9600 bauds by default)
	ldi		REG_TEMP_R16, 0
	ldi		REG_TEMP_R17, 104     ; Valeur a 16 MHz

   sbrc     REG_TEMP_R23, FLG_0_RC_OSC_8MHZ_IDX
	ldi		REG_TEMP_R17, 52     ; Valeur a 8 MHz

	; Lecture de l'EEPROM @ TODO pour fixer la vitesse de l'UART...
	; => 'UBRR0H:UBRR0L' maj dans 'read_bauds_rate_from_eeprom' en
	;    remplacement des valeur ecrites si la valeur de l'index du
	;    'bauds rate' est supportee ;-)
	sts		UBRR0H, REG_TEMP_R16
	sts		UBRR0L, REG_TEMP_R17

	rcall		read_and_set_bauds_rate_from_eeprom

	; Enable receiver and transmitter + Rx interrupt
	ldi		REG_TEMP_R16, (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0)
	;ldi		REG_TEMP_R16, (1 << RXEN0) | (1 << TXEN0)
	sts		UCSR0B, REG_TEMP_R16

	; Set frame format: Asynchronous, 8 bits data, 2 bits stop and no parity
	ldi		REG_TEMP_R16, (1 << USBS0) | (1 << UCSZ01) | (1 << UCSZ00)
	sts		UCSR0C, REG_TEMP_R16
	; Fin: Initialisation de l'UART

	; Initialisation pour la gestion des 4 boutons sur PORTD<7:4>
	ldi		REG_TEMP_R16, (1 << PCIE2)
	sts		PCICR, REG_TEMP_R16

	ldi		REG_TEMP_R16, (1 << PCINT20) | (1 << PCINT21) | (1 << PCINT22) | (1 << PCINT23)
	sts		PCMSK2, REG_TEMP_R16
	; Fin: Initialisation pour la gestion des 4 boutons

   ; Configuration des PULLUP sur PORTD<7:4>
	ldi		REG_TEMP_R16, 0xF0
	out		PORTD, REG_TEMP_R16

	ret
; ---------

; ---------
; Test si execution dans l'espace PROGRAM
;
; Retour:
;   - Z = 1 (false): Non: Execution dans l'espace BOOTLOADER
;   - Z = 0 (true) : Oui: Execution dans l'espace PROGRAM
;
; Utilisation:
;   [r]call   _uos_if_execution_into_zone_program
;   breq      <execution_dans_l_espace_bootloader>
;
;   [r]call   _uos_if_execution_into_zone_program
;   brne      <execution_dans_l_espace_programme>
;
; ---------
_uos_if_execution_into_zone_program:
	push		REG_TEMP_R17
	lds		REG_TEMP_R17, G_STATES_AT_RESET
	andi		REG_TEMP_R17, (FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK | FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK)
	cpi		REG_TEMP_R17, FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK
	pop		REG_TEMP_R17

	ret
; ---------

; ---------
; Test si execution dans l'espace BOOTLOADER
;
; Retour:
;   - Z = 1 (false): Non: Execution dans l'espace PROGRAM
;   - Z = 0 (true) : Oui: Execution dans l'espace BOOTLOADER
;
; Utilisation:
;   [r]call   _uos_if_execution_into_zone_bootloader
;   breq      <execution_dans_l_espace_programme>
;
;   [r]call   _uos_if_execution_into_zone_program
;   brne      <execution_dans_l_espace_bootloader>
;
; ---------
_uos_if_execution_into_zone_bootloader:
	push		REG_TEMP_R17
	lds		REG_TEMP_R17, G_STATES_AT_RESET
	andi		REG_TEMP_R17, (FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK | FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK)
	cpi		REG_TEMP_R17, FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK
	pop		REG_TEMP_R17

	ret
; ---------

; ---------
_uos_presentation_connexion:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbrs		REG_TEMP_R23, FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX

	rjmp		_uos_presentation_connexion_rtn

_uos_presentation_connexion_fifo_rx_not_empty:
	; FIFO/Rx non vide
	; Test si 'Non Connecte' ?
	; => Si Oui: Changement chenillard
	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	sbrc		REG_TEMP_R16, FLG_2_CONNECTED_IDX
	rjmp		_uos_presentation_connexion_reinit_timer

	; Changement chenillard
	ldi		REG_TEMP_R16, CHENILLARD_CONNECTED
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

_uos_presentation_connexion_reinit_timer:
	; Reinitialisation timer 'TIMER_CONNECT'
	ldi		REG_TEMP_R17, TIMER_CONNECT
	ldi		REG_TEMP_R18, (3000 % 256)
	ldi		REG_TEMP_R19, (3000 / 256)
	rcall		uos_restart_timer

	; Passage en mode 'Connecte' pour une presentation Led GREEN --\__/-----
	lds		REG_TEMP_R16, UOS_G_FLAGS_2
	sbr		REG_TEMP_R16, FLG_2_CONNECTED_MSK
	;rjmp		_uos_presentation_connexion_rtn

	; Fin: Passage en mode 'Non Connecte' a l'expiration du timer 'TIMER_CONNECT'

_uos_presentation_connexion_rtn:
	ret
; ---------

; ---------
; Allumage fugitif Led RED Externe si erreur
; => L'effacement des 2 'FLG_0_UART_RX_BYTE_START_ERROR' et 'FLG_0_UART_RX_BYTE_STOP_ERROR'
;    est effectue sur la reception d'un nouveau caratere sans erreur ;-)
;    => L'allumage peut durer au dela de la valeur d'initialisation du timer 'TIMER_ERROR'
;       et donc ne pas presenter d'autres erreurs a definir
;       => Choix: Effacement sur time-out de 'TIMER_CONNECT'
;
; => L'effacement des 2 'FLG_1_UART_FIFO_RX_FULL' et 'FLG_1_UART_FIFO_TX_FULL'
;    est effectue des lors que la FIFO/Rx ou Tx n'est plus "vue" comme pleine
;    => Des carateres peuvent avoir ete perdus dans l'empilement dans la FIFO
;
_uos_presentation_error:
	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbrc		REG_TEMP_R23, FLG_1_UART_FIFO_RX_FULL_IDX
	rjmp		_uos_presentation_error_reinit

	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS			; Prise des flags 'UOS_G_TEST_FLAGS'

	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_IDX
	rjmp		_uos_presentation_error_reinit

	sbrc		REG_TEMP_R16, FLG_TEST_CONFIG_ERROR_IDX
	rjmp		_uos_presentation_error_reinit

	sbrc		REG_TEMP_R16, FLG_TEST_PROGRAMING_ERROR_IDX
	rjmp		_uos_presentation_error_reinit

	sbrc		REG_TEMP_R16, FLG_TEST_EEPROM_ERROR_IDX
	rjmp		_uos_presentation_error_reinit

	rjmp		_uos_presentation_error_rtn

_uos_presentation_error_reinit:
	; Reinitialisation timer 'TIMER_ERROR' tant que erreur(s) presente(s)
	ldi		REG_TEMP_R17, TIMER_ERROR
	ldi		REG_TEMP_R18, (200 % 256)
	ldi		REG_TEMP_R19, (200 / 256)
	rcall		uos_restart_timer

	; Effacement de certaines erreurs non fugitives
	lds		REG_TEMP_R16, UOS_G_TEST_FLAGS 
	cbr		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_MSK
	cbr		REG_TEMP_R16, FLG_TEST_CONFIG_ERROR_MSK
	sts		UOS_G_TEST_FLAGS, REG_TEMP_R16

	cli

	; Pas de changement de l'etat Led si "Test Leds en cours"
	lds		REG_TEMP_R16, UOS_G_GESTION_TEST_LEDS
	sbrc		REG_TEMP_R16, FLG_GESTION_TEST_LEDS_IDX
	rjmp		_uos_presentation_error_more

	setLedRedOn

_uos_presentation_error_more:
	sei

_uos_presentation_error_rtn:
	ret
; ---------

; ---------
; Affirmation de l'erreur a acquiter maj depuis 'C' defini
;
; Usage:
;    call  uos_set_error
; ---------
uos_set_error:
	lds		REG_TEMP_R24, G_TEST_ERROR	; Reprise de l'erreur
	sbr		REG_TEMP_R24, FLG_TEST_ERR_EXTERNAL_MSK	; Caracteres mis en FIFO a emettre ;-)

	sts		G_TEST_ERROR, REG_TEMP_R24	; Update de l'erreur
	ret
; ---------

; End of file
