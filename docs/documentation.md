# Documentação — interruptions.S

---

## 1. O que este arquivo faz

Este módulo é responsável por toda a entrada do jogador, ela serve como uma interface dos botões, ditando a lógica de interrupção ao pressinar os botões. Além disso esse arquivo é responsável pelo registro da aposta que o usuário fez.

Em nosso projeto definimos rotinas de interrupção curtas, elas apenas anotam o que o jogador fez (em variáveis na SRAM) e devolvem o controle imediatamente. Toda a reação ao evento como mostrar a mensagem no LCD, distribuir as cartas, calcular resultado, fica a cargo da máquina de estados no main.S.

---

## 2. Contexto de hardware

Os três botões do jogo estão ligados no microcontrolador da seguinte forma (Botão, pino arduíno, interrupção, aposta registrada):

| Função | Pino Arduino | Porta AVR | Interrupção |
|---|---|---|---|
| Apostar em Jogador | D2 | PD2 | INT0 (borda de descida) |
| Apostar em Banca | D3 | PD3 | INT1 (borda de descida) |
| Apostar em Empate | D13 | PB5 | PCINT5 (qualquer borda) |

Para os botões de Jogador e Banca optamos pelos pinos de interrupção externa dedicada (INT0 e INT1), que nos permitem configurar o disparo diretamente na borda de descida, ou seja, no instante exato do aperto. Já o botão de Empate ficou num pino de pin change (PCINT), que não deixa escolher a borda do disparo, então esse detalhe vai acaber sendo tratado dentro da própria rotina.

---

## 3. Dependências

Constantes (definidas em defs.h):

- BET_PLAYER, BET_BANKER, BET_TIE — códigos do tipo de aposta.
- FLG_NEW_BET — número do bit, na variável flags, que sinaliza "aposta nova".

Variáveis compartilhadas (alocadas em state.S, na .bss; este arquivo só acessa):

- bet_type — recebe o código da aposta escolhida.
- flags — tem o bit FLG_NEW_BET levantado a cada nova aposta.

Vetores de interrupção utilizados (ATmega328P):

- __vector_1 → INT0
- __vector_2 → INT1
- __vector_3 → PCINT0

---

## 4. Rotinas

### 4.1. buttons_init 

Essa rotina serve para preparar os pinos dos botões e habilitar as interrupções, vai ser chamada uma única vez pelo main durante a inicialização, antes do sei. Ela não possui parâmetros nem retorno

O que ela configura, em ordem:

1. PD2 e PD3 como entrada — andi DDRD, 0xF3 zera os bits 2 e 3 sem afetar os demais.
2. Pull-up em PD2 e PD3 — ori PORTD, (1<<PD2)|(1<<PD3).
3. PB5 como entrada — andi DDRB, 0xDF zera o bit 5.
4. Pull-up em PB5 — ori PORTB, (1<<PB5).
5. Borda de descida para INT0 e INT1 — EICRA recebe (1<<ISC01)|(1<<ISC11)
6. Habilita INT0 e INT1 — EIMSK recebe (1<<INT0)|(1<<INT1).
7. Habilita o pino do pin change — PCMSK0 recebe (1<<PCINT5)
8. Habilita o grupo de pin change — PCICR recebe (1<<PCIE0)

---

### 4.2. __vector_1 — Interrupção INT0 (botão Jogador)

Possui um disparo automático, na borda de descida de PD2.

Ações Realizadas:

1. Salva r24 e o registrador de status SREG na pilha.
2. Grava BET_PLAYER em bet_type.
3. Levanta o bit FLG_NEW_BET em flags.
4. Restaura SREG e r24.
5. Retorna com reti.

---

### 4.3. __vector_2 — Interrupção INT1 (botão Banca)

É exatamente a mesma coisa de "__vector_1", a única diferença é que grava BET_BANKER em bet_type.

---

### 4.4. __vector_3 — Interrupção PCINT0 (botão Empate)

Também possui um disparo automático, em qualquer mudança de estado em PB5 (tanto ao apertar quanto ao soltar)

Ações:

1. Salva r24 e o SREG.
2. Confere o nível do pino com sbic PINB, PB5: se PB5 estiver em alto (botão solto), executa rjmp pcint0_fim e ignora o evento, se estiver em baixo (pressionado), prossegue.
3. Grava BET_TIE em bet_type.
4. Levanta FLG_NEW_BET em flags.
5. Restaura SREG e r24, retorna com reti.

Aqui verificação do tópico 2 é necessária porque o pin change dispara nas duas bordas. Sem ela, o Empate registraria a aposta duas vezes: uma ao apertar e outra ao soltar. INT0 e INT1 não precisam dessa verificação porque já são configuradas para disparar apenas na descida.

---

## 6. Integração com o main.S


; durante a inicializacao:
rcall buttons_init      ; configura botoes e interrupcoes
sei                     ; habilita interrupcoes globais (depois dos inits)

; no laco principal, ao detectar jogada:
lds  r24, flags
sbrs r24, FLG_NEW_BET   ; bit levantado por alguma ISR?
rjmp (sem jogada)
; ... le bet_type, age conforme a aposta, e limpa FLG_NEW_BET ...

