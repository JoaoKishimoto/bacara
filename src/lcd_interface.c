/* lcd_interface.c — Driver do LCD 16x2 (HD44780)
 * Modo 4 bits, write-only
 * Ligado na PORTC. Bits definidos em defs.h:
 *     RS -> PC0      EN -> PC1
 *     D4..D7 -> PC2..PC5   (LCD_DATA_SHIFT = 2)
*/

#include "defs.h"
#include "lcd_interface.h"
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

extern volatile uint8_t player_cards[3], banker_cards[3];
extern volatile uint8_t player_count, banker_count;


/* Escreve um nibble (4 bits) nas linhas de dados e gera o pulso de EN. */
static void lcd_send4(uint8_t v) {
    PORTC &= ~LCD_DATA_MASK;
    PORTC |= ((v & 0x0F) << LCD_DATA_SHIFT);
    
    PORTC |= (1 << LCD_EN_BIT);
    _delay_us(1);
    PORTC &= ~(1 << LCD_EN_BIT);   /* o LCD captura o nibble na descida do EN */
    _delay_us(40);
}

/* Comando (RS=0). O cli() protege o pulso de EN da ISR de multiplexação. */
static void lcd_cmd(uint8_t c) {
    uint8_t sreg = SREG;        /* salva o estado das interrupções */
    cli();                      /* trava p/ a ISR não estourar a temporização do EN */
    PORTC &= ~(1<<LCD_RS_BIT);  /* RS = 0 → comando */
    lcd_send4(c >> 4);
    lcd_send4(c & 0x0F);
    SREG = sreg;
    _delay_ms(2);
}

// ISRs desabilitadas durante o envio para não corromper o pulso EN
static void lcd_data(uint8_t d) {
    uint8_t sreg = SREG;
    cli();
    PORTC |= (1<<LCD_RS_BIT);   /* RS = 1 → dado */
    lcd_send4(d >> 4);
    lcd_send4(d & 0x0F);
    SREG = sreg;
    _delay_us(40);
}

/* Sequência de inicialização 4-bit do datasheet (re-sincroniza o controlador). */
static void lcd_soft_reset(void) {
    PORTC &= ~(1<<LCD_RS_BIT);
    lcd_send4(0x03);
    _delay_ms(5);
    lcd_send4(0x03);
    _delay_us(150);
    lcd_send4(0x03);
    lcd_send4(0x02);
    lcd_cmd(0x28);       /* Function Set: 4 bits, 2 linhas, fonte 5x8 */
    lcd_cmd(0x0C);       /* Display ON, cursor OFF, blink OFF */
    lcd_cmd(0x06);       /* Entry Mode: auto-incrementa o cursor, sem shift da tela */
}

void lcd_clear(void) {
    lcd_soft_reset();
    lcd_cmd(0x01);
}

static void lcd_set_cursor(uint8_t col, uint8_t row) {
    lcd_cmd(0x80 + (row ? 0x40 : 0) + col);
}

static void lcd_print_str(const char *s) {
    while (*s) {
        lcd_data((uint8_t)*s++);
    }
}

static const char *const card_labels[14] = {
    "", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"
};
static void lcd_print_card(uint8_t rank) {
    lcd_print_str(card_labels[rank]);
}

static const char *const messages[] = {
    "Faca sua aposta",   
    "Aposta: Jogador",   
    "Aposta: Banca",     
    "Aposta: Empate",    
    "Distribuindo...",   
    "Jogador vence",     
    "Banca vence",       
    "Empate",            
    "Voce ganhou!",      
    "Voce perdeu"        
};


void lcd_init(void) {
    DDRC |= LCD_DDR_MASK;   /* PC0-PC5 como saída */

    _delay_ms(50);
    PORTC &= ~(1<<LCD_RS_BIT);

    /* Sequência de inicialização 4-bit obrigatória */
    lcd_send4(0x03);
    _delay_ms(5);
    lcd_send4(0x03);
    _delay_us(150);
    lcd_send4(0x03);
    lcd_send4(0x02);        /* muda para 4 bits */

    lcd_cmd(0x28);
    lcd_cmd(0x0C);
    lcd_cmd(0x06);
    lcd_clear();
}

void lcd_message(uint8_t msg_id) {
    lcd_clear();
    lcd_set_cursor(0, 0);
    lcd_print_str(messages[msg_id]);
}

void lcd_scores(uint8_t player, uint8_t banker) {
    lcd_clear();
    
    lcd_set_cursor(0, 0);
    lcd_print_str("Jogador: ");
    lcd_data('0' + player);
    
    lcd_set_cursor(0, 1);
    lcd_print_str("Banca:   ");
    lcd_data('0' + banker);
}

void lcd_cards(uint8_t who) {
    volatile uint8_t *cards = who ? banker_cards : player_cards;
    uint8_t n               = who ? banker_count  : player_count;

    lcd_set_cursor(0, who & 1); 
    lcd_print_str(who ? "B:" : "J:");
    
    for (uint8_t i = 0; i < n; i++) {
        lcd_data(' ');
        lcd_print_card(cards[i]); 
    }
}