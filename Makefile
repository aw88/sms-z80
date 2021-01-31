CC = wla-z80
CFLAGS = -o
LD = wlalink
LDFLAGS = -v -d -s

DIRS=out

SFILES = main.s
IFILES =
OFILES = main.o

$(shell mkdir -p $(DIRS))

all: $(OFILES) Makefile
	$(LD) $(LDFLAGS) linkfile z80.sms

main.o: src/main.asm
	$(CC) $(CFLAGS) out/main.o src/main.asm

$(OFILES): $(HFILES)
