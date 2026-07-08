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

- [x] **Step 1 — The mechanics:** a first rule, prove Make runs, learn the tab rule.
      → `hello:` rule works; learned target/prereq/recipe, TAB rule, default goal,
      `@` prefix, `$(VAR)`, `$(CURDIR)`.
- [x] **Step 2 — Compile one file the naive way:** watch it fail, learn why embedded
      needs special flags. → Learned prereqs resolve to real files (hit "No rule to make
      target main.c"); recipe text ≠ prereq. `VPATH = Core/Src` + automatic vars `$< $@`
      (VPATH resolves the prereq; `$<` injects the found path — VPATH doesn't touch
      recipes). Also fixed a broken `TEMP=C:\WINDOWS` via
      `export TMP/TEMP := $(CURDIR)/build/tmp`.
- [x] **Step 3 — Fix it with include paths and preprocessor defines.** → Added 5 `-I`
      paths + `-DSTM32F767xx -DUSE_HAL_DRIVER`; understood the
      `#error "Please select... target STM32F7xx device"`.
- [x] **Step 4 — Add the MCU architecture flags (the cross-compilation core).**
      → `-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard` (hit
      `cpsid i in ARM mode` → Cortex-M is Thumb-only). Fixed path typos `Inc/Legacy`
      and `Device` casing (Windows hid the case bug). `main.o` compiles cleanly.
- [x] **Step 5 — Introduce variables to stop repeating ourselves.** → `CC`, `MCU`,
      `C_DEFS`, `C_INCLUDES`, `OPT`, `WARN`, `CFLAGS`. Learned `:=` vs `=` vs `?=` vs
      `+=`, immediate vs deferred expansion, and `make -n`/`--dry-run` to preview.
- [x] **Step 6 — `$(wildcard)` to auto-discover all sources.** → `BUILD`, `C_SOURCES`,
      `ASM_SOURCES`, `OBJECTS` (via `$(SRC:.c=.o)` substitution ref + `$(addprefix)`).
      Inspected with a `show` phony target. ~34 objects mapped under `build/make/`.
- [x] **Step 7 — Pattern rule + automatic variables to compile them all.**
      `$(BUILD)/%.o: %.c Makefile` + `.s` rule; `mkdir -p $(dir $@)`; `$< $@`.
      Retired `VPATH` and the explicit `main.o` rule. `make objects` built all 34.
- [x] **Step 8 — Link + objcopy (.hex/.bin) + size.** Added `TARGET`, `CP`, `SZ`,
      `LDSCRIPT`, `LDFLAGS` (`-T`, `--specs=nano.specs`, `-Wl,--gc-sections`,
      `-Wl,-Map,--cref`, `-lm`), added `-ffunction-sections -fdata-sections` to CFLAGS,
      made `all` the default goal. Produces `.elf/.hex/.bin`; size ≈ CMake's 18 KB.
- [ ] **Step 9 — Phony targets (`clean`, `flash`).**  *(NEXT)*  `.PHONY:`; `flash` via
      `STM32_Programmer_CLI -c port=SWD -w <elf> -rst`.
- [ ] **Step 10 — Auto-dependency generation (modern take on the Ch 5 `sed` trick).**
      `-MMD -MP` + `-include $(DEPS)`.
- [ ] **Step 11 — How to debug a Makefile (build & link failures).** Preview commands
      (`make -n`), dump db (`make -p`), trace remakes (`make --trace`, `--debug=b`),
      print any variable (`print-%` target / `$(info)`/`$(warning)`/`$(error)`),
      force/what-if (`-B`, `-W`), keep-going (`-k`), verbosity switch. Decode the common
      errors: `missing separator` (tabs), `No rule to make target` (paths/VPATH),
      `undefined reference` (missing object / lib order), `multiple definition`.
      Inspect artifacts: `nm`, `objdump -d`, the `.map` file.

**Resume marker:** Steps 1–8 done. `make` produces `.elf/.hex/.bin`, size ≈ CMake's.
Now on **Step 9** (clean + flash phony targets). Then Step 10 (auto-deps `-MMD -MP`)
and Step 11 (debugging Makefiles). After B1: Track B stage B2 = CLI debugging
(`make flash` / `gdbserver` / `gdb`), then back to CMake HAL/MISRA/GDB stages 5–8.

---

## 10. Further reading — GNU Make (book: Mecklenburg, *Managing Projects w/ GNU Make*, 3rd ed.)

User has read Ch 1–5 (Simple Makefile, Rules, Variables/Macros, Functions, Commands).
To handle complex projects (FreeRTOS, multi-component middleware), read next:

- **Ch 8 "C/C++"** — HIGH. Automatic dependency generation (our Step 10), separating
  source from binary (our `build/make/`), generated sources. Most embedded-relevant.
- **Ch 6 "Managing Large Projects"** — HIGH. Recursive vs non-recursive make, multi-dir
  component layout. This is how you scale to FreeRTOS kernel + middleware + app.
- **Ch 7 "Portable Makefiles"** — MEDIUM. Cross-shell/cross-OS (Windows vs Linux/CI),
  the `$(shell)`/tool-detection idioms. Relevant given our Git-Bash-vs-cmd gotcha.
- **Debugging Makefiles** (appendix/section) — supports our Step 11.
- Skim/skip: Ch 9 "Java" (not relevant).

Key insight to record: **our wildcard + pattern-rule Makefile ALREADY scales to
FreeRTOS.** Adding an RTOS is just: +5–6 kernel `.c` (tasks/queue/list/timers +
`heap_4.c` + the `ARM_CM7/r0p1` `port.c`), +2 include dirs (`Source/include`,
`portable/GCC/ARM_CM7/r0p1`), and a `FreeRTOSConfig.h`. No new Make concepts — just
more entries in `C_SOURCES`/`C_INCLUDES`. The real new *concepts* for scale are
Ch 6 (organization) and Ch 8 (dependency correctness). Beyond Make, mastery also
needs: linker scripts, startup/vector table, and (at big scale) why CMake/Kconfig/
West/Zephyr exist.
