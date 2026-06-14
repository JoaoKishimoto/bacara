#include <avr/io.h>
#include "defs.h"

    .text

    .global buttons_init
buttons_init:                               ;inicialização dos botões
    in   r24, _SFR_IO_ADDR(DDRD)            ;designação do botao jogador e banca
    andi r24, 0xF3
    out  _SFR_IO_ADDR(DDRD), r24
    in   r24, _SFR_IO_ADDR(PORTD)
    ori  r24, (1<<PD2)|(1<<PD3)             ;habilita pull up interno
    out  _SFR_IO_ADDR(PORTD), r24

    in   r24, _SFR_IO_ADDR(DDRB)            ;botão empate
    andi r24, 0xDF
    out  _SFR_IO_ADDR(DDRB), r24
    in   r24, _SFR_IO_ADDR(PORTB)
    ori  r24, (1<<PB5)
    out  _SFR_IO_ADDR(PORTB), r24

    ldi  r24, (1<<ISC01)|(1<<ISC11)
    sts  EICRA, r24
    in   r24, _SFR_IO_ADDR(EIMSK)           ;interrupcoes externas
    ori  r24, (1<<INT0)|(1<<INT1)
    out  _SFR_IO_ADDR(EIMSK), r24

    ldi  r24, (1<<PCINT5)
    sts  PCMSK0, r24
    lds  r24, PCICR
    ori  r24, (1<<PCIE0)
    sts  PCICR, r24
    ret

    .global __vector_1                         ;botão jogador
__vector_1:
    push r24
    in   r24, _SFR_IO_ADDR(SREG)
    push r24
    ldi  r24, BET_PLAYER
    sts  bet_type, r24
    lds  r24, flags
    ori  r24, (1<<FLG_NEW_BET)
    sts  flags, r24
    pop  r24
    out  _SFR_IO_ADDR(SREG), r24
    pop  r24
    reti

    .global __vector_2                          ;botão banca
__vector_2:
    push r24
    in   r24, _SFR_IO_ADDR(SREG)
    push r24
    ldi  r24, BET_BANKER
    sts  bet_type, r24
    lds  r24, flags
    ori  r24, (1<<FLG_NEW_BET)
    sts  flags, r24
    pop  r24
    out  _SFR_IO_ADDR(SREG), r24
    pop  r24
    reti

    .global __vector_3                          ;botão empate
__vector_3:
    push r24
    in   r24, _SFR_IO_ADDR(SREG)
    push r24
    sbic _SFR_IO_ADDR(PINB), PB5
    rjmp pcint0_fim
    ldi  r24, BET_TIE
    sts  bet_type, r24
    lds  r24, flags
    ori  r24, (1<<FLG_NEW_BET)
    sts  flags, r24
pcint0_fim:
    pop  r24
    out  _SFR_IO_ADDR(SREG), r24
    pop  r24
    reti
