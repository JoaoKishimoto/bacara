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

Inicialmente planejada para operar via protocolo I2C (módulo PCF8574), a conexão do display LCD 16x2 foi consolidada no diagrama final de forma direta, no modo de 4 bits. Os pinos de controle (RS e Enable) e o barramento de dados (D4–D7) foram mapeados para os pinos A0 a A5 do Arduino. Como esses pinos analógicos também operam perfeitamente como GPIOs (saídas digitais), essa configuração remove a necessidade do módulo I2C adicional, remove o chip PCF8574 e toda a fiação intermediária entre ele e o LCD e remove a dependência da ligação serial discreta, que se mostrou instável. O pino R/W do LCD foi permanentemente aterrado, já que o sistema fará apenas operações de escrita na tela.

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
; durante a inicializacao:
rcall buttons_init      ; configura botoes e interrupcoes
sei                     ; habilita interrupcoes globais (depois dos inits)

; no laco principal, ao detectar jogada:
lds  r24, flags
sbrs r24, FLG_NEW_BET   ; bit levantado por alguma ISR?
rjmp (sem jogada)
; ... le bet_type, age conforme a aposta, e limpa FLG_NEW_BET ...



## Parte III: Documentação de Software — `display.S`

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

---

## Parte IV: Documentação de Software — `game.S`

## 1. Visão Geral

Este arquivo é responsável por toda a lógica do jogo. É ele que cuida do sorteio das cartas, da conversão de cada carta no seu valor, do somatório dos pontos de cada mão e das regras que decidem o andamento da rodada, incluindo a compra da terceira carta e a definição do vencedor.

As funções recebem valores nos registradores, fazem o seu cálculo e devolvem o resultado, mantendo a lógica do jogo separada da parte de interrupções e de exibição, permitindo que cada regra seja testada de forma isolada.

---

## 2. Rotinas

### 2.1. sorteia_carta — Distribuição e sorteio das cartas

A função `sorteia_carta` é responsável pela distribuição e pelo sorteio das cartas do jogador e da banca. O sorteio parte da variável `rng_state`, que tem os seus bits deslocados para a direita; em seguida, aplicamos uma subtração sucessiva de 13 (equivalente a dividir por 13) até obter um valor entre 0 e 12, ao qual somamos 1 unidade. O resultado é o rank da carta, de 1 a 13.

### 2.2. valor_carta — Verificação do valor da carta

Depois, a função `valor_carta` converte o rank no valor que a carta tem no jogo: se estiver entre 1 e 9, devolve o próprio número; se for 10, 11, 12 ou 13, devolve 0.

### 2.3. calcula_pontuacao — Somatório dos pontos da mão

Para saber a pontuação de cada lado, criamos a função `calcula_pontuacao`, que recebe até três cartas nos registradores `r24`, `r22` e `r20` (este último para representar a terceira carta, quando houver). A rotina converte cada carta no seu valor e soma tudo; como a pontuação no jogo não pode passar de 9, aplicamos o módulo 10 sempre que a soma chega a 10 ou mais.

### 2.4. checa_natural — Busca por 8 ou 9 iniciais

A função `checa_natural` procura um natural no bacará: se o jogador ou a banca somar 8 ou 9 nas cartas iniciais, ela bloqueia a compra de novas cartas e o jogo segue direto para o resultado final.

### 2.5. decide_simples — Regra básica da terceira carta

Diante disso, dividimos a regra da terceira carta em duas funções: `decide_simples` e `decide_banca_p3`. A `decide_simples` verifica o placar: se estiver entre 0 e 5, o lado é obrigado a comprar; caso contrário, é obrigado a parar.

### 2.6. decide_banca_p3 — Tabela rigorosa de compra da banca

Na `decide_banca_p3`, quando o jogador comprou uma carta, a banca não usa a regra simples: ela utiliza uma tabela rigorosa que cruza o seu placar atual com o valor exato da carta que o jogador acabou de comprar, decidindo entre comprar ou ficar.

### 2.7. define_vencedor — Comparação final dos placares

Por fim, a `define_vencedor` faz a comparação dos pontos dos dois lados utilizando os registradores e devolve o desfecho da rodada: se o jogador perdeu, ganhou ou se foi empate.

## Parte V: Documentação do Display LCD 16x2 (HD44780)

### 1. Visão geral

O display de LCD é o principal canal de comunicação com o usuário, responsável por exibir as mensagens de estado (apostas e resultados), o placar e as cartas sorteadas. 
Utilizamos um display 16x2 (controlador HD44780). 
A arquitetura foi estabelecida em uma ligação paralela direta aos pinos da PORTC do ATmega328P, operando no modo de 4 bits de dados e configurada estritamente como write-only (apenas escrita).

## 2. Decisão de projeto

Como mencionado anteriormente na Parte I - 3.3 Interface do LCD (Alteração de Projeto), o planejamento original do projeto contava com um módulo adaptador PCF8574 para comunicar o LCD via I2C. Contudo, optou-se pela ligação paralela direta devido a problemas de confiabilidade física na ligação do PCF8574 na protoboard, que causavam conexões intermitentes e a exibição de caracteres corrompidos na tela. Para compensar o gasto de portas da ligação paralela, a comunicação foi implementada no modo de 4 bits. Como o sistema precisa apenas atualizar a tela e não ler seu conteúdo atual, o pino Read/Write (R/W) do LCD foi fixado no GND.

## 3. Pinagem

Os 6 pinos de controle e dados foram alocados nos bits 0 a 5 da Porta C. A conexão física segue a tabela abaixo:

| Pino do ATmega328P    | Pino do LCD | Função                                   |
|-----------------------|-------------|------------------------------------------|
| PC0 (A0)              | RS          | Register Select (0 = Comando, 1 = Dado)  |
| PC1 (A1)              | EN          | Enable                                   |
| PC2 (A2)              | D4          | Linha de Dados 4                         |
| PC3 (A3)              | D5          | Linha de Dados 5                         |
| PC4 (A4)              | D6          | Linha de Dados 6                         |
| PC5 (A5)              | D7          | Linha de Dados 7                         |
| GND                   | R/W         | Read/Write (Sempre 0 = Write-only)       |
| GND                   | VSS         | Aterramento (Power)                      |
| 5V                    | VDD         | Alimentação (Power)                      |
| GND                   | V0          | Contraste dos caracteres (fixo no máximo, V0 em GND)|
| 5V / GND              | A / K       | Positivo e Negativo do Backlight         |

## 4. Modo de operação

Como o barramento possui apenas 4 linhas de dados (D4 a D7), o caminho de um byte até a tela acontece através do seu particionamento. Cada byte é enviado quebrado em dois blocos de 4 bits (nibbles), sendo o "nibble alto" enviado primeiro, seguido imediatamente pelo "nibble baixo". 
Após apresentar o nibble nas portas de dados, é gerado um pulso no pino Enable (EN), e o LCD captura a informação na borda de descida desse sinal. 
Como não estamos lendo a busy flag do LCD (já que o R/W está no GND), a sincronização para não sobrecarregar o display é garantida por meio de funções de atraso (_delay_us e _delay_ms) que estipulam um tempo de pior caso entre um envio e outro, garantindo que o hardware tenha tempo hábil para processar tudo.

## 5. Inicialização

Para preparar o display em modo de 4 bits, o lcd_init() executa, na partida, uma sequência rígida descrita pelo datasheet da fabricante (a mesma sequência está no helper lcd_soft_reset(), reutilizado pelo lcd_clear()). Essa sequência: envia o comando de reset 0x03 três vezes consecutivas, com intervalos específicos (5ms e 150µs), e por fim um 0x02. Isso é feito puramente por conta de sincronização: ele garante que o controlador interno recomece do zero e assuma um estado perfeitamente conhecido antes de configurarmos o display definitivamente para 2 linhas de texto (modo 4 bits, fonte 5x8).

## 6. Header

O contrato (lcd_interface.h) expõe apenas o necessário para a lógica do jogo invocar a tela:

| Assinatura da Função | Descrição |
|---|---|
| `void lcd_init(void)` | Configura a PORTC como saída e executa a sequência de reset e inicialização do display |
| `void lcd_clear(void)` | Limpa a tela inteira e reseta o cursor para o topo |
| `void lcd_message(uint8_t msg_id)` | Recebe um ID (código numérico contido no `defs.h`) e imprime mensagens de sistema da rodada (ex: "Faca sua aposta", "Jogador vence") |
| `void lcd_scores(uint8_t player, uint8_t banker)` | Recebe os dois placares numéricos e renderiza na tela a pontuação da Banca e do Jogador |
| `void lcd_cards(uint8_t who)` | Imprime as "faces" literais (ex: A, K, 2, Q) das cartas de quem foi requisitado (0 para Jogador, 1 para Banca) buscando na memória interna |

## 7. Interface com o Assembly

A integração de dados entre a máquina de estados em Assembly e o arquivo C é baseada na convenção de chamadas (ABI avr-gcc) e em ponteiros fixos na memória. Variáveis cruciais para o rastreamento do jogo, como player_cards, banker_cards, player_count e banker_count, são marcadas como extern volatile no código em C. Quando o Assembly altera o estado da mão e precisa mostrá-la, ele chama a rotina gráfica em C; essa, por sua vez, usa as declarações externas como ponte para ir até a SRAM (Seção.bss) ler e formatar aqueles valores em caracteres. As mensagens de estado são acionadas quando o Assembly invoca a rotina passando o ID (ex: macros MSG_* através do registrador r24)

---
## Parte VI: Documentação de Software — `defs.h`
## 1. O que este arquivo faz

Cabeçalho compartilhado por todos os módulos do projeto (C e Assembly). Centraliza as constantes numéricas que os demais arquivos precisam conhecer, de forma que alterar um valor aqui se propaga para todo o sistema.

---
## 2. Grupos de definições

**Máquina de estados (`game_state`):** cinco estados que representam o ciclo de uma rodada — `ST_IDLE` (aguardando aposta), `ST_BET` (aposta confirmada), `ST_DEAL` (distribuição inicial), `ST_THIRD` (terceira carta) e `ST_RESULT` (exibição do resultado).

**Apostas (`bet_type`):** identificadores das três opções de aposta — `BET_PLAYER`, `BET_BANKER` e `BET_TIE` — mais `BET_NONE` para o estado sem aposta.

**Resultado (`result`):** códigos de desfecho da rodada — `RES_PLAYER`, `RES_BANKER` e `RES_TIE`.

**Flags (`flags`):** bit `FLG_NEW_BET` (bit 0), levantado pelas ISRs ao registrar uma aposta e consumido pelo laço principal em `main.S`.

**Mensagens do LCD:** dez constantes (`MSG_PLACE_BET` a `MSG_YOU_LOSE`) usadas como argumento de `lcd_message` para selecionar o texto a exibir.

**LCD e displays:** pinos de controle e dados do LCD em PORTC (A0–A5), agrupados na máscara `LCD_DDR_MASK`. Para os displays de 7 segmentos, `DISP_BLANK` (10) apaga o display e `DISP_DASH` (11) exibe um traço no estado ocioso.

---
## Parte VII: Documentação de Software — `main.S`
## 1. O que este arquivo faz
Ponto de entrada do firmware. Declara todas as variáveis globais do sistema na SRAM, inicializa o hardware e executa continuamente a máquina de estados que governa uma partida de Bacará.

---
## 2. Variáveis globais na SRAM (`.bss`)

Declaradas como `.global` e acessadas pelos demais módulos via `lds`/`sts`.

| Variável       | Tamanho | Conteúdo                                                         |
| :------------- | :-----: | :--------------------------------------------------------------- |
| `game_state`   | 1 byte  | Estado atual da máquina (`ST_IDLE` … `ST_RESULT`)               |
| `bet_type`     | 1 byte  | Aposta do usuário (`BET_NONE` … `BET_TIE`)                      |
| `player_score` | 1 byte  | Pontuação atual do Jogador (0–9)                                 |
| `banker_score` | 1 byte  | Pontuação atual da Banca (0–9)                                   |
| `player_cards` | 3 bytes | Ranks das cartas do Jogador; índice 2 = 0 se terceira não usada  |
| `banker_cards` | 3 bytes | Ranks das cartas da Banca; índice 2 = 0 se terceira não usada   |
| `player_count` | 1 byte  | Número de cartas do Jogador (2 ou 3)                             |
| `banker_count` | 1 byte  | Número de cartas da Banca (2 ou 3)                               |
| `rng_state`    | 2 bytes | Estado do LFSR para geração pseudoaleatória de cartas            |
| `result`       | 1 byte  | Resultado da rodada (`RES_BANKER`, `RES_PLAYER`, `RES_TIE`)     |
| `disp_left`    | 1 byte  | Índice de fonte do display esquerdo (Jogador)                    |
| `disp_right`   | 1 byte  | Índice de fonte do display direito (Banca)                       |
| `flags`        | 1 byte  | Bits de comunicação ISR→main (bit 0 = `FLG_NEW_BET`)            |

---
## 3. Rotinas
### 3.1. main — Inicialização

Configura a pilha em `RAMEND`, define os valores iniciais de todas as variáveis e chama `display_init`, `buttons_init`, `sei` e `lcd_init` nessa ordem. O `sei` é emitido antes do `lcd_init` para que o display de 7 segmentos já esteja operacional, independente do tempo de inicialização do LCD. Por fim, exibe `MSG_PLACE_BET` e cai no laço principal.

---
### 3.2. main_loop — Laço principal
Lê `game_state` e redireciona para o tratador correspondente via cadeia de comparações. Os cinco tratadores são:

- **`state_idle`:** aguarda o flag `FLG_NEW_BET` ser levantado por uma ISR; quando detectado, avança para `ST_BET`.
- **`state_bet`:** consome `FLG_NEW_BET`, semeia o LFSR com `TCNT2` na primeira aposta da sessão e exibe a mensagem de confirmação antes de avançar para `ST_DEAL`.
- **`state_deal`:** sorteia duas cartas para cada lado, calcula as pontuações iniciais, atualiza displays e LCD; se houver natural (8 ou 9), chama `finalize_round` diretamente, senão avança para `ST_THIRD`.
- **`state_third`:** aplica as regras oficiais da terceira carta, usando `decide_simples` para o Jogador e `decide_banca_p3` para a Banca quando o Jogador comprou; atualiza displays e LCD e finaliza com `finalize_round`.
- **`state_result`:** aguarda, descarta novas apostas chegadas durante a exibição, restaura as variáveis para o estado ocioso e exibe `MSG_PLACE_BET`.

---

### 3.3. finalize_round
Calcula o vencedor com `define_vencedor`, exibe as pontuações finais com `lcd_scores` e depois mostra quem ganhou a rodada. Em seguida, cruza `bet_type` com `result` para determinar o desfecho do apostador: se acertou, exibe `"8 8"` nos displays e `MSG_YOU_WIN`; se errou, exibe `"0 0"` e `MSG_YOU_LOSE`. Por fim, grava `ST_RESULT` em `game_state`.

---
### 3.4. pause_2s
Busy-wait de aproximadamente 2 segundos a 16 MHz, implementado com três laços aninhados nos registradores `r18`–`r20`. As interrupções continuam funcionando normalmente durante a pausa.

