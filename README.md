# Bacará — ATmega328P (Arduino Nano)

Implementação do jogo de cartas Bacará em Assembly AVR e C para o microcontrolador ATmega328P, rodando a 16 MHz. Projeto desenvolvido para a disciplina de Programação de Software Básico.

---

## Hardware necessário

| Componente                          | Quantidade |
| ----------------------------------- | ---------- |
| Arduino Nano (ATmega328P @ 16 MHz)  | 1          |
| Display 7 segmentos cátodo comum    | 2          |
| Transistor NPN (ex.: BC547)         | 2          |
| LCD 16×2 (HD44780)                  | 1          |
| Push-button                         | 3          |
| Resistores de pull-down (segmentos) | 7          |
| Resistor de pull-up (botão empate)  | 1          |

---

## Mapeamento de pinos

### Displays de 7 segmentos

| Segmento        | Pino Arduino | Porta AVR |
| --------------- | ------------ | --------- |
| a               | D4           | PD4       |
| b               | D5           | PD5       |
| c               | D6           | PD6       |
| d               | D7           | PD7       |
| e               | D8           | PB0       |
| f               | D9           | PB1       |
| g               | D10          | PB2       |
| Seleção Jogador | D12          | PB4       |
| Seleção Banca   | D11          | PB3       |

### LCD 16×2 (HD44780) — modo 4 bits, conexão direta

| Sinal LCD | Pino Arduino | Porta AVR |
| --------- | ------------ | --------- |
| RS        | A0           | PC0       |
| EN        | A1           | PC1       |
| D4        | A2           | PC2       |
| D5        | A3           | PC3       |
| D6        | A4           | PC4       |
| D7        | A5           | PC5       |

RW deve ser ligado ao GND (modo escrita permanente).

### Botões (pull-up interno, ativo em LOW)

| Função             | Pino Arduino | Porta AVR |
| ------------------ | ------------ | --------- |
| Apostar em Jogador | D2           | PD2       |
| Apostar em Banca   | D3           | PD3       |
| Apostar em Empate  | D13          | PB5       |

---

## Como jogar

1. Ao ligar, o LCD exibe "Faca sua aposta" e os displays mostram `- -`.
2. Pressione um dos três botões para fazer sua aposta (Jogador, Banca ou Empate).
3. O LCD confirma a aposta escolhida e distribui automaticamente as cartas.
4. As pontuações aparecem nos displays de 7 segmentos (esquerdo = Jogador, direito = Banca) e as cartas no LCD.
5. O jogo aplica as regras oficiais do Bacará para a terceira carta.
6. O resultado é exibido: quem ganhou a rodada e se o apostador ganhou ou perdeu.
   - Vitória: displays mostram `8 8`
   - Derrota: displays mostram `0 0`
7. Pressione qualquer botão para iniciar uma nova rodada.

### Regras do Bacará implementadas

- Mão inicial: 2 cartas para cada lado.
- Natural: se Jogador ou Banca atingir 8 ou 9 pontos, o jogo termina imediatamente.
- Terceira carta do Jogador: compra se pontuação ≤ 5, fica com 6 ou 7.
- Terceira carta da Banca (quando o Jogador comprou): tabela oficial com base na pontuação da Banca e no valor da terceira carta do Jogador.
- Pontuação: soma dos valores módulo 10 (10, J, Q, K valem 0; Ás vale 1).

---

## Construção e gravação

### Pré-requisitos

```bash
# Ubuntu/Debian
sudo apt install make gcc-avr avr-libc avrdude

# Arch Linux
sudo pacman -S make avr-gcc avr-libc avrdude
```

### Compilar

```bash
make
```

Gera `bacara.hex`.

### Gravar no Arduino Nano

```bash
avrdude -c arduino -p atmega328p -P /dev/ttyUSB0 -b 115200 -U flash:w:bacara.hex
```

Ajuste `/dev/ttyUSB0` para a porta serial do seu sistema.

### Limpar arquivos gerados

```bash
make clean
```

---

## Arquitetura do software

```
src/
├── defs.h              — constantes e contrato compartilhado entre todos os módulos
├── main.S              — ponto de entrada, alocação de variáveis SRAM e máquina de estados
├── game.S              — lógica do jogo: RNG (LFSR), pontuação, regras da 3ª carta
├── display.S           — multiplexação dos displays 7 segmentos via Timer2
├── interruptions.S     — ISRs dos botões (INT0, INT1, PCINT5)
├── lcd_interface.c     — driver HD44780 em modo 4 bits via pinos PC0–PC5 (PORTC)
└── lcd_interface.h     — protótipos públicos do driver LCD, incluído pelos módulos .S via ABI avr-gcc
```

### Máquina de estados (`game_state`)

```
ST_IDLE  →  ST_BET  →  ST_DEAL  →  ST_THIRD  →  ST_RESULT
   ↑                                                  |
   └──────────────────────────────────────────────────┘
```

| Estado      | Descrição                                           |
| ----------- | --------------------------------------------------- |
| `ST_IDLE`   | Aguarda pressionamento de botão de aposta           |
| `ST_BET`    | Confirma aposta, semeia RNG, exibe mensagem         |
| `ST_DEAL`   | Distribui 2 cartas para cada lado, verifica natural |
| `ST_THIRD`  | Avalia e distribui a 3ª carta pelas regras oficiais |
| `ST_RESULT` | Exibe resultado, aguarda botão para nova rodada     |

### Recursos de hardware utilizados

| Recurso           | Uso                                               |
| ----------------- | ------------------------------------------------- |
| Timer2 (overflow) | Multiplexação dos displays (~488 Hz por display)  |
| INT0 / INT1       | Botões Jogador e Banca (borda de descida)         |
| PCINT5            | Botão Empate (verifica nível LOW na ISR)          |
| PORTC (PC0–PC5)   | Interface direta com o LCD HD44780 em modo 4 bits |
| LFSR 8 bits       | Geração pseudo-aleatória de cartas (taps `0xB8`)  |

### Convenção de chamada (ABI avr-gcc)

Todos os módulos respeitam a ABI padrão do avr-gcc:

- 1º argumento: `r24` | 2º: `r22` | 3º: `r20`
- Retorno 8 bits: `r24`
- Registradores preservados pelo chamado (call-saved): `r2–r17`, `r28`, `r29`
- `r1` deve valer `0` ao retornar de qualquer função ou ISR
