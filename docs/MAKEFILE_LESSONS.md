# Makefile Lessons — Hand-writing a Cross-Compile Build for STM32F767

> A living reference built from the exercise of writing this project's `Makefile`
> by hand (Track B of PROJECT_GUIDE.md). Captures the *concepts*, the *errors we
> hit and what each taught*, the *embedded cross-compilation specifics*, and a
> *debugging cheat sheet*. Keep appending as you learn more.

---

## 0. The big picture: what a build actually does

Four stages turn C/asm text into a flashable image:

```
 .c  ──preprocess──▶ (headers pasted in, macros expanded)
     ──compile─────▶ .s   (assembly for the target CPU)
 .s  ──assemble────▶ .o   (machine code, unresolved addresses/symbols)
 .o… ──link────────▶ .elf (all objects merged, symbols resolved, sections
                            placed at real addresses by the linker script)
 .elf──objcopy─────▶ .hex / .bin  (plain formats a flasher understands)
```

`arm-none-eabi-gcc` is a **driver** that runs preprocess+compile+assemble (and,
when linking, invokes `ld` with the right startup code and libc). We call gcc for
everything except `objcopy`/`size`.

Key numbers for this board: flash 2 MB @ `0x08000000`, RAM 512 KB @ `0x20000000`,
core = Cortex-M7 (Thumb-only, double-precision FPU).

---

## 1. Make fundamentals

**A rule:**
```make
target: prerequisite1 prerequisite2
	recipe-command        # <-- MUST start with a TAB, not spaces
```
- **target** — the file (or phony name) to build.
- **prerequisites** — files that must exist & be up-to-date first. Make resolves
  each as a real file on disk (relative to cwd, or via `VPATH`). If a prereq is
  newer than the target, the recipe re-runs.
- **recipe** — shell commands. Every recipe line begins with a **TAB**. `@` at the
  start of a command runs it without echoing the command text first.
- **default goal** — the **first** rule in the file runs when you type `make` with
  no target. (We made `all` first on purpose.)

**Phony targets** — names that aren't files (`all`, `clean`, `flash`, `show`).
Declare them so a same-named file can't disable them, and so they always run:
```make
.PHONY: all clean flash
```

---

## 2. Variables (Ch 3)

| Operator | Name | When the right-hand side expands |
|---|---|---|
| `:=` | simply expanded | **Once, immediately** when Make reads the line. **Default choice.** |
| `=`  | recursively expanded | **Every time the variable is used** (deferred). Flexible but surprising; `x = $(x)…` is an error. |
| `?=` | conditional | Assign **only if not already set** — good for user-overridable defaults (`make OPT=-Os`). |
| `+=` | append | Add words to a variable. |

Because we use `:=`, a variable must be **defined above** any variable that
references it (e.g. `CFLAGS := $(MCU) …` needs `MCU` defined earlier).

**`export VAR := value`** puts the variable into the *environment* that recipe
shells see — we used it to override a broken `TEMP` for gcc.

**Expansion happens in two phases:** (1) Make reads the whole makefile, expanding
variable *assignments* and rule *targets/prereqs* immediately; (2) it runs recipes,
expanding them only then. That's why `:=` vs `=` and definition order matter.

---

## 3. Automatic variables (only valid inside a recipe)

| Var | Meaning | Example value |
|---|---|---|
| `$@` | the target | `build/make/Core/Src/main.o` |
| `$<` | the **first** prerequisite (VPATH-resolved) | `Core/Src/main.c` |
| `$^` | **all** prerequisites (deduped) | every `.o` (used in the link) |
| `$?` | prereqs **newer** than the target | (used for incremental `ar`, etc.) |
| `$*` | the **stem** matched by `%` in a pattern rule | `Core/Src/main` |

Variants `$(@D)`/`$(@F)` give the directory / file part. We used `$(dir $@)` to
`mkdir -p` the output folder.

**Lesson learned:** `VPATH`/`vpath` tells *Make* where to find *prerequisites* —
it does **NOT** rewrite recipe text. So a recipe must reference the file via `$<`
(which carries the resolved path), not the bare filename. Once object paths carry
their own directory (pattern rule `$(BUILD)/%.o: %.c`), `VPATH` is unnecessary.

---

## 4. Functions used (Ch 4)

- `$(wildcard Core/Src/*.c)` — expand a glob to files that **actually exist**.
  (`*` in a plain assignment is NOT expanded — always wrap it in `$(wildcard)`.)
- `$(VAR:.c=.o)` — **substitution reference**, shorthand for
  `$(patsubst %.c,%.o,$(VAR))`; swaps the `.c` suffix for `.o` on each word.
- `$(addprefix build/make/,$(list))` — prepend a string to each word.
- `$(dir $@)` — the directory part of a path.
- Debug/printing: `$(info …)` (print), `$(warning …)` (print with file:line),
  `$(error …)` (print and stop).

**The object-list pipeline:**
```
Core/Src/main.c ─(:.c=.o)→ Core/Src/main.o ─(addprefix build/make/)→ build/make/Core/Src/main.o
```

---

## 5. Pattern rules (Ch 2)

```make
$(BUILD)/%.o: %.c Makefile
	@mkdir -p $(dir $@)
	$(CC) -c $< -o $@ $(CFLAGS)
```
- `%` is the **stem**; the same stem is reused on both sides. One rule compiles
  *every* `.c`.
- Listing **`Makefile`** as a prereq forces a full rebuild whenever you change a
  flag (flags live in the Makefile).
- Make picks between competing pattern rules (`%.c` vs `%.s`) by which prerequisite
  actually exists.

---

## 6. Embedded cross-compilation specifics (the heart of it)

**Cross-compiler:** `arm-none-eabi-gcc` runs on the PC but emits ARM code.
`-c` = compile/assemble only, don't link (produce `.o`).

**Include paths (`-I`)** — where the compiler searches for `#include`d headers.
The five, layered app → HAL → device → ARM core:
```
-I Core/Inc                                       # your app + hal_conf.h
-I Drivers/STM32F7xx_HAL_Driver/Inc               # ST HAL API
-I Drivers/STM32F7xx_HAL_Driver/Inc/Legacy        # HAL legacy aliases
-I Drivers/CMSIS/Device/ST/STM32F7xx/Include      # ST device regs (stm32f767xx.h)
-I Drivers/CMSIS/Include                          # ARM CMSIS-Core (core_cm7.h)
```

**Preprocessor defines (`-D`)** — configure those shared headers for THIS chip:
- `-DSTM32F767xx` — selects the chip's register map (silences the
  `#error "Please select … target STM32F7xx device"`).
- `-DUSE_HAL_DRIVER` — pulls the HAL layer into the device header.

**MCU architecture flags** — must be IDENTICAL at compile AND link:
```
-mcpu=cortex-m7      # exact core (instruction set + scheduling)
-mthumb              # Cortex-M is Thumb-only (fixes 'cpsid i in ARM mode')
-mfpu=fpv5-d16       # the F7 hardware FPU
-mfloat-abi=hard     # pass floats in FPU registers (ABI must match everywhere)
```

**Dead-code removal (a paired technique):**
- compile with `-ffunction-sections -fdata-sections` (each symbol in its own section)
- link with `-Wl,--gc-sections` (drop sections nothing references)
→ shrinks the image from megabytes of HAL to ~18 KB.

**Linking (`LDFLAGS`):**
```
$(MCU)                         # yes — the linker needs these too (float ABI/multilib)
-T STM32F767XX_FLASH.ld        # linker script: place sections in F767 memory
--specs=nano.specs             # newlib-nano small C library (stubs from syscalls.c)
-Wl,-Map=…map,--cref           # emit a memory map + cross-reference
-Wl,--gc-sections              # (pairs with the compile flags above)
-lm                            # math library
```
Link *through* gcc (not `ld` directly) so startup/CRT glue and libc are added.
`-Wl,` forwards comma-separated options to the linker.

**Post-link:**
- `arm-none-eabi-objcopy -O ihex  in.elf out.hex`  (Intel HEX)
- `arm-none-eabi-objcopy -O binary -S in.elf out.bin`  (raw binary, stripped)
- `arm-none-eabi-size in.elf` → `text` (flash code+const), `data` (init'd RAM,
  stored in flash), `bss` (zero'd RAM). RAM used ≈ data + bss.

---

## 7. Errors we hit, and what each taught

| Error | Root cause | Fix | Concept |
|---|---|---|---|
| `*** missing separator` | recipe indented with spaces | use a real TAB | recipe syntax |
| `No rule to make target 'main.c'` | prereq `main.c` not found at cwd | correct path / `VPATH` | prereqs are real files |
| `Cannot create temporary file in C:\WINDOWS\` | shell handed gcc a bad `TEMP` | `export TMP/TEMP := $(CURDIR)/build/tmp` | env vs make vars |
| `cc1: main.c: No such file` (recipe ran) | `VPATH` doesn't rewrite recipes | use `$<` | automatic vars + VPATH |
| `fatal error: main.h: No such file` | no include paths | add the 5 `-I` | header search |
| `#error "Please select … STM32F7xx device"` | chip not defined | `-DSTM32F767xx` (+`-DUSE_HAL_DRIVER`) | `-D` configures headers |
| `cpsid i in ARM mode` | no `-mcpu/-mthumb` → default ARM mode | add MCU flags | Cortex-M is Thumb-only |
| `undefined reference to X` (link) | object missing from list / lib order | add source; `-l` after objects | linking |
| `multiple definition of X` (link) | file listed twice / defn in header | dedupe; `static`/`inline` in headers | linking |

---

## 8. Windows gotchas

- **Run `make` from a Unix shell** (Git Bash / msys2 UCRT64), not cmd/PowerShell —
  recipes use `sh` idioms (`mkdir -p`, `rm -rf`, `$$`). `mingw32-make` from cmd uses
  `cmd.exe` and those fail.
- **`TEMP=C:\WINDOWS`**: some shells hand gcc a non-writable temp dir → force a good
  one with `export TMP/TEMP` in the Makefile.
- **Case-insensitive filesystem** hides path-case bugs: `CMSIS/DEVICE` "worked" on
  Windows but the real folder is `Device`, and it would break on Linux/CI. Match case.

---

## 9. Debugging Makefiles — cheat sheet

**Add this once — inspect any variable:**
```make
print-%:
	@echo '$* = $($*)'
```
`make print-CFLAGS`, `make print-OBJECTS`, `make print-LDFLAGS`.

| Goal | Command |
|---|---|
| See commands without running them | `make -n` (a.k.a. `--dry-run`, `--just-print`) |
| Why did/didn't it rebuild? | `make --trace` or `make --debug=b` |
| Dump ALL rules + variables Make knows | `make -p` |
| Force rebuild everything | `make -B` |
| What would rebuild if I touched X? | `make -W path/to/x.h -n` |
| Don't stop at first error | `make -k` |
| Parallel build | `make -j$(nproc)` |
| Print a value mid-parse | `$(info X=$(X))` / `$(warning …)` / `$(error …)` |

**When the build succeeds but behavior is wrong**, inspect the artifacts:
`arm-none-eabi-nm x.elf` (symbols), `arm-none-eabi-objdump -d x.elf` (disassembly),
and the `.map` file (who pulled in what; final addresses).

---

## 10. Further reading (Mecklenburg, *Managing Projects with GNU Make*, 3rd ed.)

Read next, in order: **Ch 8 (C/C++ — auto-deps, source/binary separation)**,
**Ch 6 (Managing Large Projects — recursive vs non-recursive)**,
**Ch 7 (Portable Makefiles)**, and the Debugging appendix. Skip Ch 9 (Java).

**FreeRTOS note:** our `$(wildcard)` + pattern-rule Makefile already scales to it.
Adding an RTOS = +kernel sources (`tasks/queue/list/timers` + a heap + the
`ARM_CM7/r0p1` `port.c`), +2 include dirs, +a `FreeRTOSConfig.h`. No new Make
theory — the new *concepts* for scale are organization (Ch 6) and dependency
correctness (Ch 8).

---

## 11. Our Makefile's shape (annotated skeleton)

```
export TMP/TEMP        # Windows temp workaround
── Variables ──
TARGET, BUILD
CC, AS, CP, SZ         # toolchain
MCU                    # -mcpu -mthumb -mfpu -mfloat-abi
C_DEFS, C_INCLUDES
OPT, WARN
CFLAGS                 # = MCU + DEFS + INCLUDES + OPT + WARN + -ffunction/-fdata-sections
ASFLAGS                # = MCU + -x assembler-with-cpp
LDSCRIPT, LDFLAGS
C_SOURCES, ASM_SOURCES # via $(wildcard)
OBJECTS                # sources mapped under $(BUILD)
── Rules ──
all: elf hex bin       # default goal
$(BUILD)/%.o: %.c      # pattern rule (C)
$(BUILD)/%.o: %.s      # pattern rule (asm)
elf: $(OBJECTS)        # link + size
%.hex / %.bin          # objcopy
.PHONY: clean flash    # (Step 9) + print-%  (debug)
-include $(DEPS)        # (Step 10) auto-deps
```

*(Steps 9–11 get appended as we complete them.)*
```
