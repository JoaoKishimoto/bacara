#include <avr/io.h>
#include "defs.h"


    .section .bss
scan_side:                 
    .skip 1

    .text

    .global display_init
display_init:
    ; segmentos a-d como saida 
    in   r24, _SFR_IO_ADDR(DDRD)
    ori  r24, 0xF0                  ; bits 4-7 = saida
    out  _SFR_IO_ADDR(DDRD), r24

    ; segmentos e-g + selecao como saida (PB0..PB4)
    in   r24, _SFR_IO_ADDR(DDRB)
    ori  r24, 0x1F                  ; bits 0-4 = saida
    out  _SFR_IO_ADDR(DDRB), r24

    ; desliga os dois displays 
    in   r24, _SFR_IO_ADDR(PORTB)
    andi r24, 0xE7                  ; limpa bits 3 e 4
    out  _SFR_IO_ADDR(PORTB), r24

    ; comeca a varredura pelo Jogador
    clr  r24
    sts  scan_side, r24

    ; Timer2 em modo normal (overflow), prescaler 64
    ;   overflow ~= 16MHz / 64 / 256 = 976 Hz
    ;   cada display e atualizado ~488 vezes/s -> sem flicker
    clr  r24
    sts  TCCR2A, r24                ; modo normal
    ldi  r24, (1<<CS22)             ; prescaler 64
    sts  TCCR2B, r24
    ldi  r24, (1<<TOIE2)            ; habilita interrupcao de overflow
    sts  TIMSK2, r24
    ret

    .global __vector_9
__vector_9:
    push r24
    in   r24, _SFR_IO_ADDR(SREG)
    push r24
    push r18
    push r25
    push r30
    push r31
    push r1
    clr  r1                         ; garante r1 = 0 

    ; 1 apaga ambos os displays (limpa PB3 e PB4)
    in   r24, _SFR_IO_ADDR(PORTB)
    andi r24, 0xE7
    out  _SFR_IO_ADDR(PORTB), r24

    ; qual lado mostrar nesta varredura?
    lds  r25, scan_side
    tst  r25
    brne mux_banca

mux_jogador:
    lds  r25, disp_left             ; digito do jogador
    rcall mux_segmentos             ; 2 escreve segmentos 
    in   r24, _SFR_IO_ADDR(PORTB)
    ori  r24, (1<<PB4)              ; 3 liga display esquerdo
    out  _SFR_IO_ADDR(PORTB), r24
    ldi  r25, 1                     ; proxima varredura: Banca
    sts  scan_side, r25
    rjmp mux_fim

mux_banca:
    lds  r25, disp_right            ; digito da banca
    rcall mux_segmentos
    in   r24, _SFR_IO_ADDR(PORTB)
    ori  r24, (1<<PB3)              ; liga display direito
    out  _SFR_IO_ADDR(PORTB), r24
    clr  r25                        ; proxima varredura: Jogador
    sts  scan_side, r25

mux_fim:
    pop  r1
    pop  r31
    pop  r30
    pop  r25
    pop  r18
    pop  r24
    out  _SFR_IO_ADDR(SREG), r24
    pop  r24
    reti
    
mux_segmentos:
    ;parte alta: segmentos a-d em PD4..PD7 
    ldi  ZL, lo8(font_pd)
    ldi  ZH, hi8(font_pd)
    add  ZL, r25
    adc  ZH, r1                     ; trata carry (r1 = 0)
    lpm  r24, Z                     ; padrao com bits 4-7
    in   r18, _SFR_IO_ADDR(PORTD)
    andi r18, 0x0F                  ; preserva PD0-PD3
    or   r18, r24
    out  _SFR_IO_ADDR(PORTD), r18

    ;parte baixa: segmentos e-g em PB0..PB2 
    ldi  ZL, lo8(font_pb)
    ldi  ZH, hi8(font_pb)
    add  ZL, r25
    adc  ZH, r1
    lpm  r24, Z                     ; padrao com bits 0-2
    in   r18, _SFR_IO_ADDR(PORTB)
    andi r18, 0xF8                  ; preserva PB3-PB7
    or   r18, r24
    out  _SFR_IO_ADDR(PORTB), r18
    ret

    .section .progmem.data,"a",@progbits
font_pd:
    .byte 0xF0,0x60,0xB0,0xF0,0x60,0xD0,0xD0,0x70,0xF0,0xF0,0x00,0x00
font_pb:
    .byte 0x03,0x00,0x05,0x04,0x06,0x06,0x07,0x00,0x07,0x06,0x00,0x04
