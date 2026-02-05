; "$Id: ATmega328P_uOS.asm,v 1.19 2026/02/04 16:21:42 administrateur Exp $"

; - Projet: ATmega328P_uOS
;
; - r1.1: Continuite du projet 'ATmega328P_uOS_P1'
;         => Production sur Ubuntu-LinuxShop a partir des outils de Ubuntu-Dell + Sources...

; 2024/06/10 - Change 'rjmp uos_main_program' to 'jmp  0x0000' into 'ATmega328P_uOS_P4.sub' file
; 2024/06/17 - Add define 'USE_TABLES_WORDS' pour passage des tables de 'callback' en 'jmp'
;              => Facilite le codage en Langage C des ces tables ;-)
; 2024/06/21 - Add 'callback_init' method
; 2024/06/21 - Suppression du code inutilise pour gagner de la place
; 2024/06/22 - Suppression de 'REG_PORTB_OUT' au profit de 'UOS_G_PORTB_IMAGE'
; 2024/06/21 - Suppressions de 'REG_FLAGS_0' au profit de 'REG_TEMP_R24'
;              et 'REG_FLAGS_1' au profit de 'REG_TEMP_R25'
; 2024/10/07 - Suppression de '_uos_valid_address_range_2_from' en doublon de 'uos_tim1_compa_isr_program'
;              => Empeche la simulation du fait de 'uos_tim1_compa_isr_program' non referencee ;-(
;            - Ajustement a 100 uS exactement (Prise en compte de la mS a l'It suivante ;-)
;              => Cf. 'ATmega328P_uOS_P4.sub'
; 2024/10/09 - Insertion d'un 'nop' entre les labels definis a la meme adresse
; 2024/10/20   => Retour en arriere (acceptation des labels definis a la meme adresse ;-)

; 2025/08/20   => Reprise du projet 'P6' avec les ajouts de 'P7' (commande <f, ...)
; 2025/09/25   => Passage a 19200 bauds pour une utilisation avec le projet
;                 '/home/administrateur/Documents/Technique/Projects/Dev/UNO/SerialMonitor'

; 2026/01    - Reprise du projet 'ATmega328P_monitor_P8A' + reorganisation
;            - Suppression de l'appel a 'uos_print_blocking_string'
;            - Accueil du test leds en fond de tache
;              => TODO: Programmation de la flash pertubee a cause de la relance du code
;                       entrainant des erreurs d'ecriture ;-((

.include		"m328Pdef.inc"              ; Labels and identifiers for ATmega328p
.include		"ATmega328P_uOS.h"

.cseg

; Vecteurs d'interruption dans le cas du fusible BOOTRST = 0
; + padding a 64 opcodes pour preparer une reprogrammation

.org	0x0000 

reset_addr_0x0:
	jmp		uos_main_program							; # 1 RESET
	jmp		_uos_invalid_it_slow						; # 2 INT0
	jmp		_uos_invalid_it_slow						; # 3 INT1
	jmp		_uos_invalid_it_slow						; # 4 PCINT0
	jmp		_uos_invalid_it_slow						; # 5 PCINT1
	jmp		_uos_invalid_it_slow						; # 6 PCINT2	; Pas de vecteur 'pcint2_isr_program' defini
	jmp		_uos_invalid_it_slow						; # 7 WDT
	jmp		_uos_invalid_it_slow						; # 8 TIMER2 COMPA
	jmp		_uos_invalid_it_slow						; # 9 TIMER2 COMPB
	jmp		_uos_invalid_it_slow						; #10 TIMER2 OVF
	jmp		_uos_invalid_it_slow						; #11 TIMER1 CAPT
	jmp		uos_tim1_compa_isr_program				; #12 TIMER1 COMPA
	jmp		_uos_invalid_it_slow						; #13 TIMER1 COMPB
	jmp		_uos_invalid_it_slow						; #14 TIMER1 OVF
	jmp		_uos_invalid_it_slow						; #15 TIMER0 COMPA
	jmp		_uos_invalid_it_slow						; #16 TIMER0 COMPB
	jmp		_uos_invalid_it_slow						; #17 TIMER0 OVF
	jmp		_uos_invalid_it_slow						; #18 SPI, SPC
	jmp		uos_usart_rx_complete_isr_program	; #19 USART, RX
	jmp		_uos_invalid_it_slow						; #20 USART, UDRE
	jmp		_uos_invalid_it_slow						; #21 USART, TX
	jmp		_uos_invalid_it_slow						; #22 ADC
	jmp		_uos_invalid_it_slow						; #23 EE READY
	jmp		_uos_invalid_it_slow						; #24 ANALOG COMP
	jmp		_uos_invalid_it_slow						; #25 TWI
	jmp		_uos_invalid_it_slow						; #26 SPM READY

; Reservation 2 bytes pour s'aligner sur le 'main' du Langage C
	jmp		_uos_forever	; Ne sera jamais execute (adresse du 'main()' d'un programme C)

_uos_vector_timer_0_bootloader:
; ---------
; Table des 16 vecteurs d'execution non initialisee des taches timer codees dans l'espace PROGRAM
; ---------
	nop		; Adresse de la tache du Timer #0  ('_uos_callback_exec_timer_0')
	nop
	nop		; Adresse de la tache du Timer #1  ('_uos_callback_exec_timer_1')
	nop
	nop		; Adresse de la tache du Timer #2  ('_uos_callback_exec_timer_2')
	nop
	nop		; Adresse de la tache du Timer #3  ('_uos_callback_exec_timer_3')
	nop
	nop		; Adresse de la tache du Timer #4  ('_uos_callback_exec_timer_4')
	nop
	nop		; Adresse de la tache du Timer #5  ('_uos_callback_exec_timer_5')
	nop
	nop		; Adresse de la tache du Timer #6  ('_uos_callback_exec_timer_6')
	nop
	nop		; Adresse de la tache du Timer #7  ('_uos_callback_exec_timer_7')
	nop
	nop		; Adresse de la tache du Timer #8  ('_uos_callback_exec_timer_8')
	nop
	nop		; Adresse de la tache du Timer #9  ('_uos_callback_exec_timer_9')
	nop
	nop		; Adresse de la tache du Timer #10 ('_uos_callback_exec_timer_10')
	nop
	nop		; Adresse de la tache du Timer #11 ('_uos_callback_exec_timer_11')
	nop
	nop		; Adresse de la tache du Timer #12 ('_uos_callback_exec_timer_12')
	nop
	nop		; Adresse de la tache du Timer #13 ('_uos_callback_exec_timer_13')
	nop
	nop		; Adresse de la tache du Timer #14 ('_uos_callback_exec_timer_14')
	nop
	nop		; Adresse de la tache du Timer #15 ('_uos_callback_exec_timer_15')
	nop
; ---------

; ---------
; Table des 6 vecteurs d'execution non initialisee des "callback" du BOOTLOADER
; ---------
	nop		; Adresse '_uos_callback_init'
	nop
	nop		; Adresse '_uos_callback_background'
	nop
	nop		; Adresse '_uos_callback_tick'
	nop
	nop		; Adresse '_uos_callback_1_ms'
	nop
	nop		; Adresse '_uos_callback_gest_buttons'
	nop
	nop		; Adresse '_uos_callback_command'
	nop

; ---------
; Padding a 128 mots pour la programmation des 1st et 2nd pages...
; ---------
	; 8 mots
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	; 7 mots
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

.org	0x3580 

; ---------
; Adresse de programmation possible d'une page de 64 instructions
; dans l'implementation de 'ATmega328P.ext' qui sera supprime a terme
; ou de 'ATmega328P.addons' qui precise les vecteurs d'interruptions
; et les vecteur de prolongation...
;
; => WARNING: '_uos_valid_address_range_1_to' devra etre defini dans 'ATmega328P_uOS_P1.addons'
;             pour un bon fonctionnement de la commande "<dAAAA-BBBB" qui permet de
;             de reprogrammer une page de 64 opcodes de derivation ;-)
; ---------

; ---------
uos_main_program:
	; Marquage de l'origine du RESET (Espace PROGRAM)
	clr		REG_TEMP_R16
	sbr		REG_TEMP_R16, FLG_STATE_AT_RESET_PROGRAM_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16

	; Vecteurs d'interruption dans la section PROGRAM
	; Enable change of Interrupts Vectors
	ldi	REG_TEMP_R16, (1 << IVCE)
	out	MCUCR, REG_TEMP_R16

	; Move interrupts to Program section
	clr	REG_TEMP_R16
	out	MCUCR, REG_TEMP_R16
	; End: Enable change of Interrupts Vectors

	rjmp		_uos_main

_uos_main_bootloader:
	; Marquage de l'origine du RESET (Espace BOOTLOADER)
	clr		REG_TEMP_R16
	sbr		REG_TEMP_R16, FLG_STATE_AT_RESET_BOOTLOADER_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16

	; Vecteurs d'interruption dans la section BOOTLOADER
	; Enable change of Interrupts Vectors
	ldi	REG_TEMP_R16, (1 << IVCE)
	out	MCUCR, REG_TEMP_R16

	; Move interrupts to Boot Flash section
	ldi	REG_TEMP_R16, (1 << IVSEL)
	out	MCUCR, REG_TEMP_R16
	; Fin: Vecteurs d'interruption dans la section BOOTLOADER

	;rjmp		main

_uos_main:
	rcall		_uos_init_sram_fill		; Initialisation de la SRAM	
	rcall		_uos_init_sram_values	; Initialisation de valeurs particulieres

	; Test Leds avant l'initialisation hard
	; Sortie Leds et de la Pulse IT
	; => Warning: La Led BLUE est partagee avec le TX
	;             => Le port correspondant sera remis en Input pour ne pas "ecrase" la signal d'emission ;-)
	ldi		REG_TEMP_R16, (1 << UOS_IDX_BIT_LED_RED) | (1 << UOS_IDX_BIT_LED_GREEN) | (1 << UOS_IDX_BIT_LED_YELLOW) | (1 << UOS_IDX_BIT_LED_BLUE) | (1 << IDX_BIT_PULSE_IT)
	out		DDRB, REG_TEMP_R16

	; Extinction des 4 Leds BLUE, RED, GREEN et YELLOW et de leur image
	ldi		REG_TEMP_R23, (UOS_MSK_BIT_LED_RED | UOS_MSK_BIT_LED_GREEN | UOS_MSK_BIT_LED_YELLOW | UOS_MSK_BIT_LED_BLUE)
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23					; Raffraichissement du PORTB

	rcall		_uos_init_hard			; Initialisation du materiel
	rcall		read_and_test_magic_const
	rcall		init_test_leds			; Lancement du test led en fond de tache

	; Initialisation timer 'TIMER_LED_GREEN' pour le chenillard Led GREEN 
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	rcall		uos_start_timer

	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbrs		REG_TEMP_R16, FLG_STATE_AT_RESET_PROGRAM_IDX
	rjmp		_uos_main_prompt_more

_uos_main_prompt_program:
	; Preparation du "Hello World"
	ldi		REG_Z_MSB, high(_uos_text_program << 1)
	ldi		REG_Z_LSB, low(_uos_text_program << 1)
	rjmp		_uos_main_more

_uos_main_prompt_more:
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbrs		REG_TEMP_R16, FLG_STATE_AT_RESET_BOOTLOADER_IDX
	rjmp		_uos_main_more

_uos_main_prompt_bootloader:
	; Preparation du prompt "Bootloader"
	ldi		REG_Z_MSB, high(_uos_text_bootloader << 1)
	ldi		REG_Z_LSB, low(_uos_text_bootloader << 1)

_uos_main_more:
	; Initialisation du CHENILLARD @ emplacement des vecteurs d'interruption a l'expiration de 'TIMER_CONNECT'
   ldi      REG_TEMP_R17, TIMER_CONNECT
   ldi      REG_TEMP_R18, (100 % 256)
   ldi      REG_TEMP_R19, (100 / 256)
   rcall    uos_start_timer

	; Set all interruptions car emission sur l'It de cadencement ;-)
	sei

	; Print du prompt "Bootloader" eor "Hello World"
	rcall		uos_push_text_in_fifo_tx

	; Print de '_uos_text_prompt'
	ldi		REG_Z_MSB, high(_uos_text_prompt << 1)
	ldi		REG_Z_LSB, low(_uos_text_prompt << 1)
	rcall		uos_push_text_in_fifo_tx

	; Print de la frequence 8/16 MHz @ FLG_0_RC_OSC_8MHZ
	rcall		uos_print_frequency

	; Print des informations de l'EEPROM
	rcall		uos_set_infos_from_eeprom

	; Forcage de l'emission...
	rcall		uos_fifo_tx_to_send_sync

#if 1
	; Attente forfaitaire de plus de 100uS pour la maj des flags
	; 'FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER' eor 'FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM'
	ldi		REG_TEMP_R16, 80
	rcall		_uos_delay_big_more		; TODO: _uos_delay_big_2 (REG_TEMP_R17 non initialise ;-)
#endif

	; ---------
	; Prolongement de l'initialisation si le code est execute au RESET depuis
	; l'espace PROGRAM et si le vecteur commence par l'instruction 'rjmp'
	; ---------
	ldi		REG_Z_MSB, high(_uos_callback_init)	; Execution si possible de l'extension
	ldi		REG_Z_LSB, low(_uos_callback_init)	; dans l'espace PROGRAM
	rcall		_uos_exec_extension_into_program
	; ---------

_uos_main_loop:
	; Gestion de l'attente expiration des 1ms
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrs		REG_TEMP_R23, FLG_0_PERIODE_1MS_IDX		; 1mS expiree ?

	rjmp		_uos_main_loop_more									; Non

	; --- Traitements toutes les 1mS
	; => Expiration de 1mS => Nouvelle periode de 1mS
	; => call 'gestion_timer' (execution du traitement associe a chaque timer qui expire)
	; => reinitialisation 'G_TICK_1MS' (copie atomique ;-)
	; => Effacement 'FLG_0_PERIODE_1MS' -> Relance de la comptabilisation des 1mS
	; => Comptabilisation des mS a concurence de 1 Sec pour la synchronisation du timer
	;    d'erreur sur celui de 'TIMER_LED_GREEN'

	lds		REG_TEMP_R17, G_TICK_1MS_INIT
	sts		G_TICK_1MS, REG_TEMP_R17

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	cbr		REG_TEMP_R23, FLG_0_PERIODE_1MS_MSK
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

	lds		REG_X_MSB, G_COUNTER_1MS_MSB
	lds		REG_X_LSB, G_COUNTER_1MS_LSB
	adiw		REG_X_LSB, 1
	sts		G_COUNTER_1MS_MSB, REG_X_MSB
	sts		G_COUNTER_1MS_LSB, REG_X_LSB
	cpi		REG_X_LSB, (1000 % 256)
	brne		_uos_main_loop_cont_d
	cpi		REG_X_MSB, (1000 / 256)
	brne		_uos_main_loop_cont_d

	clr		REG_TEMP_R16
	sts		G_COUNTER_1MS_MSB, REG_TEMP_R16
	sts		G_COUNTER_1MS_LSB, REG_TEMP_R16

_uos_main_loop_cont_d:

	rcall		_uos_gestion_timer		; Gestion des timers

	; Presentation sur Led GREEN mode "Connecte/Non Connecte"
	rcall		_uos_presentation_connexion

	; Gestion des 4 boutons par PROGRAM (en 1st lieu) et par BOOTLOADER (si pas acquite)
	rcall		_uos_gest_buttons

	; ---------
	; Prolongement des traitements 1mS si le code est execute au RESET depuis
	; l'espace PROGRAM et si le vecteur commence par l'instruction 'rjmp'
	; ---------
	ldi		REG_Z_MSB, high(_uos_callback_1_ms)	; Execution si possible de l'extension
	ldi		REG_Z_LSB, low(_uos_callback_1_ms)	; dans l'espace PROGRAM
	rcall		_uos_exec_extension_into_program
	; ---------

	; Interpretation de la commande recue
	rcall		_uos_interpret_command

	; Fin: --- Traitements toutes les 1mS

_uos_main_loop_more:
	; Test et emission eventuelle d'un caractere de la FIFO/Tx
	; => Effectue des que possible des lors que 'FLG_1_UART_FIFO_TX_TO_SEND'
	;    est a 1 et que 'FLG_0_UART_TX_TO_SEND' est a 0
	;    => Traitement en fond de tache pour cadencer l'emission au max des 9600 bauds
	rcall		_uos_fifo_tx_to_send_async

	; Presentation erreurs sur Led RED Externe
	rcall		_uos_presentation_error

	; ---------
	; Prolongement si le code est execute au RESET depuis l'espace PROGRAM et
	; si le vecteur commence par l'instruction 'rjmp'
	; ---------
	ldi		REG_Z_MSB, high(_uos_callback_background)	; Execution si possible de l'extension
	ldi		REG_Z_LSB, low(_uos_callback_background)	; dans l'espace PROGRAM
	rcall		_uos_exec_extension_into_program
	; ---------

	rjmp		_uos_main_loop

_uos_forever:
	cli
	setLedRedOn

_uos_forever_loop:	
	rjmp		_uos_forever_loop

; ---------
; Mise sur voie de garage avec clignotement "lent" ou "rapide" de la Led RED
; ---------
_uos_awaiting_prog:
	cli
	ldi		REG_TEMP_R16, 5
	rjmp		_uos_invalid_it_leds_off

_uos_invalid_it_speed:
	cli
	ldi		REG_TEMP_R16, 20
	rjmp		_uos_invalid_it_more

_uos_invalid_it_slow:
	cli
	ldi		REG_TEMP_R16, 80

_uos_invalid_it_more:
	; Memorisation du numero de l'It non attendue dans l'espace bootloader
	sbr		REG_TEMP_R17, UOS_FLG_WRONG_IT_BOOLOADER_MSK
	cbr		REG_TEMP_R17, UOS_FLG_WRONG_IT_PROGRAM_MSK
	sts		UOS_G_STATES_POST_MORTEM, REG_TEMP_R17

_uos_invalid_it_leds_off:
	; Extinction de toutes les Leds
	setLedsOff

_uos_invalid_it_loop:
	push		REG_TEMP_R16			; Save/Restore temporisation dans REG_TEMP_R16
	setLedRedOn
	rcall		uos_delay_big_2
	pop		REG_TEMP_R16
	push		REG_TEMP_R16
	setLedRedOff
	rcall		uos_delay_big_2
	pop		REG_TEMP_R16
	rjmp		_uos_invalid_it_loop
; ---------

; ---------
; Execution du prolongement dans l'espace PROGRAM si
; - RESET depuis l'espace PROGRAM
; - Opcode 'rjmp' trouve en 1st instruction du code a executer en prolongement
;
; Input: 'Z': Adresse du vecteur d'execution du prolongement
; ---------
_uos_exec_extension_into_program:
	; Code execute depuis l'espace PROGRAM ?
	rcall		_uos_if_execution_into_zone_program
	breq		_uos_exec_extension_into_program_end		; Saut si "pas dans l'espace PROGRAM"

	; Determination de l'addresse du vecteur correspondant dans l'espace PROGRAM
	ldi		REG_X_MSB, high(_uos_reset_bootloader)
	ldi		REG_X_LSB, low(_uos_reset_bootloader)
	sub		REG_Z_LSB, REG_X_LSB
	sbc		REG_Z_MSB, REG_X_MSB		; 'Z' contient l'adresse de l'extension

	movw		REG_X_LSB, REG_Z_LSB		; Sauvegarde de l'adresse du vecteur dans l'espace PROGRAM

	; Lecture de l'opcode @ 'Z' pour savoir si le chainage est valide
	; => Presence d'un 'rjmp' a un traitement (teste) se terminant par un 'ret' (non teste)
	;    car appele avec 'icall'
	lsl		REG_Z_LSB
	rol		REG_Z_MSB
	lpm		REG_TEMP_R16, Z+
	lpm		REG_TEMP_R17, Z

	; Test si 'jmp' (1001 010k kkkk 110k -> 0x940C apres masque des 'k'))
	andi		REG_TEMP_R17, 0x94
	cpi		REG_TEMP_R17, 0x94
	brne		_uos_exec_extension_into_program_end

	andi		REG_TEMP_R16, 0x0C
	cpi		REG_TEMP_R16, 0x0C
	brne		_uos_exec_extension_into_program_end

	; Execution de l'extension dans l'espace PROGRAM
	movw		REG_Z_LSB, REG_X_LSB		; Reprise de l'adresse du vecteur dans l'espace PROGRAM
	icall

_uos_exec_extension_into_program_end:
	ret
; ---------

; ---------
; delay de 5uS ou 10uS environ avec un ATmega328p 16MHz (62 nS)
; => Mesure a l'oscilloscope:  8uS au lieu de   5S
; => Mesure a l'oscilloscope: 13uS au lieu de 10uS
;
derivation_delay_5uS:
_uos_delay_5uS:
	ldi		REG_TEMP_R16, 10
	rjmp		_uos_delay_loop

_uos_delay_10uS:
	ldi		REG_TEMP_R16, 20
	;rjmp		_uos_delay_loop

uos_derivation_delay_5uS_cont_d:
_uos_delay_loop:
	nop								;   1
	nop								; + 1
	nop								; + 1
	nop								; + 1
	nop								; + 1

	dec		REG_TEMP_R16		; + 1
	brne		_uos_delay_loop			; + 2 = 8 => 160 cycles => 9.92 uS

	ret
; ---------

; ---------
; uos_save_reg_r0_r31
; => Ecriture dans la SRAM des 32 registres 'r0' a 'r32'
;    pour une utilisation depuis un programme C
; ---------
uos_save_reg_r0_r31:
	sts		UOS_G_SAVE_R0, r0
	sts		UOS_G_SAVE_R1, r1
	sts		UOS_G_SAVE_R2, r2
	sts		UOS_G_SAVE_R3, r3
	sts		UOS_G_SAVE_R4, r4
	sts		UOS_G_SAVE_R5, r5
	sts		UOS_G_SAVE_R6, r6
	sts		UOS_G_SAVE_R7, r7
	sts		UOS_G_SAVE_R8, r8
	sts		UOS_G_SAVE_R9, r9
	sts		UOS_G_SAVE_R10, r10
	sts		UOS_G_SAVE_R11, r11
	sts		UOS_G_SAVE_R12, r12
	sts		UOS_G_SAVE_R13, r13
	sts		UOS_G_SAVE_R14, r14
	sts		UOS_G_SAVE_R15, r15
	sts		UOS_G_SAVE_R16, r16
	sts		UOS_G_SAVE_R17, r17
	sts		UOS_G_SAVE_R18, r18
	sts		UOS_G_SAVE_R19, r19
	sts		UOS_G_SAVE_R20, r20
	sts		UOS_G_SAVE_R21, r21
	sts		UOS_G_SAVE_R22, r22
	sts		UOS_G_SAVE_R23, r23
	sts		UOS_G_SAVE_R24, r24
	sts		UOS_G_SAVE_R25, r25
	sts		UOS_G_SAVE_R26, r26
	sts		UOS_G_SAVE_R27, r27
	sts		UOS_G_SAVE_R28, r28
	sts		UOS_G_SAVE_R29, r29
	sts		UOS_G_SAVE_R30, r30
	sts		UOS_G_SAVE_R31, r31

	ret
; ---------

; --------r0, -
; uos_restore_reg_r0_r31
; => Restauration depuis la pile des 32 registres
;    pour une utilisation depuis un programme C
; ---------
uos_restore_reg_r0_r31:
	lds		r0, UOS_G_SAVE_R0
	lds		r1, UOS_G_SAVE_R1
	lds		r2, UOS_G_SAVE_R2
	lds		r3, UOS_G_SAVE_R3
	lds		r4, UOS_G_SAVE_R4
	lds		r5, UOS_G_SAVE_R5
	lds		r6, UOS_G_SAVE_R6
	lds		r7, UOS_G_SAVE_R7
	lds		r8, UOS_G_SAVE_R8
	lds		r9, UOS_G_SAVE_R9
	lds		r10, UOS_G_SAVE_R10
	lds		r11, UOS_G_SAVE_R11
	lds		r12, UOS_G_SAVE_R12
	lds		r13, UOS_G_SAVE_R13
	lds		r14, UOS_G_SAVE_R14
	lds		r15, UOS_G_SAVE_R15
	lds		r16, UOS_G_SAVE_R16
	lds		r17, UOS_G_SAVE_R17
	lds		r18, UOS_G_SAVE_R18
	lds		r19, UOS_G_SAVE_R19
	lds		r20, UOS_G_SAVE_R20
	lds		r21, UOS_G_SAVE_R21
	lds		r22, UOS_G_SAVE_R22
	lds		r23, UOS_G_SAVE_R23
	lds		r24, UOS_G_SAVE_R24
	lds		r25, UOS_G_SAVE_R25
	lds		r26, UOS_G_SAVE_R26
	lds		r27, UOS_G_SAVE_R27
	lds		r28, UOS_G_SAVE_R28
	lds		r29, UOS_G_SAVE_R29
	lds		r30, UOS_G_SAVE_R30
	lds		r31, UOS_G_SAVE_R31

	ret
; ---------

; ---------
; Print de la frequence 8/16 MHz @ FLG_0_RC_OSC_8MHZ
; ---------
uos_print_frequency:
	; A priori 16 MHz
	ldi		REG_Z_MSB, high(_uos_text_frequency_16_mhz << 1)
	ldi		REG_Z_LSB, low(_uos_text_frequency_16_mhz << 1)

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrs		REG_TEMP_R23, FLG_0_RC_OSC_8MHZ_IDX

	rjmp		uos_print_frequency_end

	ldi		REG_Z_MSB, high(_uos_text_frequency_8_mhz << 1)
	ldi		REG_Z_LSB, low(_uos_text_frequency_8_mhz << 1)

uos_print_frequency_end:
	rcall		uos_push_text_in_fifo_tx

	ret
; ---------

; ---------
; uos_delay_big
; => Delay "long" de duree fixe @ REG_TEMP_R16, REG_TEMP_R17 et REG_TEMP_R18
;
; uos_delay_big_2(REG_TEMP_R16)
; => Ne doit pas etre appelee sous It
;
uos_delay_big:
	ldi		REG_TEMP_R16, 40

uos_delay_big_2:
	ldi		REG_TEMP_R17, 125

_uos_delay_big_more:
#if USE_AVRSIMU
	ret									; Bypass de la "longue" attente pour la simulation
#else
	ldi		REG_TEMP_R18, 250
#endif

_uos_delay_big_more_1:
	dec		REG_TEMP_R18
	nop									; Wait 1 cycle
	brne		_uos_delay_big_more_1
	dec		REG_TEMP_R17
	brne		_uos_delay_big_more
	dec		REG_TEMP_R16
	brne		uos_delay_big_2
	ret
; ---------

; ---------
; Test Leds suivant la sequence definie par 'text_test_leds'
;
; - 'init_test_leds': Armorce du test
; - 'exec_test_leds': Progression du test a l'expiration du timer dedie
;   => 'exec_test_leds' doit imperativement etre implemente apres 'init_test_leds'
; ---------
init_test_leds:
; ---------
	ldi		REG_TEMP_R16, FLG_GESTION_TEST_LEDS_MSK
	sts		UOS_G_GESTION_TEST_LEDS, REG_TEMP_R16
; ---------

; ---------
; Cadencement des allumages/extinctions des Leds
; ---------
exec_test_leds:
; ---------
	ldi		REG_Z_MSB, high(mask_for_test_leds << 1)
	ldi		REG_Z_LSB, low(mask_for_test_leds << 1)
	lds		REG_TEMP_R16, UOS_G_GESTION_TEST_LEDS
	andi		REG_TEMP_R16, ~FLG_GESTION_TEST_LEDS_MSK & 0xFF		; '& 0xFF' pour eviter un warning ;-)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17
	lpm      REG_TEMP_R17, Z					; 'REG_TEMP_R17' = Etat et masques d'affichage

	sbrs		REG_TEMP_R17, FLG_GESTION_TEST_LEDS_IDX
	rjmp		exec_test_leds_end

exec_test_leds_refresh:
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R17		; Update Leds...

	lds		REG_TEMP_R16, UOS_G_GESTION_TEST_LEDS	; Update progression...
	inc		REG_TEMP_R16								; Next test
	sts		UOS_G_GESTION_TEST_LEDS, REG_TEMP_R16

	rjmp		exec_test_leds_more

exec_test_leds_end:
	; End of the test
	clr		REG_TEMP_R16
	sts		UOS_G_GESTION_TEST_LEDS, REG_TEMP_R16
	rjmp		exec_test_leds_rtn

exec_test_leds_more:
	; Continue the test
	; Reinitialisation timer 'TIMER_TEST_LEDS'
	ldi		REG_TEMP_R17, TIMER_TEST_LEDS
	ldi		REG_TEMP_R18, (DURATION_TIMER_TEST_LEDS % 256)
	ldi		REG_TEMP_R19, (DURATION_TIMER_TEST_LEDS / 256)
	call		uos_start_timer

exec_test_leds_rtn:
	ret
; ---------
; Fin: Test Leds suivant la sequence definie par 'text_test_leds'
; ---------

; ---------
; Lecture des 2 bytes a l'adresse '_uos_magic_const'...
; ---------
read_and_test_magic_const:
	ldi		REG_Z_MSB, high(_uos_magic_const << 1)
	ldi		REG_Z_LSB, low(_uos_magic_const << 1)
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, 0xFF
	brne		read_and_test_magic_const_more
	jmp		_uos_awaiting_prog

read_and_test_magic_const_more:
	lpm		REG_TEMP_R16, Z
	cpi		REG_TEMP_R16, 0xFF
	brne		read_and_test_magic_const_rtn
	jmp		_uos_awaiting_prog

read_and_test_magic_const_rtn:
	ret
; ---------

; ---------
; Ecriture d'un byte contenu dans 'REG_TEMP_R16' a l'adresse 'REG_X_MSB:REG_X_LSB' de l'EEPROM
; ---------
uos_eeprom_write_byte:
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

uos_eeprom_write_byte_wait:
	sbic		EECR, EEPE
	rjmp		uos_eeprom_write_byte_wait

	ret
; ---------

; ---------
; _uos_tim1_compa_isr
;
; Methode appele a chaque expiration du timer #1 interne (100 uS)
;
; => TODO: Traitements (Nbr de cycles maximal):
;    0 - Entree dans l'It + gestion de la pulse         -> 33 cycles max
;    1 - tim1_compa_isr_acq_rxd:     Acquisition de RXD pour detection ligne IDLE   -> 18 cycles max
;    2 - tim1_compa_isr_tx_send_bit: Emission d'un bit sur TXD + uart_fifo_rx_write -> 39 + 30 cycles max
;    3 - tim1_compa_isr_rx_rec_bit:  Reception d'un bit sur RXD                     -> 67 cycles max
;    4 - tim1_compa_isr_cpt_1ms:     Comptabilisation de 1 mS                       -> 15 cycles max
;
;      - Sortie de l'It + gestion de la pulse           -> 28 cycles max
;
;    => Total si les 4 traitements sont executes dans le meme tick: 28 + 169 + 33 = 230 cycles max
;
; Registres utilises:
;    REG_X_LSB:REG_X_MSB -> Comptabilisation des ticks dans 'G_TICK_1MS'
;    REG_TEMP_R16        -> Travail
;    REG_TEMP_R17        -> Travail
;    REG_PORTB_OUT       -> Image du PORTB
;    REG_SAVE_SREG       -> Sauvegarde temporaire de SREG
; ---------
uos_tim1_compa_isr_program:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace PROGRAM)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_TIM1_COMPA_PROGRAM_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	rjmp		_uos_tim1_compa_isr

_uos_tim1_compa_isr_bootloader:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace BOOTLOADER)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_TIM1_COMPA_BOOTLOADER_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	;rjmp		_uos_tim1_compa_isr

_uos_tim1_compa_isr:
	push		REG_TEMP_R23

#if USE_MARK_IN_TIM1_COMPA
	; Creneau --\_/--- pour indiquer la charge de travail dans l'It
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	cbr		REG_TEMP_R23, MSK_BIT_PULSE_IT
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
#endif

	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE
	out		PORTB, REG_TEMP_R23

	push		REG_X_LSB
	push		REG_X_MSB
	push		REG_Z_LSB
	push		REG_Z_MSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	rcall		_uos_delay_5uS		; Travail fictif de 5uS quel que soit l'espace BOOTLOADER ou PROGRAM

	; ---------
	; Prolongement si le code est execute au RESET depuis l'espace PROGRAM et
	; si le vecteur commence par l'instruction 'rjmp'
	; ---------
	ldi		REG_Z_MSB, high(_uos_callback_tick)	; Execution si possible de l'extension '_uos_tim1_compa_isr'
	ldi		REG_Z_LSB, low(_uos_callback_tick)	; dans l'espace PROGRAM
	rcall		_uos_exec_extension_into_program
	; ---------

	; ---------
	; Comptabilisation de 1 mS
	; ---------
_uos_tim1_compa_isr_cpt_1ms:
	; => Si 'FLG_0_PERIODE_1MS' est a 1 (1mS atteinte a la precedente It) => Ne rien faire en attendant
	;       que 'FLG_0_PERIODE_1MS' passe a 0
	; => Sinon; si 'G_TICK_1MS' passe a 0 (1mS atteinte) => 'FLG_0_PERIODE_1MS' = 1 => Non maj 'G_TICK_1MS'
	;    Sinon decrementation et maj 'G_TICK_1MS'
	;
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, FLG_0_PERIODE_1MS_IDX

	rjmp		_uos_tim1_compa_isr_cpt_1ms_end

	lds		REG_X_LSB, G_TICK_1MS
	tst		REG_X_LSB										; X ?= 0
	brne		_uos_tim1_compa_isr_cpt_1ms_dec

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbr		REG_TEMP_R23, FLG_0_PERIODE_1MS_MSK		; Oui: Set 'FLG_0_PERIODE_1MS'
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

	rjmp		_uos_tim1_compa_isr_cpt_1ms_end			; Fin sans maj de 'G_TICK_1MS'

_uos_tim1_compa_isr_cpt_1ms_dec:
	subi		REG_X_LSB, 1			
	sts		G_TICK_1MS, REG_X_LSB

_uos_tim1_compa_isr_cpt_1ms_end:
	; Fin: Comptabilisation de 1 mS
	; ---------

	; Emission d'un byte sur TX
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrs		REG_TEMP_R23, FLG_0_UART_TX_TO_SEND_IDX		; Byte a emettre TXD ?

	rjmp		_uos_tim1_compa_isr_end								; Non

	lds		REG_TEMP_R17, UCSR0A								; Caractere en cours d'emission ?
	sbrs		REG_TEMP_R17, UDRE0
	rjmp		_uos_tim1_compa_isr_end							; Oui

	lds		REG_TEMP_R16, G_UART_BYTE_TX
	sts		UDR0, REG_TEMP_R16

	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	cbr		REG_TEMP_R23, FLG_0_UART_TX_TO_SEND_MSK		; Pret a lire le FIFO/Tx
	sts		UOS_G_FLAGS_0, REG_TEMP_R23
	; Fin: Emission d'un byte sur TX

_uos_tim1_compa_isr_end:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Z_MSB
	pop		REG_Z_LSB
	pop		REG_X_MSB
	pop		REG_X_LSB

#if USE_MARK_IN_TIM1_COMPA
	; Fin: Creneau --\_/---
	lds		REG_TEMP_R23, UOS_G_PORTB_IMAGE 
	sbr		REG_TEMP_R23, MSK_BIT_PULSE_IT
	sts		UOS_G_PORTB_IMAGE, REG_TEMP_R23
	out		PORTB, REG_TEMP_R23
#endif

	pop		REG_TEMP_R23

	out		SREG, REG_SAVE_SREG
	pop		REG_SAVE_SREG

	reti
; ---------

; ---------
; Reception d'un byte sur RX
; ---------
uos_usart_rx_complete_isr_program:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace PROGRAM)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_UART_COMPLETE_PROGRAM_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	rjmp		_uos_usart_rx_complete_isr

_uos_usart_rx_complete_isr_bootloader:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace BOOTLOADER)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_UART_COMPLETE_BOOTLOADER_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	;rjmp		_uos_usart_rx_complete_isr

_uos_usart_rx_complete_isr:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	lds		REG_R5, UDR0		
	rcall		_uos_uart_fifo_rx_write

	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB

	out		SREG, REG_SAVE_SREG
	pop		REG_SAVE_SREG

	reti
; ---------

; ---------
; Changement d'etat sur PIND<7:4>
; ---------
uos_pcint2_isr_program:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace PROGRAM)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_PCINT2_PROGRAM_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	rjmp		_uos_pcint2_isr

_uos_pcint2_isr_bootloader:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	; Marquage de l'origine de l'It (Espace BOOTLOADER)
	push		REG_TEMP_R16
	lds		REG_TEMP_R16, G_STATES_AT_RESET
	sbr		REG_TEMP_R16, FLG_STATE_AT_IT_PCINT2_BOOTLOADER_MSK		
	sts		G_STATES_AT_RESET, REG_TEMP_R16
	pop		REG_TEMP_R16
	;rjmp		_uos_pcint2_isr

_uos_pcint2_isr:
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19
	push		REG_Y_MSB
	push		REG_Y_LSB

	lds		REG_TEMP_R16, G_FLAGS_BUTTON
	sbr		REG_TEMP_R16, FLG_BUTTON_WAIT_DONE_MSK
	sts		G_FLAGS_BUTTON, REG_TEMP_R16

	; Rearmement a 'DURATION_WAIT_STABILITY' pour effacer les rebonds a l'appui et au relacher
	ldi		REG_TEMP_R17, TIMER_GEST_BUTTON
	ldi		REG_TEMP_R18, (DURATION_WAIT_STABILITY % 256)
	ldi		REG_TEMP_R19, (DURATION_WAIT_STABILITY / 256)
	rcall		uos_restart_timer

_uos_pcint2_isr_end:
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16

	out		SREG, REG_SAVE_SREG
	pop		REG_SAVE_SREG

	reti
; ---------

#if 1
; [Padding jusqu'a l'adresse 0x37FF
.include		"PaddingWith16Bytes.h"
.include		"PaddingWith16Bytes.h"
.include		"PaddingWith16Bytes.h"
.include		"PaddingWith16Bytes.h"

; Complement...
	nop
	nop
	nop
	nop
	rjmp		_uos_forever		; Mise sur voie de garage ;-)
; Fin: Padding jusqu'a l'adresse 0x37FF]
#endif

; Adresses de base des vecteurs d'interruptions avec 'fuses_high' = bxxxxx000
.org	0x3800 

; Vecteurs d'interruption dans le cas du fusible BOOTRST = 1
_uos_reset_bootloader:
	; => Marquage du numero de l'It en hexadecimal pour faciliter
	;    la lecture de 'UOS_G_STATES_POST_MORTEM'
	;    => Origine: 'FLG_WRONG_IT_BOOTLOADER' (Bit<7>)
	;       Num It:  Bits<0-5>
	nop
	rjmp		_uos_main_bootloader								; # 1 RESET

	ldi		REG_TEMP_R17, 0x02
	rjmp		_uos_invalid_it_speed							; # 2 INT0

	ldi		REG_TEMP_R17, 0x03
	rjmp		_uos_invalid_it_speed							; # 3 INT1

	ldi		REG_TEMP_R17, 0x04
	rjmp		_uos_invalid_it_speed							; # 4 PCINT0

	ldi		REG_TEMP_R17, 0x05
	rjmp		_uos_invalid_it_speed							; # 5 PCINT1

	nop
	rjmp		_uos_pcint2_isr_bootloader						; # 6 PCINT2

	ldi		REG_TEMP_R17, 0x07
	rjmp		_uos_invalid_it_speed							; # 7 WDT

	ldi		REG_TEMP_R17, 0x08
	rjmp		_uos_invalid_it_speed							; # 8 TIMER2 COMPA

	ldi		REG_TEMP_R17, 0x09
	rjmp		_uos_invalid_it_speed							; # 9 TIMER2 COMPB

	ldi		REG_TEMP_R17, 0x10
	rjmp		_uos_invalid_it_speed							; #10 TIMER2 OVF

	ldi		REG_TEMP_R17, 0x11
	rjmp		_uos_invalid_it_speed							; #11 TIMER1 CAPT

	nop
	rjmp		_uos_tim1_compa_isr_bootloader				; #12 TIMER1 COMPA

	ldi		REG_TEMP_R17, 0x13
	rjmp		_uos_invalid_it_speed							; #13 TIMER1 COMPB

	ldi		REG_TEMP_R17, 0x14
	rjmp		_uos_invalid_it_speed							; #14 TIMER1 OVF

	ldi		REG_TEMP_R17, 0x15
	rjmp		_uos_invalid_it_speed							; #15 TIMER0 COMPA

	ldi		REG_TEMP_R17, 0x16
	rjmp		_uos_invalid_it_speed							; #16 TIMER0 COMPB

	ldi		REG_TEMP_R17, 0x17
	rjmp		_uos_invalid_it_speed							; #17 TIMER0 OVF

	ldi		REG_TEMP_R17, 0x18
	rjmp		_uos_invalid_it_speed							; #18 SPI, SPC

	nop
	rjmp		_uos_usart_rx_complete_isr_bootloader		; #19 USART, RX

	ldi		REG_TEMP_R17, 0x20
	rjmp		_uos_invalid_it_speed							; #20 USART, UDRE

	ldi		REG_TEMP_R17, 0x21
	rjmp		_uos_invalid_it_speed							; #21 USART, TX

	ldi		REG_TEMP_R17, 0x22
	rjmp		_uos_invalid_it_speed							; #22 ADC

	ldi		REG_TEMP_R17, 0x23
	rjmp		_uos_invalid_it_speed							; #23 EE READY

	ldi		REG_TEMP_R17, 0x24
	rjmp		_uos_invalid_it_speed							; #24 ANALOG COMP

	ldi		REG_TEMP_R17, 0x25
	rjmp		_uos_invalid_it_speed							; #25 TWI

	ldi		REG_TEMP_R17, 0x26
	rjmp		_uos_invalid_it_speed							; #26 SPM READY

; Reservation 2 bytes pour s'aligner sur le 'main' du Langage C
; => TODO: Saut vers '_uos_forever'
	nop
	rjmp      _uos_forever		; Ne sera jamais execute (adresse du 'main()' d'un programme C)

; ---------
; Table des vecteurs d'execution des taches timer codees dans l'espace BOOTLOADER
; => Vecteurs d'adesses "mappee" dans l'espace PROGRAM correspondant ;-)
; ---------
_uos_vector_timer_0_program:
	; Vecteurs des 9 expirations timer disponibles pour les addons
	jmp		_uos_callback_exec_timer_0
	jmp		_uos_callback_exec_timer_1
	jmp		_uos_callback_exec_timer_2
	jmp		_uos_callback_exec_timer_3
	jmp		_uos_callback_exec_timer_4
	jmp		_uos_callback_exec_timer_5
	jmp		_uos_callback_exec_timer_6
	jmp		_uos_callback_exec_timer_7
	jmp		_uos_callback_exec_timer_8

	; Vecteurs des 7 expirations timer utilises par BOOTLOADER
	jmp		_uos_callback_exec_timer_9				; 'TIMER_TEST_LEDS'
	jmp		_uos_callback_exec_timer_10			; 'TIMER_GEST_BUTTON_LED'
	jmp		_uos_callback_exec_timer_11			; 'TIMER_GEST_BUTTON'
	jmp		_uos_callback_exec_timer_12			; 'TIMER_GEST_BUTTON_ACQ'
	jmp		_uos_callback_exec_timer_13			; 'TIMER_ERROR'
	jmp		_uos_callback_exec_timer_14			; 'TIMER_LED_GREEN'
	jmp		_uos_callback_exec_timer_15			; 'TIMER_CONNECT'

; ---------
; Table des 5 vecteurs d'execution defini sur 2 mots d'instructionen prolongement
; de celui de l'espace BOOTLOADER
; => Terminaison de la 1st page de 64 mots pour la programmation interne au moyen
;    l'instruction 'stm'
; ---------
_uos_callback_init:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callback_init')

_uos_callback_background:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callback_background')

_uos_callback_tick:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callbackaddon_tick')

_uos_callback_1_ms:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callbackaddon_1_ms')

_uos_callback_gest_buttons:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callbackaddon_gest_buttons')

_uos_callback_command:
	nop
	rjmp		_uos_forever	; Ne sera jamais execute (prolongement en 'callback_command')
; ---------

; ---------
; Fonctionnalites dans un fichier a part
; => Aucune contrainte sur l'ordre d'inclusion
;    => Si ordre different ou ajout de fonctionnalites,  certains branchements (rjump/jump) ou
;       appel aux subroutines (rcall/call) devront etre adaptes (suppression erreur ou warning)
;    => A noter que le fichier 'ATmega328P_uOS_Commands.asm' implemente les routines d'ecriture
;       dans la FLASH qui doivent etre definies dans l'espace de demarrage de uOS (0x3800-0x3FFF)
;       => En particulier la routine '_uos_do_spm' doit etre dans l'espace de demarrage
.include		"ATmega328P_uOS_Misc.asm"
.include		"ATmega328P_uOS_Timers.asm"
.include		"ATmega328P_uOS_Uart.asm"
.include		"ATmega328P_uOS_Buttons.asm"
.include		"ATmega328P_uOS_Print.asm"
.include		"ATmega328P_uOS_Commands.asm"
; Fin: Fonctionnalites dans un fichier a part

; ---------
.dseg

; Fin des variables propres au BOOTLOADER
; => 'G_FLAGS_EXTENSIONS' appartient au BOOTLOADER dans la mesure ou 'UOS_G_FLAGS_EXTENSIONS'
;    doit etre initialise a 0x00 pour poursuivre l'initialisation des extensions
; => IMPORTANT: Ne pas definir de section '.dseg' apres celle-ci ;-)
;
UOS_G_SRAM_BOOTLOADER_END_OF_USE:	.byte		1		; Initialisee a 0xff pour reperage dans la SRAM
; ---------

.cseg

; ---------
; Derniere adresse du programme
; ---------
	jmp		_uos_forever	; Ne sera jamais execute

; ---------
; Constantes et textes definis naturellement (MSB:LSB et ordre naturel du texte)
; => Remarque: Nombre pair de caracteres pour eviter le message:
;              "Warning : A .DB segment with an odd number..."

; Prompt lorsque le RESET est fait dans l'espace PROGRAMME
_uos_text_program:
.db	"### Hello World !..", CHAR_LF, CHAR_NULL, CHAR_NULL

; Prompt lorsque le RESET est fait dans l'espace BOOTLOADER
_uos_text_bootloader:
.db	"### Micro OS !..", CHAR_LF, CHAR_NULL

_uos_text_prompt:
; Warning: Passage de la Rev: sur x.yz
.db	"### ATmega328p $Revision: 1.19 $", CHAR_LF, CHAR_NULL

_uos_text_frequency_8_mhz:
.db	"### 8 MHz", CHAR_LF, CHAR_NULL, CHAR_NULL

_uos_text_frequency_16_mhz:
.db	"### 16 MHz", CHAR_LF, CHAR_NULL

_uos_text_prompt_eeprom_version:
.db	"### EEPROM: ", CHAR_NULL, CHAR_NULL

_uos_text_prompt_type:
.db	"### Type: ", CHAR_NULL, CHAR_NULL

_uos_text_prompt_id:
.db	"### Id: ", CHAR_NULL, CHAR_NULL

_uos_text_prompt_bauds_value:
.db	"### Bauds: ", CHAR_NULL

_uos_text_press_button_short:
.db	"### Press button short ", CHAR_NULL

_uos_text_press_button_long:
.db	"### Press button long ", CHAR_NULL, CHAR_NULL

_uos_text_convert_hex_to_min_ascii_table:
.db	"0123456789abcdef"

_uos_text_flash_error:
.db	"Err: FLASH at ", CHAR_NULL, CHAR_NULL

uos_text_eeprom_error:
.db	"Err: EEPROM at ", CHAR_NULL

_uos_text_it_error:
.db	"Err: Invalid It ", CHAR_NULL, CHAR_NULL

uos_text_hexa_value:
.db	"[0x", CHAR_NULL

_uos_text_hexa_value_end:
.db	"]", CHAR_NULL

uos_text_hexa_value_lf_end:
.db	"]", CHAR_LF, CHAR_NULL, CHAR_NULL

_uos_text_line_feed:
.db	CHAR_LF, CHAR_NULL

; Fin: Constantes et textes definis naturellement (MSB:LSB et ordre naturel du texte)

_uos_magic_const:
.dw	0x1234

end_of_program:

; End of file

