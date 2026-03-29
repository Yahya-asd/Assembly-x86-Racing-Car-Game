# Super NASM Racing 🏎️

A 16-bit real-mode DOS arcade racing game written entirely in **x86 Assembly (NASM)**. 

This project was developed to demonstrate low-level hardware interaction, including custom Interrupt Service Routines (ISRs) for keyboard and timer management, pseudo-random number generation, and direct manipulation of the VGA video memory buffer (`0xb800`).

## 🚀 Features

* **Custom Hardware Interrupts:** Hooks into the Interrupt Vector Table (IVT) to replace default keyboard (`INT 9`) and timer (`INT 8`) handlers for precise, non-blocking input and game-tick tracking.
* **Direct Video Memory Access:** Bypasses standard BIOS interrupts for rendering by writing directly to the VGA text mode memory buffer for flicker-free screen updates.
* **Dynamic Object Management:** Spawns and tracks multiple active objects (Obstacles, Coins, Fuel) with distinct collision detection boundaries.
* **Progressive Difficulty & Resource Management:** The game speed scales dynamically based on elapsed time, while the player must actively manage a depleting fuel gauge.
* **Real-time HUD:** Displays current score, fuel level, and active game time.

## 🛠️ Technical Stack
* **Language:** x86 Assembly (16-bit)
* **Assembler:** NASM
* **Environment:** DOSBox (or any native MS-DOS environment)

## 🎮 How to Play

**Objective:** Survive as long as possible by avoiding blue cars, collecting coins ($) to increase your score, and grabbing fuel (F) to keep your engine running. 

### Controls
* **Left/Right Arrows:** Switch between the 3 lanes
* **Up/Down Arrows:** Adjust vertical position
* **ESC:** Pause / Exit Game
* **Space:** Restart (from Game Over screen)

## 💻 Installation & Execution

To run this game on a modern operating system, you will need **NASM** and an emulator like **DOSBox**.

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YourUsername/super-nasm-racing.git](https://github.com/Yahya-asd/super-nasm-racing.git)
   cd super-nasm-racing
