# STM32F767 + VS Code + CMake — Learning Project Guide

> Living document. Captures decisions, architecture, the full roadmap, and a
> "where we are" marker so the project (and the guided walkthrough) can be
> resumed at any time. Update the **Status / Resume here** section as you go.

---

## 1. Goal & learning objectives

Build a small but *properly architected* STM32F767 firmware project, developed and
debugged entirely in VS Code, to gain senior-level experience with:

1. **VS Code debugging** — flexibility to develop/debug with any tool.
2. **Hardware abstraction layer** — firmware portable to other vendors (Nordic nRF52840).
3. **CMakeLists-based compiling.**
4. **GDB-based debugging.**
5. **Writing code to MISRA C standards.**

**Demo features:** UART over USB (ST-LINK VCP) + a hardware timer, both built on a
vendor-neutral HAL interface.

---

## 2. Hardware & environment (decided)

| Item | Choice |
|---|---|
| MCU / Board | STM32F767 on **Nucleo-F767ZI** |
| VCP UART | **USART3**, PD8 (TX) / PD9 (RX), 115200 8N1 |
| LEDs | LD1=PB0, LD2=PB7, LD3=PB14 |
| User button | PC13 |
| Clock | 8 MHz HSE (from ST-LINK MCO) → 216 MHz SYSCLK |
| Timer (demo) | **TIM6** basic timer, 1 Hz IRQ (PSC=10799, ARR=9999, APB1 timer clk 108 MHz) |
| Debug probe | **Onboard ST-LINK** via `ST-LINK_gdbserver` |
| Initial codegen | **STM32CubeMX** (standalone), Toolchain/IDE output = **CMake** |
| Editor | VS Code |
| Build | CMake 4.3.2 + Ninja 1.13.2 |
| Toolchain | **STM32CubeCLT** (chosen) — GCC 13.3, GDB, OpenOCD, ST-LINK_gdbserver, STM32_Programmer_CLI |

Pre-existing on machine: STM32CubeIDE 1.19.0 (bundles the same tools at fragile
plugin paths — we chose CubeCLT instead for stable, update-proof paths).

---

## 3. Target architecture (the abstraction layer)

```
app/        Application logic — ZERO vendor headers. Calls hal_uart_*, hal_timer_*   <- portable
hal/        Abstract interface — pure .h contracts (hal_uart.h, hal_timer.h, hal_gpio.h)  <- the "seam"
port/
  stm32f7/  Implements hal_* using STM32 HAL/LL                                       <- swappable
  nrf52840/ (future) Implements hal_* using nRF SDK
vendor/     CubeMX-generated STM32 HAL, CMSIS, startup .s, linker script             <- vendor SDK
```

**THE ONE RULE:** `app/` and `hal/` must never `#include` a vendor (STM32 / Nordic)
header. Porting = write a new `port/<vendor>/` and recompile `app/` untouched.
Enforced by directory structure + CMake `target_include_directories` visibility.

| Learning goal | Where it lives |
|---|---|
| CMake-based compiling | `toolchain-arm-none-eabi.cmake` + per-layer `CMakeLists.txt` |
| HW abstraction | `hal/` (contract) + `port/` (impl) directory firewall |
| VS Code + GDB debug | `.vscode/launch.json` driving `arm-none-eabi-gdb` <-> `ST-LINK_gdbserver` |
| MISRA C | `cppcheck --addon=misra` as a CMake target + coding rules |

---

## 4. Roadmap (8 stages)

- [x] **Stage 0** — Toolchain sanity & CubeCLT decision  *(CubeCLT 1.21.0 installed, GCC 14.3)*
- [x] **Stage 1** — Generate base with CubeMX (USART3 + TIM6, output = CMake)  *(done; note: eth.c + usb_otg.c also enabled by "init all default")*
- [x] **Stage 2** — Dissect the generated CMake & toolchain file (line by line)
- [x] **Stage 3** — First command-line build (`cmake --preset Debug`) -> `.elf` (18.4 KB flash, 3.6 KB RAM)
- [ ] **Stage 4** — VS Code wiring: `tasks.json`, `launch.json`, IntelliSense -> first breakpoint  *(IN PROGRESS)*
- [ ] **Stage 5** — Design the HAL interface (`hal_uart.h` / `hal_timer.h`)
- [ ] **Stage 6** — Implement `port/stm32f7/` + vendor-neutral `app/main`
- [ ] **Stage 7** — MISRA C: cppcheck addon target + the rules that bite
- [ ] **Stage 8** — GDB deep-dive (TUI, SWV, scripting) + nrf52840 port sketch

### Track B — Hand-written GNU Make (inserted by user request; runs parallel to CMake)

Goal: master GNU Make for cross-compilation by hand-building the SAME project.
User has read *Managing Projects with GNU Make* (3rd ed.) through Ch 5.
Shell decision: run `make` from **Git Bash / msys2 UCRT64** (Unix `sh`), NOT cmd/PowerShell.
Output dir: `build/make/` (kept separate from CMake's `build/Debug/`).

- [ ] **B1** — Working Makefile v1, hand-typed line-by-line by the user (NOT generated),
      discovering each embedded-build requirement by hitting real errors. Detailed
      10-step build-along log in section 9. Ends with toolchain vars, MCU flags,
      `$(wildcard)` discovery, pattern rules + automatic vars, phony targets,
      objcopy .hex/.bin, size, and `-MMD -MP` auto-deps (vs the book's Ch5 `sed` hack).
- [ ] **B2** — Cross-compile debugging from the CLI: `make flash`, `make gdbserver`,
      `make debug` (arm-none-eabi-gdb ↔ ST-LINK_gdbserver / OpenOCD).
- [ ] **B3** — Refactor toward scale: config split, Debug/Release, `make V=1` verbosity,
      compare line-for-line against what CMake's toolchain file generates.
- [ ] **B4** — (optional) non-recursive vs recursive make, and a portable multi-target
      Makefile that could also target nRF52840 (ties into the HAL work, Stage 5–6).

---

## 5. Status / Resume here

**Current stage:** Track B (GNU Make) — stage B1, hand-typing the Makefile.
Currently at build-along Steps 1–2 (see section 9). Stage 4 (VS Code debug) is
wired up but the F5 first-breakpoint run has NOT been confirmed yet — come back
to it. HAL / MISRA / GDB-deep-dive stages (5–8) still pending.

**IMPORTANT working style:** user is a senior embedded engineer LEARNING by doing.
Do NOT generate files for the Makefile track — guide line-by-line, explain like
they're new to Make, let them type and run each step and report results/errors.

**Done:** CubeCLT 1.21.0 + CubeMX installed; project generated; first CMake+Ninja
build green (`cmake --preset Debug && cmake --build --preset Debug`); `.vscode/`
configs written (extensions, settings, tasks, launch — ST-LINK + OpenOCD).
Shell decision for Make: run from Git Bash / msys2 UCRT64 (Unix sh), NOT PowerShell.

**Key resolved paths (for .vscode configs):**
- GDB: `C:/ST/STM32CubeCLT_1.21.0/GNU-tools-for-STM32/bin/arm-none-eabi-gdb`
- ST-LINK gdbserver: `C:/ST/STM32CubeCLT_1.21.0/STLink-gdb-server/bin/ST-LINK_gdbserver.exe`
- CubeProgrammer bin: `C:/ST/STM32CubeCLT_1.21.0/STM32CubeProgrammer/bin`
- SVD (register view): `C:/ST/STM32CubeCLT_1.21.0/STMicroelectronics_CMSIS_SVD/STM32F767.svd`
- ELF: `build/Debug/EMS_vsdebug_cmake.elf`

**Build commands:**
```
cmake --preset Debug          # configure
cmake --build --preset Debug  # compile -> build/Debug/EMS_vsdebug_cmake.elf
```

**Pending actions (user):** install VS Code extensions (CMake Tools, Cortex-Debug,
C/C++ or clangd), plug in the Nucleo, press F5. See section 8.

---

## 6. Stage 1 — CubeMX recipe (reference)

1. **New Project → Board Selector → NUCLEO-F767ZI → Start Project.**
   *"Initialize all peripherals with their default Mode?"* → **Yes**.
   (Brings up VCP USART3, LEDs, button, 216 MHz clock automatically.)
2. **Timers → TIM6** → Activated. Parameter Settings: **Prescaler = 10799**,
   **Counter Period = 9999** (→ 1 Hz). NVIC Settings → enable **TIM6 global interrupt**.
3. **Connectivity → USART3** → confirm Asynchronous, 115200 8N1, PD8/PD9.
4. **Project Manager → Project:** Name `EMS_vsdebug_cmake`,
   Location `C:\Users\LocalShivek\Documents\EMSworkspace`, **Toolchain/IDE = CMake**.
5. **Project Manager → Code Generator:** check "Copy only necessary library files"
   and "Generate peripheral init as a pair of .c/.h files per peripheral".
6. **GENERATE CODE.**

---

## 7. Notes / decisions log

- 2026-06-19: Hardware, probe, and CubeCLT toolchain chosen. Guided "build-along" mode.
- 2026-06-22: CMake build green; `.vscode/` wired. User inserted a GNU Make learning
  track (has read *Managing Projects with GNU Make* Ch 1–5) — hand-typing a Makefile
  for the same project. Working style = teach line-by-line, don't generate files.
- (add dated notes here as the project evolves)

---

## 8. Stage 4 — VS Code debug (reference)

Files in `.vscode/`: `extensions.json`, `settings.json`, `tasks.json`, `launch.json`.
Debug chain:  VS Code (Cortex-Debug) → arm-none-eabi-gdb → :3333 gdbserver → SWD → chip.
Two launch configs share one GDB: **Debug (ST-LINK)** and **Debug (OpenOCD)** — same
chip, swappable back-end (the "any tool" lesson).

To finish Stage 4:
1. `code .` from project root; install the 3 recommended extensions.
2. Plug Nucleo into ST-LINK USB port (CN1).
3. Breakpoint in `Core/Src/main.c` `while(1)`; press **F5** → "Debug (ST-LINK)".
4. It builds (preLaunchTask) → flashes → halts at `main`. Explore Cortex Peripherals
   (SVD) panel, Step Over (F10), watch variables.
Status: configs written, first F5 run NOT yet confirmed.

---

## 9. Track B — Makefile build-along log (stage B1)

Hand-typed `Makefile` at project root. Output → `build/make/`. Run from Git Bash.
10-step incremental build; each step teaches one embedded-compile concept by
hitting a real error, then fixing it. Update status as you go.

- [x] **Step 1** — `Makefile` created; `hello:` rule works. Learned TAB rule, default
      goal, `@`, `$(VAR)`, `$(CURDIR)`.
- [x] **Step 2** — Learned prereqs are resolved as files (hit "No rule to make target
      main.c"); recipe text ≠ prereq. Also fixed a broken `TEMP=C:\WINDOWS` via
      `export TMP/TEMP := $(CURDIR)/build/tmp` at top of Makefile.
- [x] **Step 2b** — `VPATH = Core/Src` + automatic vars `$< $@` (VPATH resolves the
      prereq; `$<` injects the found path into the recipe — VPATH doesn't touch recipes).
- [x] **Step 3** — Added 5 `-I` include paths + `-DSTM32F767xx -DUSE_HAL_DRIVER`
      (hit and understood the `#error "Please select... target STM32F7xx device"`).
- [x] **Step 4** — Added MCU flags `-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16
      -mfloat-abi=hard` (hit `cpsid i in ARM mode` → Cortex-M is Thumb-only).
      Also fixed path typos: `Inc/Legacy`, and `Device` casing (Windows hid the case bug).
      `main.o` now compiles cleanly.
- [ ] **Step 5** — Introduce variables (`CC`, `MCU`, `CFLAGS`, `C_DEFS`, `C_INCLUDES`)
      to stop repeating flags. `:=` vs `=` vs `?=` vs `+=`.  *(IN PROGRESS)*
- [ ] **Step 6** — `$(wildcard Core/Src/*.c ...)` to auto-discover sources;
      `patsubst`/`addprefix` to map sources → objects under `$(BUILD)`.
- [ ] **Step 7** — Pattern rule `$(BUILD)/%.o: %.c` with automatic vars `$< $@`;
      `mkdir -p $(dir $@)`; add `Makefile` as prereq so flag edits force rebuild.
- [ ] **Step 8** — Link rule (`$^`, linker script `-T`, `--specs=nano.specs`,
      `--gc-sections`); objcopy `.hex`/`.bin`; print `size`. First full `.elf`.
- [ ] **Step 9** — Phony targets `.PHONY: all clean flash`; `flash` via
      `STM32_Programmer_CLI -c port=SWD -w <elf> -rst`.
- [ ] **Step 10** — Auto-dependency generation: `-MMD -MP` + `-include $(DEPS)`
      (modern replacement for the book's Ch5 `gcc -M | sed` hack).

**Resume marker:** Steps 1–4 done, `main.o` compiles. Now on Step 5 — factoring the
long recipe into variables (`CC`, `MCU`, `C_DEFS`, `C_INCLUDES`, `OPT`, `CFLAGS`).
Next after 5: Step 6 `$(wildcard)` to auto-discover all sources.
