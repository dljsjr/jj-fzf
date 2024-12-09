# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

SHELL	::= /bin/bash -o pipefail
prefix	 ?= /usr/local
bindir	 ?= ${prefix}/bin
INSTALL	::= install -c
RM	::= rm -f
Q	::= $(if $(findstring 1, $(V)),, @)

all: check

install: jj-fzf
	$(INSTALL) -t "$(bindir)" $<

uninstall:
	$(RM) "$(bindir)/jj-fzf"

shellcheck-warning: jj-fzf
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S warning -e SC2178,SC2207,SC2128 jj-fzf
shellcheck-error:
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error jj-fzf
test: jj-fzf
	$Q ./testing.sh
tests-basics.sh:
	$Q tests/basics.sh
check: jj-fzf shellcheck-error test tests-basics.sh
