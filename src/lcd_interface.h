#ifndef LCD_INTERFACE_H
#define LCD_INTERFACE_H

#include <stdint.h>

void lcd_init(void);
void lcd_message(uint8_t msg_id);                   // msg_id: MSG_* de defs.h
void lcd_scores(uint8_t player, uint8_t banker);    // player, banker: 0..9
void lcd_cards(uint8_t who);                        // who: 0 = Jogador, 1 = Banca
void lcd_clear(void);

#endif 