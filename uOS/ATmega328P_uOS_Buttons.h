; "$Id: ATmega328P_uOS_Buttons.h,v 1.2 2026/02/18 18:01:34 administrateur Exp $"

; Definitions pour la gestion de 4 boutons...
#define	UOS_BUTTON_1_NUM						1
#define	UOS_BUTTON_2_NUM						2
#define	UOS_BUTTON_3_NUM						3
#define	UOS_BUTTON_4_NUM						4

; Bits des boutons sur le PIND<4:5:6:7>
#define	BUTTON_1_MSK							MSK_BIT4
#define	BUTTON_2_MSK							MSK_BIT5
#define	BUTTON_3_MSK							MSK_BIT6
#define	BUTTON_4_MSK							MSK_BIT7

#define	BUTTON_1_IDX							IDX_BIT4
#define	BUTTON_2_IDX							IDX_BIT5
#define	BUTTON_3_IDX							IDX_BIT6
#define	BUTTON_4_IDX							IDX_BIT7

#define	DURATION_WAIT_STABILITY				10
#define	DURATION_BUTTON_LED					100
#define	DURATION_BUTTON_ACQ					200
#define	DURATION_WAIT_ACTION					500

#define	FLG_BUTTON_REPEAT_MSK			MSK_BIT4
#define	FLG_BUTTON_RISING_EDGE_MSK		MSK_BIT3
#define	FLG_BUTTON_PRESSED_MSK			MSK_BIT2
#define	FLG_BUTTON_FALLING_EDGE_MSK	MSK_BIT1
#define	FLG_BUTTON_WAIT_DONE_MSK		MSK_BIT0

#define	FLG_BUTTON_REPEAT_IDX			IDX_BIT4
#define	FLG_BUTTON_RISING_EDGE_IDX		IDX_BIT3
#define	FLG_BUTTON_PRESSED_IDX			IDX_BIT2
#define	FLG_BUTTON_FALLING_EDGE_IDX	IDX_BIT1
#define	FLG_BUTTON_WAIT_DONE_IDX		IDX_BIT0

#define	FLG_STATE_BUTTON_ACTION_MSK			MSK_BIT7		; Action a executer pour le bouton #N [1, 2, ...]
#define	FLG_STATE_BUTTON_SHORT_TOUCH_MSK		MSK_BIT6		; Appui "court" a l'expiration de 'TIMER_GEST_BUTTON_ACQ'
#define	FLG_STATE_BUTTON_LONG_TOUCH_MSK		MSK_BIT5		; Appui "long" a l'expiration de 'TIMER_GEST_BUTTON_ACQ'

#define	FLG_STATE_BUTTON_ACTION_IDX			IDX_BIT7		; Action a executer pour le bouton #N [1, 2, ...]
#define	UOS_FLG_STATE_BUTTON_SHORT_TOUCH_IDX		IDX_BIT6		; Appui "court" a l'expiration de 'TIMER_GEST_BUTTON_ACQ'
#define	FLG_STATE_BUTTON_LONG_TOUCH_IDX		IDX_BIT5		; Appui "long" a l'expiration de 'TIMER_GEST_BUTTON_ACQ'

#define	BUTTONS_MASK_1_2_3_4						(BUTTON_1_MSK | BUTTON_2_MSK | BUTTON_3_MSK | BUTTON_4_MSK)

#define	FLG_BUTTONS_1_2_3_4_VALID_MSK			MSK_BIT7		; 1! bouton est valide parmi les 4
#define	FLG_BUTTONS_1_2_3_4_LOW_MSK			MSK_BIT6		; Ce bouton est appuye
#define	FLG_BUTTONS_1_2_3_4_HIGH_MSK			MSK_BIT5		; Ce bouton est relache

#define	FLG_BUTTONS_1_2_3_4_VALID_IDX			IDX_BIT7		; 1! bouton est valide parmi les 4
#define	FLG_BUTTONS_1_2_3_4_LOW_IDX			IDX_BIT6		; Ce bouton est appuye
#define	FLG_BUTTONS_1_2_3_4_HIGH_IDX			IDX_BIT5		; Ce bouton est relache

.dseg

G_NUM_BUTTON:							.byte		1			; Numero du bouton en cours d'acquisition parmi [1, 2, 3, ...]
																	; avec les flags 'FLG_BUTTONS_1_2_3_4_xxx' renseignes
G_NUM_BUTTON_PRE:						.byte		1			; Numero du bouton precedent pour comparaison
G_FLAGS_BUTTON:						.byte		1			; Gestion des rebonds, appuis "court" et "long" d'un bouton
G_BUTTON_NBR_LONG_TOUCH:			.byte		1			; Nombre d'appuis "long" (sans relacher)
UOS_G_STATES_BUTTON:					.byte		1			; Etats du bouton a l'expiration de 'TIMER_GEST_BUTTON_ACQ'
UOS_G_STATES_BUTTON_NBR_TOUCH:	.byte		1			; et le nombre d'appuis avant expiration de 'TIMER_GEST_BUTTON_ACQ'

UOS_G_STATES_BUTTON_NOTIF:					.byte		1			; Recopie de 'G_STATES_BUTTON'...
UOS_G_STATES_BUTTON_NBR_TOUCH_NOTIF:	.byte		1			; ...pour une mise a disposition dans le traitement 1mS

; End of file
