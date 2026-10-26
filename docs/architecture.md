# Architecture

Two-player Pac-Man game controlled by capacitive touch pads (wearable tattoo electrodes).

```mermaid
flowchart LR
    subgraph P1["Player 1 module (Pac-Man)"]
        direction TB
        T1["Touch pads 0-11<br/>(copper / tattoo electrodes)"]
        S1["MPR121<br/>capacitive sensor"]
        M1["Arduino<br/>arduino.ino"]
        T1 -->|electrode lines| S1
        S1 -->|"I2C (0x5A)"| M1
    end

    subgraph P2["Player 2 module (Ghost)"]
        direction TB
        T2["Touch pads 0-11<br/>(copper / tattoo electrodes)"]
        S2["MPR121<br/>capacitive sensor"]
        M2["Arduino<br/>arduino.ino"]
        T2 -->|electrode lines| S2
        S2 -->|"I2C (0x5A)"| M2
    end

    subgraph PC["Host computer - Processing sketch"]
        direction TB
        SER["serial.pde<br/>serialEvent()"]
        GAME["processing.pde<br/>setup / draw / resetGame / chackPoints"]
        PAC["Pacman.pde"]
        GH["Ghost.pde"]
        DOT["Dot.pde"]
        SER -->|"pacman.move(dx, dy)"| PAC
        SER -->|"ghost.move(dx, dy)"| GH
        SER -->|"pads 8/9: resetGame()"| GAME
        GAME --- PAC
        GAME --- GH
        GAME --- DOT
    end

    M1 -->|"USB serial 115200 baud<br/>pad index per line"| SER
    M2 -->|"USB serial 115200 baud<br/>pad index per line"| SER
    GAME --> DISP["Display<br/>field, dots, score"]
```

## Firmware (`firmware/arduino/arduino.ino`)

1. On startup, restart MPR121 sensing and average 20 readings per pad as a software baseline.
2. Every 10 ms, read the chip touch flags and filtered data for all 12 electrodes.
3. A pad counts as touched if the chip reports it, or its reading drops more than 5 below baseline.
4. On a new touch (rising edge), print the pad index as one line over serial.

## Host (`processing/`)

| File | Role |
|---|---|
| `serial.pde` | Opens one serial port per player; validates numeric lines and maps pad to action |
| `processing.pde` | Game state, draw loop, dot spawning, scoring, reset |
| `Pacman.pde` | Player 1 character; bounded movement and facing angle |
| `Ghost.pde` | Player 2 character; bounded movement |
| `Dot.pde` | Dot position |

## Pad mapping

| Pad | Action |
|---|---|
| 0 | Up (dy = -10) |
| 1 | Down (dy = +10) |
| 2 | Left (dx = -10) |
| 3 | Right (dx = +10) |
| 8, 9 | Reset game |

The serial port a line arrives on decides whether it moves Pac-Man or the ghost.
