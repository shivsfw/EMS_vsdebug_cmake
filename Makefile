# Some Windows shells hand gcc a non-writable TEMP (e.g. C:\WINDOWS).
# Force a writable one. 'export' pushes a Make variable into the environment
# of every recipe command, overriding whatever was inherited.
export TMP  := $(CURDIR)/build/tmp
export TEMP := $(CURDIR)/build/tmp

VPATH = Core/Src

hello:
	@echo "Make is alive now! Working dir: $(CURDIR)"

#this will fail as VPATH does not expand the file in the command script, so we need to use the full path to the file
main.o: main.c
	arm-none-eabi-gcc -c main.c -o main.o