include gnulib.mk

AM_CFLAGS = $(GNULIB_TEST_WARN_CFLAGS) $(WERROR_CFLAGS)

# A few tests are inherently warning-evoking.
# In the typical case where we use -Werror, exempt the few offenders.

# test-xvasprintf.c: In function 'test_xasprintf':
# test-xvasprintf.c:100: error: format not a string literal and no \
#   format arguments [-Wformat-security]
test_xvasprintf_CFLAGS = $(AM_CFLAGS) \
  `test -n '$(WERROR_CFLAGS)' && echo ' -Wno-format-security'`

# test-lock.c: In function 'lock_mutator_thread':
# test-lock.c:148: error: cast from function call of type 'pthread_t' to \
#   non-matching type 'void *' [-Wbad-function-cast]
test_lock_CFLAGS = $(AM_CFLAGS) \
  `test -n '$(WERROR_CFLAGS)' && echo ' -Wno-bad-function-cast'`
test_tls_CFLAGS = $(AM_CFLAGS) \
  `test -n '$(WERROR_CFLAGS)' && echo ' -Wno-bad-function-cast'`
