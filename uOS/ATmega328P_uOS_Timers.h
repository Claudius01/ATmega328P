; "$Id: ATmega328P_uOS_Timers.h,v 1.2 2026/02/03 09:14:46 administrateur Exp $"

; Attribution des 'NBR_TIMER' timers #0, #1, ..., #7
; => Le traitement associe a chaque timer est effectue dans l'ordre de son index
#define	NBR_TIMER							16

; 10 Timers destines au PROGRAM
#define	TIMER_SPARE_0						0		; Reserve
#define	TIMER_SPARE_1						1		; Reserve
#define	TIMER_SPARE_2						2		; Reserve
#define	TIMER_SPARE_3						3		; Reserve
#define	TIMER_SPARE_4						4		; Reserve
#define	TIMER_SPARE_5						5		; Reserve
#define	TIMER_SPARE_6						6		; Reserve
#define	TIMER_SPARE_7						7		; Reserve
#define	TIMER_SPARE_8						8		; Reserve

; 7 Timers utilises par le BOOTLOADER
#define	TIMER_TEST_LEDS					9		; Timer pour le test Leds
#define	TIMER_GEST_BUTTON_LED			10		; Timer pour la presentation des appuis valides des boutons
#define	TIMER_GEST_BUTTON					11		; Timer pour la gestion des boutons (anti-rebonds et prise en compte)
#define	TIMER_GEST_BUTTON_ACQ			12		; Timer pour la mise a disposition du bouton appuye
#define	TIMER_ERROR							13		; Timer pour la presentation des erreurs (Led RED)
#define	TIMER_LED_GREEN					14		; Timer pour la presentation de l'etat Connecte/Non connecte
#define	TIMER_CONNECT						15		; Timer pour les connexions/deconnexions (reception sur RX)

#define	PERIODE_1MS							10		; Comptabilisation de 1mS -> Gestion des timers

.dseg

; Valeurs sur 16 bits des 'NBR_TIMER' accedees par indexation @ 'G_TIMER_0'
G_TIMER_0:						.byte		2		; 2 bytes pour la duree
G_TIMER_SPACE:					.byte		2 * (NBR_TIMER - 1)

; Contextes sur 16 bits des 'NBR_TIMER' accedees par indexation @ 'G_TIMER_CONTEXT_0'
G_TIMER_CONTEXT_0:			.byte		2		; 2 bytes pour le contexte
G_TIMER_CONTEXT_SPACE_0:	.byte		2 * (NBR_TIMER - 1)

; End of file

