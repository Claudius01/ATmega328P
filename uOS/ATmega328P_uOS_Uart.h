; "$Id: ATmega328P_uOS_Uart.h,v 1.1 2026/01/26 17:47:34 administrateur Exp $"

; Gestion de l'UART
; -----------------
; - FLG_0_UART_DETECT_LINE_IDLE: Passage a 1 si ligne RXD a l'etat haut durant au moins 10 bits;
;   => Soit 40 acquisitions concecutives espacees de 13uS = 520uS correspondant a 10 bits a 9600 bauds
; - FLG_0_UART_DETECT_BIT_START: Si 'FLG_0_UART_DETECT_LINE_IDLE' a 1, passage a 1 sur detection du bit START
;   => Acquisition au moyen de la detection du front descendant sur RXD (cf. 'int0_isr')
;   => Conservation de 'FLG_0_UART_DETECT_LINE_IDLE' et de 'FLG_0_UART_DETECT_BIT_START' a 1 jusqu'a
;      la fin de l'acquisition d'un byte UART (1 start + 8 datas + 1 stop)
;      => Passage a 0 de 'FLG_0_UART_DETECT_BIT_START' pour relancer la detaction du bit START
; - FLG_0_UART_DETECT_BYTE: Passage a 1 pour indiquer donnee UART disponible jusqu'a sa lecture
;   pour traitement (ie. ecriture dans la FIFO/UART RX)
;
; => 1 - L'acquisition des donnees UART commence des que les 2 flags 'FLG_0_UART_DETECT_LINE_IDLE' et
;    'FLG_0_UART_DETECT_BIT_START' sont a 1
;
;    2 - A la fin de l'acquisition, le flag 'FLG_0_UART_DETECT_BIT_START' est remis a 0
;        pour une detection du bit START
;
;    => 'FLG_0_UART_DETECT_LINE_IDLE' est remis a 0 sur erreur de communication comme:
;       - Pas de bit START lu au 1st bit apres la detection --\__ (Frame Error)
;       - Pas de bit STOP lu au 10th bit (Frame Error)
;       - Donnee non attendue @ protocole
;       - A completer...
;

.dseg

G_UART_CPT_LINE_IDLE_LSB:	.byte		1		; Compteur de 16 bits pour la detection de la ligne IDLE
G_UART_CPT_LINE_IDLE_MSB:	.byte		1

G_UART_BYTE_TX:				.byte		1		; Byte a emettre sur TXD

; FIFO UART/Rx
#define	SIZE_UART_FIFO_RX			64			; Puissance de 2 pour un modulo SIZE_UART_FIFO_RX

G_UART_FIFO_RX_WRITE:		.byte		1
G_UART_FIFO_RX_READ:			.byte		1
G_UART_FIFO_RX_DATA:			.byte		(SIZE_UART_FIFO_RX - 1)		; 1st byte de la FIFO/Rx
G_UART_FIFO_RX_DATA_END:	.byte		1									; Last byte de la FIFO/Rx

; FIFO UART/Tx
#define	SIZE_UART_FIFO_TX			256		; Puissance de 2 pour un modulo SIZE_UART_FIFO_TX

G_UART_FIFO_TX_WRITE:		.byte		1
G_UART_FIFO_TX_READ:			.byte		1
G_UART_FIFO_TX_DATA:			.byte		(SIZE_UART_FIFO_TX - 1)		; 1st byte de la FIFO/Tx
G_UART_FIFO_TX_DATA_END:	.byte		1									; Last byte de la FIFO/Tx

; End of file

