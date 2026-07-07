# Some Windows shells hand gcc a non-writable TEMP (e.g. C:\WINDOWS).
# Force a writable one. 'export' pushes a Make variable into the environment
# of every recipe command, overriding whatever was inherited.
export TMP  := $(CURDIR)/build/tmp
export TEMP := $(CURDIR)/build/tmp

VPATH = Core/Src

hello:
	@echo "Make is alive now! Working dir: $(CURDIR)"

#-D is the command-line equivalent of writing #define STM32F767xx at the top of 
#every file — it configures the same headers to behave for your specific target. 
#This is a cornerstone of embedded C: one HAL source tree, specialized per-chip 
#entirely through -D symbols.
main.o: main.c 
	arm-none-eabi-gcc -c $< -o $@ -DSTM32F767xx -DUSE_HAL_DRIVER\
	  -I Core/Inc \
	  -I Drivers/STM32F7xx_HAL_Driver/Inc \
	  -I Drivers/STM32F7xx_HAL_Driver/Legacy \
	  -I Drivers/CMSIS/DEVICE/ST/STM32F7xx/Include \
	  -I Drivers/CMSIS/Include \