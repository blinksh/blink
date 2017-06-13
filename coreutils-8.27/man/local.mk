# Make coreutils man pages.				-*-Makefile-*-
# This is included by the top-level Makefile.am.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

EXTRA_DIST += man/help2man man/dummy-man

## Graceful degradation for systems lacking perl.
if HAVE_PERL
run_help2man = $(PERL) -- $(srcdir)/man/help2man
else
run_help2man = $(SHELL) $(srcdir)/man/dummy-man
endif

man1_MANS = @man1_MANS@
EXTRA_DIST += $(man1_MANS:.1=.x)

EXTRA_MANS = @EXTRA_MANS@
EXTRA_DIST += $(EXTRA_MANS:.1=.x)

ALL_MANS = $(man1_MANS) $(EXTRA_MANS)

CLEANFILES += $(ALL_MANS)

# This is a kludge to remove generated 'man/*.1' from a non-srcdir build.
# Without this, "make distcheck" might fail.
distclean-local:
	test x$(srcdir) = x$(builddir) || rm -f $(ALL_MANS)

# Dependencies common to all man pages.  Updated below.
mandeps =

# Depend on this to get version number changes.
mandeps += .version

# This is required so that changes to e.g., emit_bug_reporting_address
# provoke regeneration of all the manpages.
mandeps += $(top_srcdir)/src/system.h

$(ALL_MANS): $(mandeps)

if SINGLE_BINARY
mandeps += src/coreutils$(EXEEXT)
else
# Most prog.1 man pages depend on src/prog.  List the exceptions:
man/install.1:   src/ginstall$(EXEEXT)
man/test.1:      src/[$(EXEEXT)

man/arch.1:      src/arch$(EXEEXT)
man/b2sum.1:     src/b2sum$(EXEEXT)
man/base32.1:    src/base32$(EXEEXT)
man/base64.1:    src/base64$(EXEEXT)
man/basename.1:  src/basename$(EXEEXT)
man/cat.1:       src/cat$(EXEEXT)
man/chcon.1:     src/chcon$(EXEEXT)
man/chgrp.1:     src/chgrp$(EXEEXT)
man/chmod.1:     src/chmod$(EXEEXT)
man/chown.1:     src/chown$(EXEEXT)
man/chroot.1:    src/chroot$(EXEEXT)
man/cksum.1:     src/cksum$(EXEEXT)
man/comm.1:      src/comm$(EXEEXT)
man/coreutils.1: src/coreutils$(EXEEXT)
man/cp.1:        src/cp$(EXEEXT)
man/csplit.1:    src/csplit$(EXEEXT)
man/cut.1:       src/cut$(EXEEXT)
man/date.1:      src/date$(EXEEXT)
man/dd.1:        src/dd$(EXEEXT)
man/df.1:        src/df$(EXEEXT)
man/dir.1:       src/dir$(EXEEXT)
man/dircolors.1: src/dircolors$(EXEEXT)
man/dirname.1:   src/dirname$(EXEEXT)
man/du.1:        src/du$(EXEEXT)
man/echo.1:      src/echo$(EXEEXT)
man/env.1:       src/env$(EXEEXT)
man/expand.1:    src/expand$(EXEEXT)
man/expr.1:      src/expr$(EXEEXT)
man/factor.1:    src/factor$(EXEEXT)
man/false.1:     src/false$(EXEEXT)
man/fmt.1:       src/fmt$(EXEEXT)
man/fold.1:      src/fold$(EXEEXT)
man/groups.1:    src/groups$(EXEEXT)
man/head.1:      src/head$(EXEEXT)
man/hostid.1:    src/hostid$(EXEEXT)
man/hostname.1:  src/hostname$(EXEEXT)
man/id.1:        src/id$(EXEEXT)
man/join.1:      src/join$(EXEEXT)
man/kill.1:      src/kill$(EXEEXT)
man/link.1:      src/link$(EXEEXT)
man/ln.1:        src/ln$(EXEEXT)
man/logname.1:   src/logname$(EXEEXT)
man/ls.1:        src/ls$(EXEEXT)
man/md5sum.1:    src/md5sum$(EXEEXT)
man/mkdir.1:     src/mkdir$(EXEEXT)
man/mkfifo.1:    src/mkfifo$(EXEEXT)
man/mknod.1:     src/mknod$(EXEEXT)
man/mktemp.1:    src/mktemp$(EXEEXT)
man/mv.1:        src/mv$(EXEEXT)
man/nice.1:      src/nice$(EXEEXT)
man/nl.1:        src/nl$(EXEEXT)
man/nohup.1:     src/nohup$(EXEEXT)
man/nproc.1:     src/nproc$(EXEEXT)
man/numfmt.1:    src/numfmt$(EXEEXT)
man/od.1:        src/od$(EXEEXT)
man/paste.1:     src/paste$(EXEEXT)
man/pathchk.1:   src/pathchk$(EXEEXT)
man/pinky.1:     src/pinky$(EXEEXT)
man/pr.1:        src/pr$(EXEEXT)
man/printenv.1:  src/printenv$(EXEEXT)
man/printf.1:    src/printf$(EXEEXT)
man/ptx.1:       src/ptx$(EXEEXT)
man/pwd.1:       src/pwd$(EXEEXT)
man/readlink.1:  src/readlink$(EXEEXT)
man/realpath.1:  src/realpath$(EXEEXT)
man/rm.1:        src/rm$(EXEEXT)
man/rmdir.1:     src/rmdir$(EXEEXT)
man/runcon.1:    src/runcon$(EXEEXT)
man/seq.1:       src/seq$(EXEEXT)
man/sha1sum.1:   src/sha1sum$(EXEEXT)
man/sha224sum.1: src/sha224sum$(EXEEXT)
man/sha256sum.1: src/sha256sum$(EXEEXT)
man/sha384sum.1: src/sha384sum$(EXEEXT)
man/sha512sum.1: src/sha512sum$(EXEEXT)
man/shred.1:     src/shred$(EXEEXT)
man/shuf.1:      src/shuf$(EXEEXT)
man/sleep.1:     src/sleep$(EXEEXT)
man/sort.1:      src/sort$(EXEEXT)
man/split.1:     src/split$(EXEEXT)
man/stat.1:      src/stat$(EXEEXT)
man/stdbuf.1:    src/stdbuf$(EXEEXT)
man/stty.1:      src/stty$(EXEEXT)
man/sum.1:       src/sum$(EXEEXT)
man/sync.1:      src/sync$(EXEEXT)
man/tac.1:       src/tac$(EXEEXT)
man/tail.1:      src/tail$(EXEEXT)
man/tee.1:       src/tee$(EXEEXT)
man/timeout.1:   src/timeout$(EXEEXT)
man/touch.1:     src/touch$(EXEEXT)
man/tr.1:        src/tr$(EXEEXT)
man/true.1:      src/true$(EXEEXT)
man/truncate.1:  src/truncate$(EXEEXT)
man/tsort.1:     src/tsort$(EXEEXT)
man/tty.1:       src/tty$(EXEEXT)
man/uname.1:     src/uname$(EXEEXT)
man/unexpand.1:  src/unexpand$(EXEEXT)
man/uniq.1:      src/uniq$(EXEEXT)
man/unlink.1:    src/unlink$(EXEEXT)
man/uptime.1:    src/uptime$(EXEEXT)
man/users.1:     src/users$(EXEEXT)
man/vdir.1:      src/vdir$(EXEEXT)
man/wc.1:        src/wc$(EXEEXT)
man/who.1:       src/who$(EXEEXT)
man/whoami.1:    src/whoami$(EXEEXT)
man/yes.1:       src/yes$(EXEEXT)
endif

.x.1:
	$(AM_V_GEN)name=`echo $@ | sed 's|.*/||; s|\.1$$||'` || exit 1;	\
## Ensure that help2man runs the 'src/ginstall' binary as 'install' when
## creating 'install.1'.  Similarly, ensure that it uses the 'src/[' binary
## to create 'test.1'.
	case $$name in							\
	  install) prog='ginstall'; argv=$$name;;			\
	     test) prog='['; argv='[';;					\
		*) prog=$$name; argv=$$prog;;				\
	esac;								\
## Note the use of $$t/$*, rather than just '$*' as in other packages.
## That is necessary to avoid failures for programs that are also shell
## built-in functions like echo, false, printf, pwd.
	rm -f $@ $@-t							\
	  && t=$*.td							\
	  && rm -rf $$t							\
	  && $(MKDIR_P) $$t						\
	  && (cd $$t && $(LN_S) '$(abs_top_builddir)/src/'$$prog$(EXEEXT) \
				$$argv$(EXEEXT))			\
	&& : $${SOURCE_DATE_EPOCH=`cat $(srcdir)/.timestamp 2>/dev/null || :`} \
	&& export SOURCE_DATE_EPOCH && $(run_help2man)			\
		     --source='$(PACKAGE_STRING)'			\
		     --include=$(srcdir)/man/$$name.x			\
		     --output=$$t/$$name.1				\
		     --info-page='\(aq(coreutils) '$$name' invocation\(aq' \
		     $$t/$$argv$(EXEEXT)				\
	  && sed \
	       -e 's|$*\.td/||g' \
	       -e '/For complete documentation/d' \
	       $$t/$$name.1 > $@-t			\
	  && rm -rf $$t							\
	  && chmod a-w $@-t						\
	  && mv $@-t $@
