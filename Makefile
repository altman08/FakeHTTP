CROSS_PREFIX :=
CC=$(CROSS_PREFIX)gcc
STRIP=$(CROSS_PREFIX)strip

PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
SRCDIR=src
INCLUDEDIR=include
BUILDDIR=build
SRCS := $(wildcard $(SRCDIR)/*.c)
OBJS := $(patsubst $(SRCDIR)/%.c,$(BUILDDIR)/%.o,$(SRCS))

override CFLAGS+=-std=c99 -I$(INCLUDEDIR) -frandom-seed=fakehttp \
	-pedantic -Wall -Wextra -Wdate-time

ifdef VERSION
	override CFLAGS += -DVERSION=\"$(VERSION)\"
endif

FAKEHTTP=$(BUILDDIR)/fakehttp

ifeq ($(STATIC), 1)
	override LDFLAGS += -static
endif

# STATIC_LIBNFQ=1: statically link libnetfilter_queue/libnfnetlink/libmnl
# only, while still dynamically linking libc and other system libraries.
# This keeps the binary free of runtime dependencies on those three
# libraries without bloating it with a fully static libc.
ifeq ($(STATIC_LIBNFQ), 1)
	override LDFLAGS += -Wl,-Bstatic -lnetfilter_queue -lnfnetlink -lmnl -Wl,-Bdynamic
else
	override LDFLAGS += -lnetfilter_queue -lnfnetlink -lmnl
endif

ifeq ($(DEBUG), 1)
	override CFLAGS += -O0 -g3 -fsanitize=address,leak,undefined
	override LDFLAGS += -fsanitize=address,leak,undefined
else
	override CFLAGS += -O3
endif

all: $(FAKEHTTP)

debug:
	$(MAKE) DEBUG=1

clean:
	$(RM) -r $(BUILDDIR)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BUILDDIR)/%.d: $(SRCDIR)/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -MM -MT $(@:.d=.o) $< -MF $@

$(BUILDDIR)/%.o: $(SRCDIR)/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(FAKEHTTP): $(OBJS) $(MKS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)
ifneq ($(DEBUG), 1)
	$(STRIP) $@
endif

install: all
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 $(FAKEHTTP) $(DESTDIR)$(BINDIR)/fakehttp

uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/fakehttp

.PHONY: all debug clean install uninstall

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJS:.o=.d)
endif
