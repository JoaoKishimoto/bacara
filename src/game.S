#include "defs.h"

;  game.S  -  Logica do jogo Bacara (ATmega328P)
    .global sorteia_carta
sorteia_carta:
    ; Primeira parte: Sorteio dos números  
    LDS  r24, rng_state		 ; 
    LSR  r24                 ; desloca os bits pra direita para gerar um número totalmente aleatório
    BRCC fim_lfsr            ; se saiu 0, pula o XOR
    LDI  r25, 0xB8					
    EOR  r24, r25            ; mistura (XOR com os taps)
fim_lfsr:
    STS  rng_state, r24      ; salva nova posicao do LFSR

    ; Segunda parte: calcular o módulo de 13
filtra_modulo:
    CPI  r24, 13			 ; compara com 13
    BRLO converte_rank       ; se for menor ja achamos
    SUBI r24, 13			 ; subtrai por 13 até achar o primeiro valor menor que 13(equivalente a achar o modulo de 13) 
    RJMP filtra_modulo		 

converte_rank:
    INC  r24                 ; incrementa um para ficar no padrão do jogo(1 a 13)
    RET                      ; retorna o rank 

;  função valor_carta para converter o rank para o valor do bacara(0 a 9) 
;  tem como entrada: r24 = rank (de 1 a 13)  
;  tem como saida: r24 = valor do bacará (0 a 9)   ; 10,J,Q,K valem 0; e de As até 9 valem o proprio número
;  Funcao folha (so usa r24).

    .global valor_carta
valor_carta:				 
    CPI  r24, 10			
    BRLO vc_fim              ; se for de 0 a 9 ja sao o proprio valor
    LDI  r24, 0              ; se for 10,11(J),12(Q),13(K) converte para 0(valor bacará)
vc_fim:
    RET

;  calcula_pontuacao soma ate 3 cartas 
;  tem como entradas: r24 = soma da primeira carta, r22 = soma da segunda carta, r20 = soma da terceira carta (0 = sem carta)
;  tem como saida:    r24 = pontuacao final (0 a 9)
;  Converte cada carta com a função valor_carta antes de somar (senao um "10" somaria 10 em vez de 0). Acumula em r23 pra nao perder o valor entre chamadas.
    .global calcula_pontuacao
calcula_pontuacao:
    push r23			
    push r22
    push r20

    rcall valor_carta        ; r24 = valor da primeira carta
    mov  r23, r24            ; acumulador 

    mov  r24, r22
    rcall valor_carta        ; r24 = valor da segunda carta
    add  r23, r24

    mov  r24, r20
    rcall valor_carta        ; r24 = valor da terceira carta 
    add  r23, r24

    mov  r24, r23
filtra_dezena:			;função para converter a pontuação final no valor do bacará(pois se for 15, a pontuação é 5) filtrando a dezena
    CPI  r24, 10		;verifica se é menor que 10
    BRLO fim_pontuacao	;se for menor que 10, já é ela mesma
    SUBI r24, 10		;caso contrário, subtraimos 10 
    RJMP filtra_dezena
fim_pontuacao:
    pop  r20
    pop  r22
    pop  r23
    RET
;  função checa_natural vericamos se jogador ou Banca fizeram 8 ou 9 na mao inicial(servirá de auxiliar para a 3 carta)
;  tem como entradas: r24 = placar do jogador, r22 = placar da banca (ja no valor do bacará)
;  tem como saida: r24 = 1(sem terceira carta) | 0 (terceira carta)

    .global checa_natural
checa_natural:
    CPI  r24, 8			
    BREQ deu_natural
    CPI  r24, 9
    BREQ deu_natural
    CPI  r22, 8
    BREQ deu_natural
    CPI  r22, 9				;se for 8 ou 9 não tem terceira carta, então chama deu_natural para passar o valor 1
    BREQ deu_natural		
    LDI  r24, 0				;caso contrário, recebe o valor de 0 para comprar a terceira carta
    RET
deu_natural:
    LDI  r24, 1
    RET

;  a função decide_simples é uma regra de "saque"  (0 a 5 compra, 6 a 7 fica)
;  Usada para: (a) o jogador sempre; (b) a Banca quando o jogador nao comprou.
;  tem como entrada: r24 = score (de 0 a 9)
;  tem como saida:   r24 = 1 (compra da 3a carta) | 0 (fica)
    .global decide_simples
decide_simples:
    CPI  r24, 6
    BRLO ds_compra           ; 0 a 5 compra
    LDI  r24, 0              ; 6,7 (e mais) fica 
    RET
ds_compra:
    LDI  r24, 1
    RET
;  função decide_banca_p3  é a tabela de saque da Banca quando o jogador comprou
;  tem como entradas: r24 = banker_score (0 a 9), r22 = p3 (valor 0 a 9 da 3a carta do jogador)
;  tem como saida: r24 = 1 (banca compra) | 0 (banca fica)
;  Tabela oficial do Bacara:
;    score 0,1,2 sempre compra
;    score 3 compra, exceto se p3 == 8
;    score 4 compra se p3 in [2 a 7]
;    score 5 compra se p3 in [4 a 7]
;    score 6 compra se p3 in [6,7]
;    score 7 (e maior) nunca compra
    .global decide_banca_p3
decide_banca_p3:
    CPI  r24, 3
    BRLO db_compra           ; 0,1,2 sempre compra
    BREQ db_3                ; ==3
    CPI  r24, 4
    BREQ db_4
    CPI  r24, 5
    BREQ db_5
    CPI  r24, 6
    BREQ db_6
    RJMP db_fica             ; 7 (e qualquer >6 que nao bateu) fica

db_3:
    CPI  r22, 8
    BREQ db_fica             ; p3 == 8 fica
    RJMP db_compra           ; p3 != 8 compra

db_4:
    CPI  r22, 2
    BRLO db_fica             ; p3=2 fica
    CPI  r22, 8
    BRSH db_fica             ; p3 >= 8 fica
    RJMP db_compra           ; se p3 in [2 a 7] compra

db_5:
    CPI  r22, 4
    BRLO db_fica             ; se p3 4 fica
    CPI  r22, 8
    BRSH db_fica             ; se p3 >= 8 fica
    RJMP db_compra           ; se p3 in [4 a 7] compra

db_6:
    CPI  r22, 6
    BREQ db_compra
    CPI  r22, 7
    BREQ db_compra
    RJMP db_fica             ; se p3 != 6 e != 7 fica

db_compra:
    LDI  r24, 1
    RET
db_fica:
    LDI  r24, 0
    RET
;  função define_vencedor compara os placares finais
;  tem como entradas: r24 = placar final jogador, r22 = placar final banca (de 0 a 9)
;  tem como saida: r24 = RES_PLAYER (1) | RES_BANKER (2) | RES_TIE (3)

    .global define_vencedor
define_vencedor:
    CP   r24, r22
    BREQ deu_empate
    BRLO banca_ganhou        ; jogador < banca (unsigned lower)
jogador_ganhou:
    LDI  r24, RES_PLAYER
    RET
banca_ganhou:
    LDI  r24, RES_BANKER
    RET
deu_empate:
    LDI  r24, RES_TIE
    RET						;verifica o vencedor 