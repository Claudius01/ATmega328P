; $Id: ATmega328P_optiBoot.asm,v 1.2 2026/11/21 13:10:35 administrateur Exp $

; Reprise du code pour commentaires @ simulation

; Commandes supportees et testees:
; - STK_READ_SIGN ('u'): [STK_READ_SIGN CRC_EOP]
;   Reponse:             [STK_INSYNC 1E 95 16 STK_OK]
;                        -> Signature de la cible (ATMEGA328PB_SIGNATURE)

; - STK_GET_PARAMETER ('A'): [STK_GET_PARAMETER '0' CRC_EOP]
;   Reponse:                 [STK_INSYNC 03 STK_OK]
;                            -> Car '0' inconnu
;                            [STK_GET_PARAMETER "\81" CRC_EOP]
;                            [STK_GET_PARAMETER "\82" CRC_EOP]
;   Reponse:                 [STK_INSYNC 04 STK_OK]
;                            -> Car 0x81 = 'STK_SW_MAJOR' et 0x82 = 'STK_SW_MINOR'
;
; - STK_SET_DEVICE ('B'):    [STK_SET_DEVICE 12345678901234567890 CRC_EOP] (20 bytes de donnees)
;   Reponse:                 [STK_INSYNC STK_OK]
;                            -> Ok mais aucune prise en compte des parametres ;-)
;
; - STK_SET_DEVICE_EXT ('E'): [STK_SET_DEVICE_EXT 12345 CRC_EOP] (5 bytes de donnees)
;   Reponse:                  [STK_INSYNC STK_OK]
;                             -> Ok mais aucune prise en compte des parametres ;-)
;
; - STK_LOAD_ADDRESS ('U'): [STK_LOAD_ADDRESS "\12" "\34" CRC_EOP] (2 bytes de donnees)
;   Reponse:                [STK_INSYNC STK_OK]
;                           -> L'adresse multipliee par 2 est memorisee dans Z
;                              une ecriture dans la flash (TBC: eeprom) au moyen de
;                              la commande 'STK_PROG_PAGE'
;
; - STK_PROG_PAGE ('d'): [STK_PROG_PAGE d\00\08F\12\34\56\78\9a\bc\de\f0 CRC_EOP] (8 bytes de donnees)
;                        => Donnees de la page de 64 mots a ecrire dans la flash ((TBC: eeprom))
;                           => La page de 64 mots est totalement ecrite ;-)
;
; - STK_PROG_PAGE ('d'): [STK_PROG_PAGE d\00\04F\12\34\56\78 CRC_EOP] (7 bytes de donnees)
;                        [STK_PROG_PAGE d\00\04F\ab\cd\ef\01 CRC_EOP] (7 bytes de donnees)
;                        => Programmation des 4 bytes "\12\34\56\78" dans la Flash (terminaison par 'CRC_EOP')
;   Reponse:             Aucune car peut etre executee en plusieurs fois
;                        => L'adresse utilsee est celle memorisee dans Z et le type 'E' ou 'F'
;                           n'est pas extraits ni memorise
;                        => Memorisation des donnees de la page a l'adresse 0x100 de la SRAM
;                           SRAM::dump_sram()
;                           Dump of [0x808b9bc] - Offset [0x100] (2048 bytes)
;                           Address    0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F   0123456789ABCDEF
;                           00000100  12 34 56 78 9a bc de f0  3f 3f 3f 3f 3f 3f 3f 3f  |.4Vx....????????|
;                           00000110  3f 3f 3f 3f 3f 3f 3f 3f  3f 3f 3f 3f 3f 3f 3f 3f  |????????????????|
;                           *
;                           000008f0  3f 3f 3f 3f 3f 3f 3f 3f  3f 3f 3f 3f 3f 3f 3f 72  |???????????????r|
;                           00000900
;
;   => L'absence de reception de caracteres provoque l'expiration du timer Watchdog qui fera un Reset en 0x0
;
; - STK_LEAVE_PROGMODE ('Q'): [STK_LEAVE_PROGMODE CRC_EOP] (2 bytes de donnees)
;   Reponse:                  [STK_INSYNC STK_OK]
;
; - STK_UNIVERSAL ('V'): [STK_UNIVERSAL 1234 CRC_EOP] (4 bytes de donnees)
;   Reponse:             [STK_INSYNC 00 STK_OK]
;
; 2026/11/02 - Accueil de la symbologie des 4 Leds GREEN, YELLOW, BLUE et RED
;              => Led GREEN
;              => Led YELLOW
;              => Led BLUE
;              => Led RED
;
; 2026/11/06 - Programmationi avec la Platine, televersement depuis l'IDE avec succes dans un 'ATmega328P' ;-))
;              => Adresse de boot: 0x3800 Fuses:  00xef 0xff 0xfc 0xd0 (comme uOS ;-)
;              => Adresse de boot: 0x3800 Fuses:  00xef 0xff 0xfc 0xd6

.include			"m328Pdef.inc"		; Labels and identifiers for ATmega328p

.include			"stk500.h"
.include			"ATmega328P_uOS.def"
.include			"ATmega328P_optiBoot.def"

#define			SIGNATURE		0x1E950F		; ATmega328p

#define	ETX		0x03		; End of TeXt
#define	EOT		0x04		; End Of Transmission

#define	USE_GESTION_LEDS		0

.cseg

.org	0x3E00		; WARNING: Pb de programmation de la derniere page [0x3c00-0x3fff]
						;          avec le mode '^p' @ Monitor
						;          => Reste a 0xffff ?!..
						;          => Ok avec les modes "Prog erase" + "Prog flash..."
	cli

	clr     REG_R1
	sts     OPTIBOOT_G_TRACES_MCUSR, REG_R1
	sts     OPTIBOOT_G_TRACES_GO_SKETCH, REG_R1
	sts     OPTIBOOT_G_TRACES_WATCHDOG, REG_R1

	; Remarque: 2 incrementations constatees suite a un Reset materiel
	;           => Sans doute du a un rebond sur le Reset
	lds     REG_TEMP_R24, OPTIBOOT_G_TRACES_LAUNCH
	inc     REG_TEMP_R24
	sts     OPTIBOOT_G_TRACES_LAUNCH, REG_TEMP_R24

	; Marquage de l'origine du Reset (WDRF BORF EXTRF PORF);
	; => A la mise sous tension:    0x5 -> BORF + PORF
	; => Suite a un Reset materiel: 0x8 -> WDRF
	in      REG_TEMP_R24, MCUSR
	sts     OPTIBOOT_G_TRACES_MCUSR, REG_TEMP_R24

	out     MCUSR, REG_R1
	sbrs    REG_TEMP_R24, EXTRF

	rcall   go_sketch

#if USE_GESTION_LEDS
	; Gestion Leds
	sbi     DDRB, LED_BLUE		; Led BLUE
	sbi     DDRB, LED_RED		; Led RED
	;sbi     DDRB, LED_YELLOW	; Led YELLOW
	sbi     DDRB, LED_GREEN		; Led GREEN

	sbi     PORTB, LED_BLUE		; Extinction Led BLUE
	sbi     PORTB, LED_RED		; Extinction Led RED
	;sbi     PORTB, LED_YELLOW	; Extinction Led YELLOW
	sbi     PORTB, LED_GREEN	; Extinction Led GREEN
	; Fin: Gestion Leds
#endif

	ldi     REG_TEMP_R24, 0x55
	sts     OPTIBOOT_G_TRACES_GO_SKETCH, REG_TEMP_R24

	ldi     REG_TEMP_R24, (1 << CS12) | (1 << CS10)
	sts     TCCR1B, REG_TEMP_R24
	sbi     PORTD, IDX_BIT0			; Mise a 1 de Rx (PORTD<0>)

	; En attendant une evolution de 'uOS' @ 'uos_init_hard'
	; TODO: 'UCSR0A' a initialiser sans le bit 'U2X0'
	ldi     REG_TEMP_R24, (1 << U2X0)
	sts     UCSR0A, REG_TEMP_R24

	ldi     REG_TEMP_R24, (1 << RXEN0) | (1 << TXEN0)
	sts     UCSR0B, REG_TEMP_R24
	ldi     REG_TEMP_R24, (1 << UCSZ01) | (1 << UCSZ00)
	sts     UCSR0C, REG_TEMP_R24

	; Avec 'U2X0' dans 'UCSR0A' affirme et 'UBRR0H' = 0:
	; 21 = 0x15 -> 115200 Bauds Rate @ 20 MHz
	; 16 = 0x10 -> 115200 Bauds Rate @ 16 MHz
	;              => Lu dans le bootloader UNO a 16 MHz
	; 20/16 = 1.25 ~= 21/16 = 1.31 (21/17 = 1.235)
	;
	; Valeurs pour une gestion avec 'UsbMonitor':
	; 103 = 0x67 -> 19200 bauds @ 16 MHz
	; 207 = 0xCF ->  9600 bauds @ 16 MHz
	;ldi     REG_TEMP_R24, 21		; Avec 'U2X0' a 1 - 20 MHz
	ldi     REG_TEMP_R24, 16		; Avec 'U2X0' a 1 - 16 MHz

	sts     UBRR0L, REG_TEMP_R24

	ldi     REG_TEMP_R24, (1 << WDE) | (1 << WDP2) | (1 << WDP1)
	rcall   set_reg_wdtcsr

	sbi     DDRB, PB5				; PORTB<5> en sortie (Led YELLOW)

	ldi     REG_TEMP_R24, 6		; Initialisation boucle

	; Initialisation timer 1
	ldi     REG_TEMP_R18, low(64316)
	ldi     REG_TEMP_R19, high(64316)
	ldi     REG_TEMP_R25, (1 << TOV1)

	; Boucle d'attente du debordement du timer 1
wait_end_of_timer1:
	sts     TCNT1H, REG_TEMP_R19
	sts     TCNT1L, REG_TEMP_R18
	out     TIFR1, REG_TEMP_R25

wait_end_of_timer1_loop:
	sbis    TIFR1, TOV1
	rjmp    wait_end_of_timer1_loop

	; Astuce: Inverse l'etat de PB1 (allume ou eteint la LED sur PB5 configure en sortie))
	sbi     PINB, PB5		; Clignotement Led YELLOW sur overflow du timer ;-)

#if USE_WATCHDOG
	push    REG_TEMP_R25
	ldi     REG_TEMP_R25, 0xBB
	sts     OPTIBOOT_G_TRACES_WATCHDOG, REG_TEMP_R25
	pop     REG_TEMP_R25

	wdr
#endif

	subi    REG_TEMP_R24, 1
	brne    wait_end_of_timer1
	; Fin: Boucle d'attente du debordement du timer 1

	clr     REG_R12
	clr     REG_R13
	clr     REG_R8
	inc     REG_R8
	ldi     REG_X_MSB, 5
	mov     REG_R10, REG_X_MSB

	ldi     REG_X_LSB, 0x11
	mov     REG_R9, REG_X_LSB

	; Preparation ecriture de SPMCSR
	ldi     REG_Z_MSB, (1 << PGERS) | (1 << SPMEN)
	mov     REG_R11, REG_Z_MSB

wait_stk_opcode:
#if USE_GESTION_LEDS
	; Allumage de la Led GREEN durant l'attente de la commande STK500
	cbi     PORTB, LED_GREEN
	sbi     PORTB, LED_BLUE
#endif

	rcall   wait_char

test_if_stk_get_parameter:
	cpi     REG_TEMP_R24, STK_GET_PARAMETER
	brne    test_if_stk_set_device

exec_stk_get_parameter:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	rcall   wait_char
	mov     REG_TEMP_R16, REG_TEMP_R24		; Sauvegarde caractere recu dans 'REG_TEMP_R16'
	rcall   read_crc_eop

	cpi     REG_TEMP_R16, STK_SW_MINOR
	breq    send_eot

	; Traitement de la commande 'STK_SW_MINOR'
	cpi     REG_TEMP_R16, STK_SW_MAJOR
	brne    send_etx

	; Traitement de la commande 'STK_SW_MAJOR'
send_eot:
	ldi     REG_TEMP_R24, EOT
	rjmp    send_response

send_etx:
	ldi     REG_TEMP_R24, ETX

send_response:
	rcall   send_tx
	rjmp    send_stk_ok

test_if_stk_set_device:
	cpi     REG_TEMP_R24, STK_SET_DEVICE
	brne    test_if_stk_set_device_ext

exec_stk_set_device:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	ldi     REG_TEMP_R24, 0x14
	rjmp    exec_stk_set_device_ext_contd

test_if_stk_set_device_ext:
	cpi     REG_TEMP_R24, STK_SET_DEVICE_EXT
	brne    test_if_stk_load_address

#if USE_GESTION_LEDS
	cbi     PORTB, LED_GREEN
	;sbi     PORTB, LED_YELLOW
#endif

	; Traitement de la commande 'STK_SET_DEVICE_EXT'
	ldi     REG_TEMP_R24, 5

exec_stk_set_device_ext_contd:
	rcall   consommation_char
	rjmp    send_stk_ok

test_if_stk_load_address:
	cpi     REG_TEMP_R24, STK_LOAD_ADDRESS
	brne    test_if_stk_read_osccal

#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	; Traitement de la commande 'STK_LOAD_ADDRESS'
	rcall   wait_char
	mov     REG_R14, REG_TEMP_R24
	clr     REG_R15
	rcall   wait_char
	mov     REG_TEMP_R16, REG_TEMP_R24
	ldi     REG_TEMP_R17, 0
	mov     REG_TEMP_R17, REG_TEMP_R16
	clr     REG_TEMP_R16
	or      REG_TEMP_R16, REG_R14
	or      REG_TEMP_R17, REG_R15
	lsl     REG_TEMP_R16
	rol     REG_TEMP_R17
	rcall   read_crc_eop

	movw    REG_R12, REG_TEMP_R16
	rjmp    send_stk_ok

test_if_stk_read_osccal:
	cpi     REG_TEMP_R24, STK_UNIVERSAL
	brne    test_if_stk_prog_page

#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	; Traitement de la commande 'STK_UNIVERSAL'
	ldi     REG_TEMP_R24, 4
	rcall   consommation_char

	ldi     REG_TEMP_R24, 0
	rjmp    send_response

test_if_stk_prog_page:
	cpi     REG_TEMP_R24, STK_PROG_PAGE
	breq    exec_stk_prog_page

	; Traitement de la commande 'STK_PROG_PAGE'
	rjmp    test_if_stk_read_page

; --------
exec_stk_prog_page:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	rcall   wait_char			; Lecture de 'bytes_high'
	rcall   wait_char			; Lecture de 'bytes_low'

	; Remarque: 'bytes_high' est perdu !..
	;           => Pas grave car:
	;              => "The data block size should not be larger than 256 bytes"
	mov     REG_TEMP_R16, REG_TEMP_R24

	rcall   wait_char			; Lecture du type 'E' (Eeprom) eor 'F' (Flash)

exec_stk_prog_page_more:
	ldi     REG_TEMP_R24, 0x00			; Adresse low(0x7000) = low(2 * 0x3800)
	cp      REG_R12, REG_TEMP_R24		; 
	ldi     REG_TEMP_R24, 0x70			; Adresse high(0x7000) = high(2 * 0x3800)
	cpc     REG_R13, REG_TEMP_R24
	brcc    write_into_sram

	movw    REG_Z_LSB, REG_R12			; 0 <= R11:R12 < 0x7000

	; Ecriture dans la flash de 'REG_R1:REG_R0'
	out     SPMCSR, REG_R11
	spm		; Bit SPMEN remis a 0 dans SMPCSR

write_into_sram:
	ldi     REG_Y_LSB, low(OPTIBOOT_G_BUFFER)
	ldi     REG_Y_MSB, high(OPTIBOOT_G_BUFFER)

write_into_sram_loop:
	rcall   wait_char
	st      Y+, REG_TEMP_R24
	cp      REG_TEMP_R16, REG_Y_LSB	; Comparaison du seul LSB de l'adresse
												; => TODO: Faire un masque pour accepter 'OPTIBOOT_G_BUFFER'
												;          egal a 0x880 (definitions juste avant la pile d'appel)
	brne    write_into_sram_loop		; Fin du buffer (LSB limite a 'REG_TEMP_R16' contenant le nbr
												; de donnees a programmer...

	ldi     REG_Z_MSB, 0x00       ; Oui -> Compare address
	cp      REG_R12, REG_Z_MSB
	ldi     REG_Z_MSB, 0x70       ; Adresse max de la flash (0x7000 = 2 * 0x3800)
	cpc     REG_R13, REG_Z_MSB
	brcs    write_into_sram_more	; Z < R12:R13 ?

	movw    REG_Z_LSB, REG_R12

	out     SPMCSR, REG_R11
	spm		; Bit SPMEN remis a 0 dans SMPCSR

write_into_sram_more:
	rcall   read_crc_eop

write_into_sram_more_loop:
	in      REG_R0, SPMCSR			; Wait for SPMEN ready
	sbrc    REG_R0, SPMEN
	rjmp    write_into_sram_more_loop

	movw    REG_TEMP_R20, REG_R12

	ldi     REG_X_LSB, low(OPTIBOOT_G_BUFFER)
	ldi     REG_X_MSB, high(OPTIBOOT_G_BUFFER)

write_into_sram_more_loop2:
	ld      REG_TEMP_R18, X
	ldi     REG_TEMP_R19, 0
	adiw    REG_X_LSB, 1
	ld      REG_TEMP_R24, X
	sbiw    REG_X_LSB, 1
	ldi     REG_TEMP_R25, 0
	mov     REG_TEMP_R25, REG_TEMP_R24
	clr     REG_TEMP_R24
	or      REG_TEMP_R24, REG_TEMP_R18
	or      REG_TEMP_R25, REG_TEMP_R19
	adiw    REG_X_LSB, 2
	movw    REG_Z_LSB, REG_TEMP_R20
	movw    REG_R0, REG_TEMP_R24

	out     SPMCSR, REG_R8
	spm		; Bit SPMEN remis a 0 dans SMPCSR

	clr     REG_R1
	subi    REG_TEMP_R20, 0xfe
	sbci    REG_TEMP_R21, 0xff

	ldi     REG_Z_MSB, high(OPTIBOOT_G_BUFFER)
	cpi     REG_X_LSB, 0x80
	cpc     REG_X_MSB, REG_Z_MSB
	brne    write_into_sram_more_loop2

	movw    REG_Z_LSB, REG_R12

	out     SPMCSR, REG_R10
	spm		; Bit SPMEN remis a 0 dans SMPCSR

write_into_sram_more_loop3:
	in      REG_R0, SPMCSR		; Wait for SPMEN ready
	sbrc    REG_R0, SPMEN
	rjmp    write_into_sram_more_loop3

	out     SPMCSR, REG_R9
	spm								; Bit SPMEN remis a 0 dans SMPCSR

	rjmp    send_stk_ok
; --------

test_if_stk_read_page:
	cpi     REG_TEMP_R24, STK_READ_PAGE
	brne    test_if_stk_read_sign

exec_stk_read_page:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	; Traitement de la commande 'STK_READ_PAGE'
	rcall   wait_char
	rcall   wait_char
	mov     REG_R15, REG_TEMP_R24
	rcall   wait_char
	rcall   read_crc_eop
	movw    REG_Z_LSB, REG_R12
	mov     REG_R14, REG_R15

exec_stk_read_page_loop:
	movw    REG_TEMP_R16, REG_Z_LSB
	subi    REG_TEMP_R16, -1
	sbci    REG_TEMP_R17, -1
	lpm     REG_TEMP_R24, Z
	rcall   send_tx

	dec     REG_R14
	movw    REG_Z_LSB, REG_TEMP_R16
	brne    exec_stk_read_page_loop

	sec
	adc     REG_R12, REG_R1
	adc     REG_R13, REG_R1
	dec     REG_R15
	add     REG_R12, REG_R15
	adc     REG_R13, REG_R1
	rjmp    send_stk_ok
; --------

test_if_stk_read_sign:
	cpi     REG_TEMP_R24, STK_READ_SIGN
	brne    test_if_stk_leave_progmode

	; Traitement de la commande 'STK_READ_SIGN'
	rcall   read_crc_eop

	ldi     REG_TEMP_R24, ((SIGNATURE & 0xFF0000) >> 16)
	rcall   send_tx
	ldi     REG_TEMP_R24, ((SIGNATURE & 0x00FF00) >> 8)
	rcall   send_tx
	ldi     REG_TEMP_R24, ((SIGNATURE & 0x0000FF))
	rjmp    send_response

test_if_stk_leave_progmode:
	cpi     REG_TEMP_R24, STK_LEAVE_PROGMODE
	brne    wait_crc_eop

exec_stk_leave_progmode:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
	;cbi     PORTB, LED_YELLOW
#endif

	; Traitement de la commande 'STK_LEAVE_PROGMODE'
	ldi     REG_TEMP_R24, (1 << WDE)
	rcall   set_reg_wdtcsr

wait_crc_eop:
	rcall   read_crc_eop

send_stk_ok:
	ldi     REG_TEMP_R24, STK_OK
	rcall   send_tx

	rjmp    wait_stk_opcode

send_tx:
	mov     REG_TEMP_R25, REG_TEMP_R24	; Recopie du caractere a emettre

send_tx_wait:
	lds     REG_TEMP_R24, UCSR0A
	sbrs    REG_TEMP_R24, UDRE0	; Registre d'emission UD0 vide ?
	rjmp    send_tx_wait				; Oui -> Continue

	sts     UDR0, REG_TEMP_R25		; Non -> Emission du contenu dans 'REG_TEMP_R25'

	ret
; --------

; --------
; Boucle d'attente de reception caractere
; => Caractere recu disponible dans 'REG_TEMP_R24'
wait_char:
	lds     REG_TEMP_R24, UCSR0A
	sbrs    REG_TEMP_R24, RXC0		; Caractere recu ?
	rjmp    wait_char

	lds     REG_TEMP_R24, UCSR0A	; Oui
	sbrc    REG_TEMP_R24, FE0		; Frame error ?
	rjmp    read_char					; Oui -> bypass 'wdr'

#if USE_WATCHDOG
	ldi     REG_TEMP_R24, 0xCC
	sts     OPTIBOOT_G_TRACES_WATCHDOG, REG_TEMP_R24
	wdr
#endif

read_char:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN
#endif

	lds	 REG_TEMP_R24, UDR0

wait_char_rtn:
	ret
; --------

; --------
; Reinitialisation de 'WDTCSR' @ 'REG_TEMP_R24:REG_TEMP_R25'
set_reg_wdtcsr:
	ldi     REG_Z_LSB, WDTCSR
	ldi     REG_Z_MSB, 0
	ldi     REG_TEMP_R25, (1 << WDCE) | (1 << WDE)		; TBC: ...

	st      Z, REG_TEMP_R25										; TBC: ...
	st      Z, REG_TEMP_R24										; ...Car 'st Z, REG_TEMP_R25' est inutile ?!..

	ret
; --------

; Reception caractere et test si egal a 'CRC_EOP' qui terminera la reponse...
; => Sinon,  rearmement du timer Watchdog
read_crc_eop:
#if USE_GESTION_LEDS
	;sbi     PORTB, LED_YELLOW
	cbi     PORTB, LED_BLUE
#endif

	rcall   wait_char

test_if_crc_eop:
	cpi     REG_TEMP_R24, CRC_EOP			; Caractere 'CRC_EOP' recu
	breq    send_stk_insync

	; Rearment timer Watchdog
	ldi     REG_TEMP_R24, (1 << WDE)
	rcall   set_reg_wdtcsr

	; Caractere recu non supporte
	; => Mise sur voie de garage
	;    => Attente expiration du timer Watchdog

#if 0
        ; Mise sur voie de garage
        ldi     REG_TEMP_R24, 'E'
        rcall   send_tx
        ldi     REG_TEMP_R24, 0x0a
        rcall   send_tx
#endif

forever:
#if USE_GESTION_LEDS
	sbi     PORTB, LED_GREEN		; Extinction Led GREEN
	;sbi     PORTB, LED_YELLOW		; Extinction Led YELLOW
	cbi     PORTB, LED_RED			; Allumage Led RED
#endif

	rjmp    forever

send_stk_insync:
#if USE_GESTION_LEDS
	cbi     PORTB, LED_BLUE
#endif

	ldi     REG_TEMP_R24, STK_INSYNC

	; TBC: Le 'ret' de 'send_tx'...
	;      => A verifier avec 'avrsimu' ;-)
	rjmp    send_tx

; Consommation des caracteres recus a concurence du contenu
; de 'REG_TEMP_R17'
consommation_char:
	push    REG_TEMP_R17
	mov     REG_TEMP_R17, REG_TEMP_R24

consommation_char_loop:
	rcall   wait_char
	subi    REG_TEMP_R17, 1
	brne    consommation_char_loop

	rcall   read_crc_eop
	pop     REG_TEMP_R17
	ret

	; Execution du 'sketch' implemente a l'adresse 0x0000
go_sketch:
	ldi     REG_TEMP_R24, 0xAA
	sts     OPTIBOOT_G_TRACES_GO_SKETCH, REG_TEMP_R24

	ldi     REG_TEMP_R24, 0
	rcall   set_reg_wdtcsr

	clr     REG_Z_LSB
	clr     REG_Z_MSB
	ijmp
; ---

_optiboot_magic_const:   
	.dw  0x1234

.dseg

; WARNING: L'adresse 'low' de 'OPTIBOOT_G_BUFFER' doit etre egale a 0x00 ;-)
; => TODO: Evolutions pour accepter une adresse comme 0x880 juste avant la pile d'appel ;-)
OPTIBOOT_G_SPARE:							.byte		(6 * 0x100)

; Utilisation a partir de 0x700 pour ne pas etre initialise par un code C telecharge
OPTIBOOT_G_BUFFER:						.byte		(2 * 64) 	; Page de 64 mots

OPTIBOOT_G_TRACES_LAUNCH:				.byte		1
OPTIBOOT_G_TRACES_MCUSR:				.byte		1
OPTIBOOT_G_TRACES_GO_SKETCH:			.byte		1
OPTIBOOT_G_TRACES_WATCHDOG:			.byte		1

; End of File

