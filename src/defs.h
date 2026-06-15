/* defs.h  —  Contrato compartilhado do projeto Bacará */

#ifndef DEFS_H
#define DEFS_H

#ifndef F_CPU
#define F_CPU 16000000UL     /* Arduino Nano = 16 MHz */
#endif
#include <avr/io.h>

/*  MÁQUINA DE ESTADOS   (game_state)  */
#define ST_IDLE     0
#define ST_BET      1
#define ST_DEAL     2
#define ST_THIRD    3
#define ST_RESULT   4

/*  APOSTAS   (bet_type)  — setado pelas ISRs dos botões  */
#define BET_NONE    0
#define BET_PLAYER  1
#define BET_BANKER  2
#define BET_TIE     3

/*  RESULTADO   (variável: result)  */
#define RES_BANKER  0
#define RES_PLAYER  1
#define RES_TIE     2

/*  BITS DA FLAG GLOBAL   (flags)  — comunicação ISR -> main loop  */
#define FLG_NEW_BET  0

/*  MENSAGENS PARA O LCD   (argumento de lcd_message)  */
#define MSG_PLACE_BET    0
#define MSG_BET_PLAYER   1
#define MSG_BET_BANKER   2
#define MSG_BET_TIE      3
#define MSG_DEALING      4
#define MSG_PLAYER_WINS  5
#define MSG_BANKER_WINS  6
#define MSG_TIE          7
#define MSG_YOU_WIN      8
#define MSG_YOU_LOSE     9

/*  LCD (4-bit, paralelo)  — mapeado em PORTC  */
#define LCD_RS_BIT      PC0
#define LCD_EN_BIT      PC1
#define LCD_DATA_SHIFT  2       /* nibble de dados começa em PC2 */
#define LCD_DATA_MASK   0x3C        /* PC2..PC5 */
#define LCD_DDR_MASK    ((1<<LCD_RS_BIT)|(1<<LCD_EN_BIT)|LCD_DATA_MASK)

/*  TABELA DE FONTE  (display.S)
 *     Formato: b0=a b1=b b2=c b3=d b4=e b5=f b6=g b7=livre  */
#define DISP_BLANK  10      /*  display apagado  */
#define DISP_DASH   11      /*  traço "-"  */

#endif