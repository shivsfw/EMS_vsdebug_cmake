# Some Windows shells hand gcc a non-writable TEMP (e.g. C:\WINDOWS).
# Force a writable one. 'export' pushes a Make variable into the environment
# of every recipe command, overriding whatever was inherited.
export TMP  := $(CURDIR)/build/tmp
export TEMP := $(CURDIR)/build/tmp

VPATH = Core/Src

hello:
	@echo "Make is alive now! Working dir: $(CURDIR)"

main.o: main.c
	arm-none-eabi-gcc -c $< -o $@