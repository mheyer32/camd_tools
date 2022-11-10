#provide these as env variables at commandline
# i.e.  DEBUG=1 make all -j8
DEBUG ?= 0
BINDIR ?= bin
USEIXEMUL ?= 1
PROFILE  ?= 0

CC=m68k-amigaos-gcc
STRIP=m68k-amigaos-strip
PHXASS=vasmm68k_mot

PREFIX = $(shell ./getprefix.sh "$(CC)")

CLIB_CFLAGS = -mcrt=clib2 -DUSECLIB2
CLIB_LDFLAGS = -mcrt=clib2

NOIXEMUL_CFLAGS = -noixemul -DUSENOIXEMUL
NOIXEMUL_LDFLAGS = -noixemul

ifeq ($(USEIXEMUL), 1)
RUNTIME_CFLAGS = $(NOIXEMUL_CFLAGS)
RUNTIME_LDFLAGS = $(NOIXEMUL_LDFLAGS)
else
	RUNTIME_CFLAGS = $(CLIB_CFLAGS)
	RUNTIME_LDFLAGS = $(CLIB_LDFLAGS)
endif

CFLAGS  = $(RUNTIME_CFLAGS)
LDFLAGS = $(RUNTIME_LDFLAGS)

CFLAGS += -fbaserel -m68020-60 -mtune=68030 -msmall-code -mregparm=4 -msoft-float
CFLAGS += -Werror -Wimplicit -Wstrict-prototypes -Wdouble-promotion -fstrict-aliasing

#Always	provide symbols, will be stripped away  for target executable
CFLAGS += -g -ggdb
LDFLAGS += -g -ggdb 

ifeq ($(DEBUG), 1)
	CFLAGS += -DDEBUG -Og -ffast-math -fno-omit-frame-pointer
	#-DRANGECHECK
else
	CFLAGS += -DNDEBUG -Os -fstrength-reduce -ffast-math
	ifeq ($(PROFILE), 0)
		CFLAGS +=-fomit-frame-pointer
	endif
endif

CFLAGS += -D__BIG_ENDIAN__ 

CFLAGS_DOOMSOUND := $(CFLAGS)

ifeq ($(PROFILE), 1)
	CFLAGS += -pg
	LDFLAGS += -pg
endif

PFLAGS = -Fhunk -phxass -nosym -ldots -m68030 -linedebug
PFLAGS += -I$(PREFIX)/m68k-amigaos/ndk-include
PFLAGS += -I$(PREFIX)/m68k-amigaos/ndk/include

INTERMEDIATE =$(CURDIR)/build/
OUT = $(CURDIR)/bin/

#$(info $(OBJS))

all:	doomsound_midi.library NullModem CAMDoomSound

clean:
	rm -f *.o
	rm -f doomsound_midi.library
	rm -f NullModem
	rm -f CAMDoomSound

%.o:	%.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@

%.s:	%.c Makefile
	$(CC) $(CFLAGS) -Wa,-adhln -g -c $<  > $@

%.o: %.s | Makefile
	$(PHXASS) $(PFLAGS) $^

%.o: %.ASM | Makefile
	$(PHXASS) $(PFLAGS) -sc $^

DoomSnd.h: doomsound.fd doomsound.h Makefile
	fd2pragma --infile doomsound.fd --clib doomsound.h --externc --special 47

DoomSndFwd.h: doomsound_fwd.fd doomsound_fwd.h Makefile
	fd2pragma --infile doomsound_fwd.fd --clib doomsound_fwd.h --externc --special 47

doomsound_midi.library: doomsound_midi.c musplay.c | DoomSndFwd.h Makefile
	$(CC) $(CFLAGS_DOOMSOUND) -I./ -flto -ramiga-lib -fbaserel -o $@ $^
	$(STRIP) --strip-debug --strip-unneeded --strip-all $@ -o  $(BINDIR)/$@

NullModem: INTERNAL.o | Makefile
	$(CC) -g -ggdb -nostdlib -nostartfiles -nodefaultlibs -o $@ $^ -lamiga
	$(STRIP) --strip-debug --strip-unneeded --strip-all $@ -o  $(BINDIR)/$@

CAMDoomSound: camdoom.c musplay.c | Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) -Wno-strict-prototypes -o $@ $^
	$(STRIP) --strip-debug --strip-unneeded --strip-all $@ -o $(BINDIR)/$@

#############################################################
#
#############################################################
