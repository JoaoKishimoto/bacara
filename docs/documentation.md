# Documentação - Projeto Bacará

Este documento detalha o esquemático elétrico, as decisões de montagem do circuito físico e virtual (SimulIDE), e a implementação das rotinas de interrupção (ISRs) para a execução do jogo Bacará utilizando o microcontrolador ATmega328P. O circuito foi projetado para espelhar exatamente a montagem na protoboard física, garantindo que o código em Assembly opere de forma idêntica em ambos os ambientes.

## Parte I: Especificação do Hardware

### 1. Componentes Utilizados

- 1x Placa Arduino Nano (ATmega328P)
- 2x Displays de 7 Segmentos (Cátodo Comum)
- 2x Transistores NPN (BC548 ou equivalente)
- 1x Display LCD 16x2
- 3x Chaves Tácteis (Push buttons)
- 7x Resistores de 330 Ω (para os segmentos do display)
- 3x Resistores de 1 kΩ (2 para a base dos transistores, 1 para pull-up externo)

### 2. Mapeamento de Pinos

A tabela abaixo descreve a alocação de portas digitais e analógicas do ATmega328P para os periféricos do sistema.

| Componente            | Pino Arduino | Função Específica                                       |
| :-------------------- | :----------- | :------------------------------------------------------ |
| **Botões**            | D2           | Aposta: Jogador (Interrupção INT0)                      |
|                       | D3           | Aposta: Banca (Interrupção INT1)                        |
|                       | D13          | Aposta: Empate (Interrupção PCINT5)                     |
| **Barramento 7 Seg.** | D4 ao D10    | Controle dos segmentos A até G, respectivamente.        |
| **Multiplexação**     | D11          | Chaveamento do display da Banca (Transistor Direito)    |
|                       | D12          | Chaveamento do display do Jogador (Transistor Esquerdo) |
| **Display LCD**       | A0           | Pino RS do LCD                                          |
|                       | A1           | Pino Enable (E) do LCD                                  |
|                       | A2 ao A5     | Pinos de dados D4, D5, D6 e D7 do LCD                   |

### 3. Detalhamento das Ligações

#### 3.1. Botões, Pull-up Interno e Externo

Os três botões foram aterrados na mesma linha de GND do circuito, operando com lógica invertida (pressionar gera nível baixo). No entanto, há uma diferença no modo como o estado lógico alto é garantido:

- **Jogador (D2) e Banca (D3):** Conectados diretamente, sem resistores físicos externos. O estado alto é mantido via software pela ativação dos resistores de _pull-up_ internos do ATmega328P.
- **Empate (D13):** Utiliza um **resistor de pull-up externo de 1 kΩ** conectado à linha de 5V. Como a placa Arduino Nano possui um LED _onboard_ integrado diretamente ao pino D13 (que drena corrente para a terra), o _pull-up_ interno do microcontrolador é insuficiente para garantir um nível lógico alto estável. O resistor externo contorna essa limitação física da placa.

#### 3.2. Displays de 7 Segmentos e Varredura

Para economizar portas digitais, os dois displays de 7 segmentos compartilham o mesmo barramento de dados. Os pinos A a G do display do Jogador estão ligados em paralelo aos pinos A a G do display da Banca, protegidos por uma única barreira de resistores de 330 Ω ligada entre os pinos D4 e D10.

O controle de acionamento é feito por dois transistores NPN operando como chaves no lado de baixo (aterramento). A corrente sai do pino comum (cátodo) de cada display e entra no coletor do transistor. Quando os pinos D11 ou D12 enviam nível lógico alto para a base (protegida por resistores de 1 kΩ), o transistor satura e escoa a corrente para o GND, acendendo o display selecionado naquele ciclo de varredura.

#### 3.3. Interface do LCD (Alteração de Projeto)

Inicialmente planejado para operar via protocolo I2C (módulo PCF8574), o diagrama final consolidou a conexão do display LCD 16x2 de forma direta no modo de 4 bits. Os pinos de controle (RS e Enable) e o barramento de dados (D4-D7) foram mapeados para as portas A0 a A5 do Arduino. Como essas portas analógicas também operam perfeitamente como GPIOs (saídas digitais), essa configuração remove a necessidade do módulo I2C adicional, simplifica a fiação na protoboard física e elimina potenciais conflitos de temporização no barramento durante a ocorrência das interrupções do jogo. O pino RW do LCD foi permanentemente aterrado, já que o sistema fará apenas operações de escrita na tela.

---

## Parte II: Documentação de Software — `interruptions.S`

---

## 1. O que este arquivo faz

Este módulo é responsável por toda a entrada do jogador, ela serve como uma interface dos botões, ditando a lógica de interrupção ao pressinar os botões. Além disso esse arquivo é responsável pelo registro da aposta que o usuário fez.

Em nosso projeto definimos rotinas de interrupção curtas, elas apenas anotam o que o jogador fez (em variáveis na SRAM) e devolvem o controle imediatamente. Toda a reação ao evento como mostrar a mensagem no LCD, distribuir as cartas, calcular resultado, fica a cargo da máquina de estados no main.S.

---

## 2. Contexto de hardware

Os três botões do jogo estão ligados no microcontrolador da seguinte forma (Botão, pino arduíno, interrupção, aposta registrada):

| Função             | Pino Arduino | Porta AVR | Interrupção             |
| ------------------ | ------------ | --------- | ----------------------- |
| Apostar em Jogador | D2           | PD2       | INT0 (borda de descida) |
| Apostar em Banca   | D3           | PD3       | INT1 (borda de descida) |
| Apostar em Empate  | D13          | PB5       | PCINT5 (qualquer borda) |

Para os botões de Jogador e Banca optamos pelos pinos de interrupção externa dedicada (INT0 e INT1), que nos permitem configurar o disparo diretamente na borda de descida, ou seja, no instante exato do aperto. Já o botão de Empate ficou num pino de pin change (PCINT), que não deixa escolher a borda do disparo, então esse detalhe vai acaber sendo tratado dentro da própria rotina.

---

## 3. Dependências

Constantes (definidas em defs.h):

- BET_PLAYER, BET_BANKER, BET_TIE — códigos do tipo de aposta.
- FLG_NEW_BET — número do bit, na variável flags, que sinaliza "aposta nova".

Variáveis compartilhadas (alocadas em state.S, na .bss, este arquivo só acessa):

- bet_type — recebe o código da aposta escolhida.
- flags — tem o bit FLG_NEW_BET levantado a cada nova aposta.

Vetores de interrupção utilizados:

- \_\_vector_1 → INT0
- \_\_vector_2 → INT1
- \_\_vector_3 → PCINT0

---

## 4. Rotinas

### 4.1. buttons_init

Essa rotina serve para preparar os pinos dos botões e habilitar as interrupções, vai ser chamada uma única vez pelo main durante a inicialização, antes do sei. Ela não possui parâmetros nem retorno.

O mapeamento começa configurando os pinos PD2 e PD3 como entrada, aplicando a instrução `andi DDRD, 0xF3` para zerar os bits 2 e 3 sem afetar o restante da porta D. Logo em seguida, os resistores de pull-up internos desses mesmos pinos são ativados através do comando `ori PORTD, (1<<PD2)|(1<<PD3)`. O mesmo processo de entrada é feito para o pino PB5, limpando o bit 5 com `andi DDRB, 0xDF`, seguido imediatamente pela habilitação do seu pull-up com `ori PORTB, (1<<PB5)`.

Com os pinos devidamente prontos, a rotina passa a configurar o comportamento das interrupções externas. Primeiro, define o disparo por borda de descida para as interrupções INT0 e INT1 enviando `(1<<ISC01)|(1<<ISC11)` para o registrador EICRA, liberando o funcionamento de ambas logo depois ao gravar `(1<<INT0)|(1<<INT1)` no registrador EIMSK. Por fim, o pino específico do pin change é habilitado escrevendo `(1<<PCINT5)` em PCMSK0, e o grupo completo de interrupções por mudança de pino é ligado de fato ao enviar `(1<<PCIE0)` para o registrador de controle PCICR.

---

### 4.2. \_\_vector_1 — Interrupção INT0 (botão Jogador)

Esta rotina possui um disparo automático que ocorre sempre que há uma borda de descida no pino PD2, quando é acionada, ela realiza o salvamento do registrador r24 e do registrador de status SREG diretamente na pilha para preservar o estado do programa principal. Na sequência, ela grava o código BET_PLAYER dentro da variável bet_type e levanta o bit FLG_NEW_BET na variável flags para sinalizar ao sistema que uma nova aposta tá sendo feita. No final, a rotina restaura os valores originais de SREG e r24 de volta aos seus registradores e finaliza a execução retornando com a instrução `reti`.

---

### 4.3. \_\_vector_2 — Interrupção INT1 (botão Banca)

Esta rotina funciona exatamente da mesma forma que a interrupção do jogador anterior. A única mudança real em sua execução é que ela grava o código de identificação BET_BANKER na variável bet_type, registrando a intenção de aposta do usuário na banca.

---

### 4.4. \_\_vector_3 — Interrupção PCINT0 (botão Empate)

Esta rotina também conta com um disparo automático, mas atua diante de qualquer mudança de estado no pino PB5, o que significa que ela vai rodar tanto quando o jogador apertar o botão quanto quando ele o soltar. Logo no início, o código faz o salvamento preventivo do registrador r24 e do SREG na pilha. Feito isso, a rotina confere imediatamente o nível atual do pino usando a instrução `sbic PINB, PB5`. Se o pino PB5 estiver em nível alto, indicando que o botão acabou de ser solto, a execução desvia para o rótulo pcint0_fim e ignora completamente o evento. Caso o pino esteja em nível baixo, indicando um aperto real, o fluxo prossegue para gravar o código BET_TIE em bet_type e levantar a flag FLG_NEW_BET em flags. Por fim, o contexto é restaurado e a execução se encerra com um `reti`.

Essa verificação de nível lógico no meio da rotina se faz estritamente necessária porque a interrupção por pin change reage a ambas as bordas do sinal. Caso essa checagem não existisse, o Empate registraria a mesma aposta duas vezes seguidas.

---

## 6. Integração com o main.S

```assembly
; durante a inicializacao:
rcall buttons_init      ; configura botoes e interrupcoes
sei                     ; habilita interrupcoes globais (depois dos inits)

; no laco principal, ao detectar jogada:
lds  r24, flags
sbrs r24, FLG_NEW_BET   ; bit levantado por alguma ISR?
rjmp (sem jogada)
; ... le bet_type, age conforme a aposta, e limpa FLG_NEW_BET ...



## Parte III: Documentação de Software — `interruptions.S`

---

## 1. Visão Geral

Este arquivo é responsável por implementar o controle de dois displays de 7 segmentos.

O sistema utiliza o Timer2 para gerar interrupções, a cada interrupção, o código alterna qual display está ligado, de forma que o usuário consiga visualizar adequadamente.

---

## 2. Mapeamento

A distribuição dos segmentos do display e dos pinos de controle de anodo ou catodo comum está divido entre PORTB e PORTD.

O `PORTD` é encarregado de controlar a parte alta dos segmentos da tela. Já o `PORTB` atua em duas frentes distintas: os pinos de PB0 a PB2 controlam a parte baixa dos segmentos (segmentos e, f e g), enquanto os pinos PB4 e PB3 funcionam exclusivamente como linhas de seleção e alimentação. O pino PB4 aciona o Display Esquerdo, representando o Jogador, e o pino PB3 aciona o Display Direito, que representa a Banca.

---

## 3. Variáveis e Dados na Memória

O módulo gerencia seu estado e a exibição visual combinando variáveis armazenadas na memória RAM (`.bss`) com tabelas gravadas na memória de programa (`.progmem`).

Na memória RAM, o sistema utiliza a variável `scan_side` de 1 byte para atuar como uma chave de controle de estado. Ela indica qual display que deve ser aceso na próxima varredura, onde o valor `0` representa a vez do display do Jogador e o valor `1` a vez do display da Banca. Além disso, o código depende de duas variáveis externas: `disp_left` e `disp_right`. Elas armazenam os valores numéricos, que vão de 0 a 11, que serão exibidos para o Jogador e para a Banca, respectivamente.

Na memória de programa, os dados visuais são guardados através de tabelas de decodificação, nas tabelas `font_pd` e `font_pb`.

---

## 4. Rotinas e Funções

### 4.1. display_init

Esta rotina pública configura as portas de I/O e faz a inicialização do Timer2. O processo começa configurando os pinos PD4 a PD7 e PB0 a PB4 como saídas de dados. Logo após a configuração de I/O, a rotina estabelece o estado inicial do sistema desligando ambos os displays, o que é feito zerando imediatamente os bits PB3 e PB4, e iniciando a variável de controle `scan_side` com o valor 0.


### 4.2. __vector_9 (Interrupção TIMER2_OVF)

Esta é a Rotina de Serviço de Interrupção encarregada de tratar o Overflow do Timer2. Assim que é acionada pelo hardware, ela salva o contexto atual do programa empilhando no *stack* os registradores que serão utilizados e o registrador de status (SREG). Depois, ela desativa os dois displays limpando temporariamente os pinos PB3 e PB4, para evitar problemas na transição dos dados

Após garantir a limpeza visual, a rotina lê a variável `scan_side` para decidir qual tela acender. Se o valor for 0 (rotina `mux_jogador`), ela carrega o valor da variável `disp_left`, chama a sub-rotina de decodificação, liga o pino de controle PB4, altera `scan_side` para 1 e pula para a finalização. Caso o valor não seja 0 (rotina `mux_banca`), o processo é espelhado: ela carrega `disp_right`, invoca a decodificação dos segmentos, aciona o pino PB3 e redefine `scan_side` para 0. Com a nova tela selecionada e acesa, a rotina restaura os registradores originais e o SREG, e retorna a execução ao programa principal através da instrução `reti`.

### 4.3. mux_segmentos

Esta sub-rotina é responsável por aplicar o padrão de bits correspondente ao número a ser exibido diretamente nos pinos do microcontrolador. O fluxo inicia com o recebimento do número a ser decodificado que fica registrado em `r25`. Utilizando esse valor, a rotina calcula primeiro o endereço do byte correto na tabela `font_pd` (através dos registradores X/Z e do comando `lpm`).

Na segunda parte, a rotina repete a operação, mas calculando em `font_pb`, lendo o padrão correspondente na memória flash e atualizando os bits inferiores de `PORTB` (0 a 2), usando outra máscara lógica para preservar perfeitamente o estado dos bits superiores dessa porta. Finalizada a escrita, a sub-rotina retorna o controle para a rotina de interrupção.

```
