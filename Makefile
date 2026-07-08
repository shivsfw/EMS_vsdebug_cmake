# Some Windows shells hand gcc a non-writable TEMP (e.g. C:\WINDOWS).
# Force a writable one. 'export' pushes a Make variable into the environment
# of every recipe command, overriding whatever was inherited.
export TMP  := $(CURDIR)/build/tmp
export TEMP := $(CURDIR)/build/tmp

# ---- Toolchain -------------------------------------------------------------
CC := arm-none-eabi-gcc

# ---- MCU architecture (must be identical for compile AND link) -------------
MCU := -mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard

# ---- Preprocessor defines --------------------------------------------------
C_DEFS := -DSTM32F767xx -DUSE_HAL_DRIVER

# ---- Include search paths --------------------------------------------------
C_INCLUDES := -I Core/Inc \
  -I Drivers/STM32F7xx_HAL_Driver/Inc \
  -I Drivers/STM32F7xx_HAL_Driver/Legacy \
  -I Drivers/CMSIS/Device/ST/STM32F7xx/Include \
  -I Drivers/CMSIS/Include

# ---- Optimisation / debug / warnings ---------------------------------------
OPT := -O0 -g3 #-gdwarf-2
WARN := -Wall #-Wextra -Wno-unused-parameter -Wno-unused-variable \
  -Wno-unused-function

# ---- One bag of flags for the C compiler -----------------------------------
#This is a paired technique: -ffunction-sections -fdata-sections at compile, 
#--gc-sections at link. Together they shrink your image from ~megabytes of 
#linked HAL to ~18 KB. (Since CFLAGS changed and Makefile is a prereq, your 
#next build recompiles everything — expected.)
CFLAGS := $(MCU) $(C_DEFS) $(C_INCLUDES) $(OPT) $(WARN) -ffunction-sections \
  -fdata-sections

ASMFLAGS := $(MCU) -x assembler-with-cpp

# ---- Where build outputs go ------------------------------------------------
BUILD := build/make

# ---- Source discovery (scan the filesystem) --------------------------------
C_SOURCES := $(wildcard Core/Src/*.c) \
  $(wildcard Drivers/STM32F7xx_HAL_Driver/Src/*.c)

ASM_SOURCES := startup_stm32f767xx.s

# ---- Derive the object list from the sources -------------------------------
OBJECTS := $(addprefix $(BUILD)/,$(C_SOURCES:.c=.o))
OBJECTS += $(addprefix $(BUILD)/,$(ASM_SOURCES:.s=.o))

#VPATH = Core/Src

TARGET := EMS_vsdebug_cmake

# ---- Tools -----------------------------------------------------------------
CP := arm-none-eabi-objcopy
SZ := arm-none-eabi-size

# ---- Linker ----------------------------------------------------------------
LDSCRIPT := STM32F767XX_FLASH.ld
LDFLAGS  := $(MCU) -T$(LDSCRIPT) --specs=nano.specs \
            -Wl,-Map=$(BUILD)/$(TARGET).map,--cref -Wl,--gc-sections -lm

.PHONY: show objects all
all: $(BUILD)/$(TARGET).elf $(BUILD)/$(TARGET).hex $(BUILD)/$(TARGET).bin

show:
	@echo "=== C_SOURCES ==="; echo $(C_SOURCES) | tr ' ' '\n'
	@echo "=== OBJECTS ===";   echo $(OBJECTS)   | tr ' ' '\n'

objects: $(OBJECTS)


#Why Makefile is a prerequisite: your flags (CFLAGS) live in the Makefile. 
#Listing Makefile as a prereq means that if you edit any flag, every 
#object becomes out-of-date and rebuilds — so you never ship objects 
#built with stale flags. (Trade-off: editing a comment also triggers a 
#full rebuild. Worth it.)
$(BUILD)/%.o: %.c Makefile
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.o: %.s Makefile
	@mkdir -p $(dir $@)
	$(CC) $(ASMFLAGS) -c $< -o $@

# Link all objects into the .elf, then print the size summary
$(BUILD)/$(TARGET).elf: $(OBJECTS)
	$(CC) $^ $(LDFLAGS) -o $@
	$(SZ) $@

# .elf -> Intel HEX (for many flashers)
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(CP) -O ihex $< $@

# .elf -> raw binary (for dfu / offset flashing)
$(BUILD)/%.bin: $(BUILD)/%.elf
	$(CP) -O binary -S $< $@

hello:
	@echo "Make is alive now! Working dir: $(CURDIR)"

#-D is the command-line equivalent of writing #define STM32F767xx at the top of 
#every file — it configures the same headers to behave for your specific target. 
#This is a cornerstone of embedded C: one HAL source tree, specialized per-chip 
#entirely through -D symbols.
#main.o: main.c 
#	$(CC) $(CFLAGS) -c $< -o $@



#Sen Habit
#Use Unix commands
#Case sensitive makefiles 
#Last line does not have a '\' char for any recipe
#Multi-line var definitions like C_Includes, the next line should be indented with spaces, 
#   not tabs. Tabs are only for recipes.	
