PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
MANDIR ?= $(PREFIX)/share/man
SYSCONFDIR ?= /etc

PLATFORMFILE := src/platform/$(shell uname | tr '[:upper:]' '[:lower:]').sh

.PHONY: install uninstall install-platform

all:
	@echo "Note store is a shell script, so there is nothing to do. Try \"make install\" instead."

install:
	@mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(LIBDIR)" "$(DESTDIR)$(MANDIR)/man1" "$(DESTDIR)$(SYSCONFDIR)/bash_completion.d"
	@install -m 0755 -v src/note-store.sh "$(DESTDIR)$(BINDIR)/pass"
	@install -m 0644 -v man/note.1 "$(DESTDIR)$(MANDIR)/man1/note.1"
	@install -m 0644 -v contrib/note.bash-completion "$(DESTDIR)$(SYSCONFDIR)/bash_completion.d/note-store"

#	Uncomment to install the zsh completion file.
#	@install -m 0644 -v contrib/pass.zsh-completion "$(DESTDIR)$(PREFIX)/share/zsh/site-functions/_pass"
#
#	Uncomment to install the fish completion file.
#	@install -m 0644 -v contrib/pass.fish-completion "$(DESTDIR)$(PREFIX)/share/fish/completions/pass.fish"

	@$(MAKE) -s install-platform

ifneq ($(strip $(wildcard $(PLATFORMFILE))),)
install-platform:
	@install -m 0644 -v "$(PLATFORMFILE)" "$(DESTDIR)$(LIBDIR)/note-store.platform.sh"
#	The -i "" doesn't work on GNU, where the extra argument isn't needed. Fortuantely, platform file is for non-GNU only.
	sed -i "" 's:.*platform-defined-functions.*:source $(DESTDIR)$(LIBDIR)/note-store.platform.sh:' "$(DESTDIR)$(BINDIR)/note"
else
install-platform:
endif

uninstall:
	@rm -vf "$(DESTDIR)$(BINDIR)/note" "$(DESTDIR)$(MANDIR)/man1/note.1" "$(DESTDIR)$(SYSCONFDIR)/bash_completion.d/note-store" "$(DESTDIR)$(LIBDIR)/note-store.platform.sh"
