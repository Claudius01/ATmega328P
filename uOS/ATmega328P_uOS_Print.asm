; "$Id: ATmega328P_uOS_Print.asm,v 1.6 2026/02/18 18:01:34 administrateur Exp $"

.cseg

;--------------------
; Lecture et sauvegarde des informations de l'EEPROM
;--------------------
uos_set_infos_from_eeprom:
	; => Prompt "### EEPROM..."
	ldi		REG_TEMP_R18, 8
	ldi		REG_Z_MSB, ((_uos_text_prompt_eeprom_version << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_prompt_eeprom_version << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	; Lecture de la version de l'EEPROM definie dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_VERSION)
	ldi		REG_X_LSB, low(EEPROM_ADDR_VERSION)
	rcall		uos_push_text_in_fifo_tx_from_eeprom
	rcall		uos_print_line_feed

	; => Prompt "### Type..."
	ldi		REG_Z_MSB, ((_uos_text_prompt_type << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_prompt_type << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	; Lecture du type de platine defini dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_TYPE);
	ldi		REG_X_LSB, low(EEPROM_ADDR_TYPE);
	rcall		uos_eeprom_read_byte

	sts		UOS_G_HEADER_TYPE_PLATINE, REG_TEMP_R16

	rcall		uos_convert_and_put_fifo_tx
	rcall		uos_print_line_feed

	; => Prompt "### Id..."
	ldi		REG_Z_MSB, ((_uos_text_prompt_id << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_prompt_id << 1) % 256)
	rcall		uos_push_text_in_fifo_tx
	
	; Lecture de l'Id de la Platine defini dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_ID);
	ldi		REG_X_LSB, low(EEPROM_ADDR_ID);
	rcall		uos_eeprom_read_byte

	sts		UOS_G_HEADER_INDEX_PLATINE, REG_TEMP_R16

	rcall		uos_convert_and_put_fifo_tx
	rcall		uos_print_line_feed

	; Lecture de la vitesse configuree dans l'EEPROM
	; => Prompt "### Bauds..."
	ldi		REG_Z_MSB, ((_uos_text_prompt_bauds_value << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_prompt_bauds_value << 1) % 256)
	rcall		uos_push_text_in_fifo_tx
	
	ldi		REG_X_MSB, high(EEPROM_ADDR_BAUDS_IDX);
	ldi		REG_X_LSB, low(EEPROM_ADDR_BAUDS_IDX);

#if USE_AVRSIMU
	ldi		REG_TEMP_R16, 0xFF		; TODO: Attente de la simulation de l'EEPROM
#else
	rcall		uos_eeprom_read_byte
#endif

	cpi		REG_TEMP_R16, 0xFF
	brne		uos_set_infos_from_eeprom_more
	ldi		REG_TEMP_R16, 1						; Set to 9600 bauds (value by default)

uos_set_infos_from_eeprom_more:
	sts		UOS_G_HEADER_BAUDS_VALUE, REG_TEMP_R16

#if 0
	rcall		uos_convert_and_put_fifo_tx
#else
	rcall		get_index_bauds_rate_value
	rcall		uos_push_text_in_fifo_tx
#endif

	rcall		uos_print_line_feed
	; Fin: Preparation emission des prompts d'accueil

	ret
; ---------

; ---------
; Reset the 'UOS_FLG_0_PRINT_SKIP' flag
; ---------
uos_reset_skip_print:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	cbr		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_MSK
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

	ret
; ---------

; ---------
; Set the 'UOS_FLG_0_PRINT_SKIP' flag
; ---------
uos_set_skip_print:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbr		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_MSK
	sts		UOS_G_FLAGS_0, REG_TEMP_R23

	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un texte termine par '\0'
;
; Usage:
;      ldi		REG_Z_MSB, <address MSB>
;      ldi		REG_Z_LSB, <address LSB>
;      rcall   uos_push_text_in_fifo_tx
;
; Registres utilises
;    REG_Z_LSB:REG_Z_LSB -> Pointeur sur le texte en memoire programme (preserve)
;    REG_TEMP_R16        -> Working register (preserve)
; ---------
uos_push_text_in_fifo_tx_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_push_text_in_fifo_tx:
	push		REG_Z_MSB
	push		REG_Z_LSB
	push		REG_TEMP_R16

_uos_push_text_in_fifo_tx_loop:
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, CHAR_NULL		; '\0' terminal ?
	breq		_uos_push_text_in_fifo_tx_end

	mov		REG_R3, REG_TEMP_R16
	rcall		_uos_uart_fifo_tx_write

	rjmp		_uos_push_text_in_fifo_tx_loop

_uos_push_text_in_fifo_tx_end:
	pop		REG_TEMP_R16
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un char
;
; Usage:
;      ldi		REG_TEMP_R16, <value>
;      rcall   uos_push_1_char_in_fifo_tx
;
; Registres utilises
;    REG_TEMP_R16 -> Working register
; ---------
uos_push_1_char_in_fifo_tx_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_push_1_char_in_fifo_tx:
	mov		REG_R3, REG_TEMP_R16
	rcall		_uos_uart_fifo_tx_write

	ret
; ---------

; ---------
_uos_convert_nibble_to_ascii:
	andi		REG_TEMP_R16, 0x0f
	ldi		REG_Z_MSB, high(_uos_text_convert_hex_to_min_ascii_table << 1)
	ldi		REG_Z_LSB, low(_uos_text_convert_hex_to_min_ascii_table << 1)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16
	lpm		REG_TEMP_R16, Z

_uos_convert_nibble_to_ascii_rtn:
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un byte converti en 2 hex-char
; => En majuscule si '_uos_text_convert_hex_to_maj_ascii_table' utilisee
; => En minuscule si '_uos_text_convert_hex_to_min_ascii_table' utilisee
;
; Usage:
;      ldi		REG_TEMP_R16, <value>
;      rcall   uos_convert_and_put_fifo_tx
; ---------
uos_convert_and_put_fifo_tx:
	push		REG_TEMP_R16		; Sauvegarde de la valeur a convertir et ecrire

	swap		REG_TEMP_R16		; Copie Bits<7-4> dans Bits<3-0>
	rcall		_uos_convert_nibble_to_ascii
	rcall    uos_push_1_char_in_fifo_tx

	pop		REG_TEMP_R16		; Reprise de la valeur a convertir et ecrire

	rcall		_uos_convert_nibble_to_ascii
	rcall    uos_push_1_char_in_fifo_tx

	ret
; ---------

; ---------
uos_print_line_feed_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_print_line_feed:
	push		REG_Z_MSB
	push		REG_Z_LSB

	ldi		REG_Z_MSB, ((_uos_text_line_feed << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_line_feed << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_MSK	; Caracteres mis en FIFO a emettre ;-)
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
uos_print_1_byte_hexa_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_print_1_byte_hexa:
	push		REG_Z_MSB
	push		REG_Z_LSB

	; Emission en hexa du contenu de 'REG_X_LSB'
	ldi		REG_Z_MSB, ((uos_text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((uos_text_hexa_value << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	mov		REG_TEMP_R16, REG_X_LSB
	rcall		uos_convert_and_put_fifo_tx

	ldi		REG_Z_MSB, ((_uos_text_hexa_value_end << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_hexa_value_end << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
uos_print_2_bytes_hexa_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_print_2_bytes_hexa:
	push		REG_Z_MSB
	push		REG_Z_LSB

	; Emission en hexa du contenu de 'REG_X_MSB:REG_X_LSB'
	ldi		REG_Z_MSB, ((uos_text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((uos_text_hexa_value << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	mov		REG_TEMP_R16, REG_X_MSB
	rcall		uos_convert_and_put_fifo_tx

	mov		REG_TEMP_R16, REG_X_LSB
	rcall		uos_convert_and_put_fifo_tx

	ldi		REG_Z_MSB, ((_uos_text_hexa_value_end << 1) / 256)
	ldi		REG_Z_LSB, ((_uos_text_hexa_value_end << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Marquage traces
; ---------
uos_print_mark_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_print_mark:
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 3

_uos_print_mark_loop:
	push		REG_TEMP_R16
	cpi		REG_TEMP_R16, 2
	brne		_uos_print_mark_loop_a
	mov		REG_TEMP_R16, REG_TEMP_R17
	rjmp		_uos_print_mark_loop_b

_uos_print_mark_loop_a:
	ldi		REG_TEMP_R16, '-'

_uos_print_mark_loop_b:
	rcall		uos_push_1_char_in_fifo_tx
	pop		REG_TEMP_R16
	dec		REG_TEMP_R16
	brne		_uos_print_mark_loop

	rcall		uos_print_line_feed

	pop		REG_TEMP_R16

	ret
; ---------

; ---------
; Traces pour les developpements
; ---------
uos_print_mark_3_char_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_print_mark_3_char:
	push		REG_TEMP_R16

	mov		REG_TEMP_R16, REG_TEMP_R17
	rcall		uos_push_1_char_in_fifo_tx

	mov		REG_TEMP_R16, REG_TEMP_R18
	rcall		uos_push_1_char_in_fifo_tx

	mov		REG_TEMP_R16, REG_TEMP_R19
	rcall		uos_push_1_char_in_fifo_tx

	pop		REG_TEMP_R16

	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un texte lu de l'EEPROM et termine par '\0'
; => Si un 0xff est lu (EEPROM non initialisee), abandon de la lecture
; => Limitation a 8 caracteres lus pour eviter un bouclage ;-)
;
; Usage:
;      ldi		REG_TEMP_R18, 8
;      ldi		REG_X_MSB, <address MSB>
;      ldi		REG_X_LSB, <address LSB>
;      rcall   uos_push_text_in_fifo_tx_from_eeprom
;
; ---------
uos_push_text_in_fifo_tx_from_eeprom_skip:
	lds		REG_TEMP_R23, UOS_G_FLAGS_0
	sbrc		REG_TEMP_R23, UOS_FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme

	ret

uos_push_text_in_fifo_tx_from_eeprom:
uos_push_text_in_fifo_tx_from_eeprom_loop:
	rcall		uos_eeprom_read_byte

	cpi		REG_TEMP_R16, 0xff
	breq		uos_push_text_in_fifo_tx_from_eeprom_end

	tst		REG_TEMP_R16
	breq		uos_push_text_in_fifo_tx_from_eeprom_end

	rcall		uos_push_1_char_in_fifo_tx

	adiw		REG_X_LSB, 1
	dec		REG_TEMP_R18
	brne		uos_push_text_in_fifo_tx_from_eeprom_loop

uos_push_text_in_fifo_tx_from_eeprom_end:
	ret
; ---------

; ---------
; Mise en FIFO/Tx d'un buffer 'C' defini en SRAM dans l'ordre "naturel"
; comme "### Enter in Program C (0x05a0)":
;       00000130  34 78 29 0a 00 23 23 23  20 45 6e 74 65 72 20 69  |4x)..### Enter i|
;       00000140  6e 20 50 72 6f 67 72 61  6d 20 43 20 28 30 78 30  |n Program C (0x0|
;       00000150  35 61 30 29 0a 00 20 20  20 20 20 20 20 20 20 20  |5a0)..          |
;
; Usage:
;    lds   r24, low('address_buffer')
;    lds   r25, high('address_buffer')
;    call  uos_puts
; ---------
uos_puts:
	movw		REG_X_LSB, REG_TEMP_R24

uos_puts_loop:
	ld			REG_TEMP_R16, X+
	cpi		REG_TEMP_R16, CHAR_NULL		; '\0' terminal ?
	breq		uos_puts_end

	mov		REG_R3, REG_TEMP_R16
	rcall		uos_uart_fifo_tx_write

	rjmp		uos_puts_loop

uos_puts_end:

	lds		REG_TEMP_R23, UOS_G_FLAGS_1
	sbr		REG_TEMP_R23, FLG_1_UART_FIFO_TX_TO_SEND_MSK	; Caracteres mis en FIFO a emettre ;-)
	sts		UOS_G_FLAGS_1, REG_TEMP_R23

	ret
; ---------

; ---------
; Retourne dans 'REG_Z_MSB:REG_Z_LSB' l'index pour l'affichage de la vitesse en Bauds @ 'UOS_G_HEADER_BAUDS_VALUE'
; ---------
get_index_bauds_rate_value:
; ---------
	ldi		REG_Z_MSB, high(const_for_bauds_rate_values << 1)
	ldi		REG_Z_LSB, low(const_for_bauds_rate_values << 1)

	; Longueur du texte defini sur 6 caracteres
	; +> Multiplication par 6 de l'adresse de base de la table 'const_for_bauds_rate_values'
	lds		REG_TEMP_R16, UOS_G_HEADER_BAUDS_VALUE
	mov		REG_TEMP_R17, REG_TEMP_R16
	lsl		REG_TEMP_R16						; REG_TEMP_R16 = (2 * REG_TEMP_R16)
	add		REG_TEMP_R16, REG_TEMP_R17		; REG_TEMP_R16 = (3 * REG_TEMP_R16)
	lsl		REG_TEMP_R16						; REG_TEMP_R16 = (6 * UOS_G_HEADER_BAUDS_VALUE)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16			; Z = (const_for_bauds_rate_values + 6 * UOS_G_HEADER_BAUDS_VALUE)

	ret
; ---------

; End of file
