////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#include <sys/time.h>
#include <arpa/inet.h>
#include <getopt.h>
#include <libssh2/libssh2.h>
#include <libssh2/libssh2_sftp.h>
#include <limits.h>
#include <netdb.h>
#include <poll.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/time.h>

#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"
#import "SSHSession.h"

#define REQUEST_TTY_AUTO 0
#define REQUEST_TTY_NO 1
#define REQUEST_TTY_YES 2
#define REQUEST_TTY_FORCE 3

#define PORT 22
#define TERM "xterm-256color"

static const char *usage_format =
  "usage: ssh [options] [user@]hostname [command]\r\n"
  "[-l login_name] [-i identity_file] [-p port]\r\n" 
  "[-t request_tty] [-v verbose]\r\n"
  "\r\n";

typedef struct {
  int address_family;
  int connection_timeout;
  int port;
  const char *hostname;
  const char *user;
  int request_tty;
  const char *identity_file;
  const char *password;
  BOOL disableHostKeyCheck;
} Options;


@interface SSHSession ()
@end

@implementation SSHSession {
  Options _options;
  //SSHWrapper _ssh;
  int _sock;
  LIBSSH2_SESSION *_session;
  LIBSSH2_CHANNEL *_channel;
  NSMutableArray *_identities;
  const char *_command;
  int _tty_flag;
}

static int waitsocket(int socket_fd, LIBSSH2_SESSION *session)
{
  struct timeval timeout;
  int rc;
  fd_set fd;
  fd_set *writefd = NULL;
  fd_set *readfd = NULL;
  int dir;

  timeout.tv_sec = 10;
  timeout.tv_usec = 0;

  FD_ZERO(&fd);

  FD_SET(socket_fd, &fd);

  /* now make sure we wait in the correct direction */
  dir = libssh2_session_block_directions(session);

  if (dir & LIBSSH2_SESSION_BLOCK_INBOUND)
    readfd = &fd;

  if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
    writefd = &fd;

  rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);

  return rc;
}

static void kbd_callback(const char *name, int name_len,
			 const char *instruction, int instruction_len,
			 int num_prompts,
			 const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
			 LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
			 void **abstract)
{
  SSHSession *s = (__bridge SSHSession *)(*abstract);
  // We want to write straight to the control
  // ssh does the same and writes straight to /dev/tty or stderr
  FILE *termout = s->_stream.control.termout;
  if (name_len > 0) {
    fwrite(name, 1, name_len, termout);
    fprintf(termout, "\r\n");
  }
  if (instruction_len > 0) {
    fwrite(instruction, 1, instruction_len, termout);
    fprintf(termout, "\r\n");
  }

  for (int i = 0; i < num_prompts; i++) {
    fwrite(prompts[i].text, 1, prompts[i].length, termout);
    responses[i].length = (int)[s promptUser:&responses[i].text];
    fprintf(termout, "\r\n");
  }
} /* kbd_callback */

- (ssize_t)promptUser:(char **)resp
{
  //char *line=NULL;
  size_t size = 0;
  ssize_t sz = 0;

  FILE *termin = _stream.control.termin;
  if ((sz = getdelim(resp, &size, '\r', termin)) == -1) {
    return -1;
  } else {
    if ((*resp)[sz - 1] == '\r') {
      (*resp)[--sz] = '\0';
    }
    return sz;
  }
}

- (int)main:(int)argc argv:(char **)argv
{
  // Options
  // port -p
  // verbose --verbose
  // command (Obtain data at the end)
  // tty -t
  // key -i identity file
  // forced password
  optind = 1;

  while (1) {
    int c = getopt_long(argc, argv, "p:i:htvl:", NULL, NULL);
    if (c == -1) {
      break;
    }
    char *ep;
    switch (c) {
      case 'p':
	_options.port = (unsigned int)strtol(optarg, &ep, 10);
	if (optarg == ep || *ep != '\0' || _options.port > 65536) {
	  return [self dieMsg:@"Wrong port value provided."];
	}
	break;
      case 'h':
        _options.disableHostKeyCheck = true;
        break;
      case 'v':
	_debug = 1;
	break;
      case 'i':
	_options.identity_file = optarg;
	break;
      case 't':
	_options.request_tty = REQUEST_TTY_FORCE;
	break;
      case 'l':
	_options.user = optarg;
	break;
      default:
	optind = 0;
	return [self dieMsg:@(usage_format)];
    }
  }

  if (argc - optind < 1) {
    return [self dieMsg:@(usage_format)];
  }

  NSString *userhost = [NSString stringWithFormat:@"%s", argv[optind++]];
  char **command = &argv[optind];
  int commands = argc - optind;

  NSArray *chunks = [userhost componentsSeparatedByString:@"@"];
  if ([chunks count] != 2) {
    _options.hostname = [userhost UTF8String];
  } else {
    _options.user = [chunks[0] UTF8String];
    _options.hostname = [chunks[1] UTF8String];
  }
  
  [self processHostSettings];

  if (!_options.user) {
    // If no user provided, use the default
    _options.user = [[BKDefaults defaultUserName] UTF8String];
  }

  NSMutableArray *command_args = [[NSMutableArray alloc] init];

  if (commands) {
    for (int i = 0; i < commands; i++) {
      [command_args addObject:[NSString stringWithFormat:@"%s", command[i]]];
    }
    _command = [[command_args componentsJoinedByString:@" "] UTF8String];
  } else {
    _options.request_tty = REQUEST_TTY_YES;
  }

  // Request tty can have different options, but depends on the process to choose whether to use it or not.
  // I want to maintain the REQUEST_TTY_XXX because it will give us flexibility with the command in the future.
  if ((_options.request_tty == REQUEST_TTY_FORCE) || (_options.request_tty == REQUEST_TTY_YES)) {
    _tty_flag = 1;
  } else {
    _tty_flag = 0;
  }

  _options.connection_timeout = 10;

  struct addrinfo *addrs;
  NSError *e = nil;

  // Obtain a list of all possible hosts for the name given.
  if ((addrs = [self resolve_host:_options.hostname port:_options.port]) == NULL) {
    return [self dieMsg:@"Could not resolve host address."];
  }

  // Connect to any of the hosts provided and return the successful one.
  struct sockaddr_storage hostaddr;
  [self ssh_connect:_options.hostname addrs:addrs succ_addr:&hostaddr error:&e];
  if (e != nil) {
    return [self dieMsg:[NSString stringWithFormat:@"Could not connect to host: %@", [e localizedDescription]]];
  }

  // Login to the host through one of the possible identities
  [self load_identity_files];
  [self ssh_login:_identities to:(struct sockaddr *)&hostaddr port:_options.port user:_options.user timeout:_options.connection_timeout error:&e];

  if (e != nil) {
    return [self dieMsg:[e localizedDescription]];
  }

  int exit_code = 0;
  exit_code = [self ssh_session_start];
  [self debugMsg:[NSString stringWithFormat:@"session finished with code %d", exit_code]];

  return exit_code;
}

- (int)dieMsg:(NSString *)msg
{
  fprintf(_stream.out, "%s\r\n", [msg UTF8String]);
  return -1;
}

- (void)errMsg:(NSString *)msg
{
  fprintf(_stream.err, "%s\r\n", [msg UTF8String]);
}

- (void)debugMsg:(NSString *)msg
{
  if (_debug) {
    fprintf(_stream.out, "SSHSession:DEBUG:%s\r\n", [msg UTF8String]);
  }
}

- (void)processHostSettings
{
  BKHosts *host;

  if (!(host = [BKHosts withHost:[NSString stringWithUTF8String:_options.hostname]])) {
    return;
  }

  _options.hostname = host.hostName ? [host.hostName UTF8String] : _options.hostname;
  _options.port = _options.port ? _options.port : [host.port intValue];
  if (!_options.user && [host.user length]) {
    _options.user = [host.user UTF8String];
  }
  _options.identity_file = _options.identity_file ? _options.identity_file : [host.key UTF8String];
  _options.password = host.password ? [host.password UTF8String] : NULL;
}

- (void)load_identity_files
{
  // Obtain valid auths that will be tried for the connection
  _identities = [[NSMutableArray alloc] init];
  BKPubKey *pk;

  if (_options.identity_file) {
    if ((pk = [BKPubKey withID:[NSString stringWithUTF8String:_options.identity_file]]) != nil) {
      [_identities addObject:pk];
    }
  }

  if ((pk = [BKPubKey withID:@"id_rsa"]) != nil) {
    [_identities addObject:pk];
  }
}

// Hosts and no hosts tested
- (struct addrinfo *)resolve_host:(const char *)name port:(int)port
{
  char strport[NI_MAXSERV];
  struct addrinfo hints, *res;
  int err;

  if (port <= 0) {
    port = PORT;
  }

  snprintf(strport, sizeof strport, "%d", port);
  memset(&hints, 0, sizeof(hints));
  // IPv4 / IPv6
  hints.ai_family = _options.address_family == -1 ? AF_UNSPEC : _options.address_family;
  hints.ai_socktype = SOCK_STREAM;

  if ((err = getaddrinfo(name, strport, &hints, &res)) != 0) {
    return NULL;
  }

  return res;
}

- (void)ssh_connect:(const char *)host addrs:(struct addrinfo *)aitop succ_addr:(struct sockaddr_storage *)hostaddr error:(NSError **)error
{
  struct addrinfo *ai;
  char ntop[NI_MAXHOST], strport[NI_MAXSERV];

  for (ai = aitop; ai; ai = ai->ai_next) {
    if (ai->ai_family != AF_INET && ai->ai_family != AF_INET6) {
      continue;
    }

    if (getnameinfo(ai->ai_addr, ai->ai_addrlen,
		    ntop, sizeof(ntop), strport,
		    sizeof(strport), NI_NUMERICHOST | NI_NUMERICSERV) != 0) {
      [self debugMsg:@"ssh_connect: getnameinfo failed"];
      continue;
    }

    [self debugMsg:[NSString stringWithFormat:@"Connecting to %.200s [%.100s] port %s.", host, ntop, strport]];
    _sock = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
    if (_sock < 0) {
      [self debugMsg:[NSString stringWithFormat:@"%s", strerror(errno)]];
      if (!ai->ai_next) {
	*error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"ssh: connect to host %s port %s: %s", host, strport, strerror(errno)] }];
	return;
      }

      continue;
    }

    if ([self timeout_connect:_sock
		    serv_addr:ai->ai_addr
		     addr_len:ai->ai_addrlen
		      timeout:&_options.connection_timeout] >= 0) {
      // Successful connection. Save host address
      memcpy(hostaddr, ai->ai_addr, ai->ai_addrlen);
      fprintf(_stream.out, "Connected to %s\r\n", ntop);
      break;
    } else {
      [self debugMsg:[NSString stringWithFormat:@"connect to host %s port %s: %s", ntop, strport, strerror(errno)]];
      _sock = -1;
    }
  }

  if (_sock < 0) {
    *error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"ssh: connect to host %s port %s: %s", host, strport, strerror(errno)] }];
    [self debugMsg:@"Could not establish a successful connection."];
    return;
  }

  if (0 != [self ssh_set_session]) {
    *error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"Error establishing SSH session." }];
    return;
  }

  if (!_options.disableHostKeyCheck) {
    if (![self verify_host:ntop]) {
      *error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"Host key verification failed." }];
    }
  } else {
    [self errMsg:@"@@@@@@ WARNING @@@@@@@@ --- Host Key check disabled."];
  }

  return;
}

- (int)ssh_set_session
{
  int rc;

  _session = libssh2_session_init();
  if (!_session) {
    [self debugMsg:@"Session init failed"];
    // *error = [NSError errorWithDomain:@"bnk.sessions.sshwrapper" code:401 userInfo:@{NSLocalizedDescriptionKey : @"Create session failed"}];
    return -1;
  }
  //libssh2_trace(_session, LIBSSH2_TRACE_SOCKET);

  libssh2_session_set_blocking(_session, 0);

  // Set timeout for libssh2 controlled functions
  libssh2_session_set_timeout(_session, _options.connection_timeout);

  /* ... start it up. This will trade welcome banners, exchange keys,
   * and setup crypto, compression, and MAC layers
   */
  char *errmsg;
  while ((rc = libssh2_session_handshake(_session, _sock)) ==
	 LIBSSH2_ERROR_EAGAIN)
    ;
  if (rc) {
    libssh2_session_last_error(_session, &errmsg, NULL, 0);
    [self debugMsg:[NSString stringWithFormat:@"%s", errmsg]];
    return -1;
  }

  // Set object as handler
  void **handler = libssh2_session_abstract(_session);
  *handler = CFBridgingRetain(self);

  return 0;
}

- (void)ssh_login:(NSArray *)ids to:(struct sockaddr *)addr port:(int)port user:(const char *)user timeout:(int)timeout error:(NSError **)error
{
  char *userauthlist = NULL;
  int auth_type;

  // Set supported auth_type from server
  do {
    userauthlist = libssh2_userauth_list(_session, user, (int)strlen(user));

    if (!userauthlist) {
      if (libssh2_session_last_errno(_session) != LIBSSH2_ERROR_EAGAIN) {
	*error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"No userauth list" }];
	return;
      } else {
	waitsocket(_sock, _session); /* now we wait */
      }
    }
  } while (!userauthlist);

  [self debugMsg:[NSString stringWithFormat:@"Authenticating as '%s'.", user]];

  if (strstr(userauthlist, "password") != NULL) {
    auth_type |= 1;
  }
  if (strstr(userauthlist, "keyboard-interactive") != NULL) {
    auth_type |= 2;
  }
  if (strstr(userauthlist, "publickey") != NULL) {
    auth_type |= 4;
  }

  int succ = 0;

  if (auth_type & 4) {
    succ = [self ssh_login_publickey:user];
  }
  if (!succ && _options.password) {
    succ = [self ssh_login_password:user password:_options.password];
  }
  if (!succ && (auth_type & 2)) {
    succ = [self ssh_login_interactive:user];
  }
  if (!succ && auth_type & 1) {
    succ = [self ssh_login_password:user password:NULL];
  }

  if (!succ) {
    *error = [NSError errorWithDomain:@"blk.ssh.libssh2" code:-1 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Permission denied (%s).", userauthlist] }];
    return;
  }

  return;
}

- (int)ssh_login_password:(const char *)user password:(char *)password
{
  int retries = 3;
  char *errmsg;

  do {
    int rc;
    if (!password) {
      fprintf(_stream.control.termout, "%s@%s's password: ", user, _options.hostname);
      [self promptUser:&password];
      fprintf(_stream.control.termout, "\r\n");
    }

    if (strlen(password) != 0) {
      while ((rc = libssh2_userauth_password(_session, user, password)) == LIBSSH2_ERROR_EAGAIN)
	;
      if (rc == 0) {
	[self debugMsg:@"Authentication by password succeeded."];
	return 1;
      } else if (rc != LIBSSH2_ERROR_PASSWORD_EXPIRED || rc != LIBSSH2_ERROR_AUTHENTICATION_FAILED) {
	libssh2_session_last_error(_session, &errmsg, NULL, 0);
	[self errMsg:[NSString stringWithFormat:@"Authentication by password failed: %s", errmsg]];
	return 0;
      }
    }
  } while (--retries);

  [self debugMsg:@"Could not match user and password."];
  return 0;
}

- (int)ssh_login_interactive:(const char *)user
{
  int rc;

  [self debugMsg:@"Attempting interactive authentication."];
  while ((rc = libssh2_userauth_keyboard_interactive(_session, user, &kbd_callback)) == LIBSSH2_ERROR_EAGAIN)
    ;

  if (rc == 0) {
    [self debugMsg:@"Authentication succeeded."];
    return 1;
  } else {
    [self debugMsg:@"Auth by password failed"];
  }
  return 0;
}

- (int)ssh_login_publickey:(const char *)user
{
  // Try all the identities until finding a successful one, and return
  for (BKPubKey *pk in _identities) {
    [self debugMsg:@"Attempting authentication with publickey."];
    int rc = 0;
    const char *pub = [pk.publicKey UTF8String];
    const char *priv = [pk.privateKey UTF8String];

    if (!priv || !pub) {
      [self debugMsg:@"Could not find public key files."];
      return 0;
    }

    char *passphrase = NULL;

    // Request passphrase from user
    if ([pk isEncrypted]) {
      fprintf(_stream.control.termout, "Enter your passphrase for key '%s':", [pk.ID UTF8String]);
      [self promptUser:&passphrase];
      fprintf(_stream.control.termout, "\r\n");
    }

    while ((rc = libssh2_userauth_publickey_frommemory(_session, user, strlen(user),
						       pub, strlen(pub), // or sizeof_publickey methods
						       priv, strlen(priv),
						       passphrase)) == LIBSSH2_ERROR_EAGAIN)
      ;
    if (rc == 0) {
      [self debugMsg:@"Authentication succeeded."];
      return 1;
    } else {
      [self debugMsg:@"Authentication failed"];
    }
  }
  // Login with publickey failed
  return 0;
}

- (int)timeout_connect:(int)fd serv_addr:(const struct sockaddr *)addr
	      addr_len:(socklen_t)len
	       timeout:(int *)timeoutp
{
  struct timeval tv;
  fd_set fdset;
  int res;
  int valopt = 0;
  socklen_t lon;

  if ([self set_nonblock:_sock] != 0) {
    return -1;
  }

  // Trying to initiate connection as nonblock
  res = connect(_sock, addr, len);
  if (res == 0) {
    return [self unset_nonblock:_sock];
  }
  if (errno != EINPROGRESS) {
    return -1;
  }

  do {
    // Set timeout params
    tv.tv_sec = *timeoutp;
    tv.tv_usec = 0;
    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    // Try to select it to write
    res = select(fd + 1, NULL, &fdset, NULL, &tv);

    if (res != -1 || errno != EINTR) {
      //fprintf(stderr, "Error connecting %d - %s\n", errno, strerror(errno));
      break;
    }
  } while (1);

  switch (res) {
    case 0:
      // Timed out message
      errno = ETIMEDOUT;
      return -1;
    case -1:
      // Select failed
      return -1;
    case 1:
      // Completed or failed. Socket selected for write
      valopt = 0;
      lon = sizeof(valopt);

      lon = sizeof(int);
      if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &valopt, &lon) == -1) {
	return -1;
      }
      if (valopt != 0) {
	errno = valopt;
	return -1;
      }
      return [self unset_nonblock:fd];

    default:
      return -1;
  }
}

- (int)set_nonblock:(int)fd
{
  int arg;

  if ((arg = fcntl(fd, F_GETFL, NULL)) < 0) {
    [self debugMsg:[NSString stringWithFormat:@"Error fcntl(..., F_GETFL) (%s)", strerror(errno)]];
    return -1;
  }
  arg |= O_NONBLOCK;
  if (fcntl(fd, F_SETFL, arg) < 0) {
    [self debugMsg:[NSString stringWithFormat:@"Error fcntl(..., F_GETFL) (%s)", strerror(errno)]];
    return -1;
  }
  return 0;
}

- (int)unset_nonblock:(int)fd
{
  int arg;

  if ((arg = fcntl(fd, F_GETFL, NULL)) < 0) {
    [self debugMsg:[NSString stringWithFormat:@"Error fcntl(..., F_GETFL) (%s)", strerror(errno)]];
    return -1;
  }
  arg &= (~O_NONBLOCK);
  if (fcntl(fd, F_SETFL, arg) < 0) {
    [self debugMsg:[NSString stringWithFormat:@"Error fcntl(..., F_GETFL) (%s)", strerror(errno)]];
    return -1;
  }

  return 0;
}

- (int)ssh_session_start
{
  // This function is responsible to start all the session requirements, like port forwarding, shell, commands...
  // using the ssh library that we want to.

  // It would be responsible to open the channels, and requesting the shells or commands as necessary
  // We just have a couple of things, so maybe we can avoid it.
  // [self ssh_session_setup];

  // It would be responsible to read / write to the channels, shutting down the system and dropping the result of the operation.
  int rc = 0;
  char *errmsg;

  while ((_channel = libssh2_channel_open_session(_session)) == NULL &&
	 libssh2_session_last_error(_session, NULL, NULL, 0) == LIBSSH2_ERROR_EAGAIN) {
    waitsocket(_sock, _session);
  }
  if (_channel == NULL) {
    libssh2_session_last_error(_session, &errmsg, NULL, 0);
    [self debugMsg:[NSString stringWithFormat:@"ssh_session_start: error creating channel: %s", errmsg]];
    return -1;
  }

  [self debugMsg:@"ssh_session_start: channel created"];

  if (_tty_flag) {
    // [self debugMsg:[NSString stringWithFormat:@"Sending env LC_CTYPE = UTF-8"]];    
    // while ((rc = libssh2_channel_setenv(_channel, "LC_CTYPE", "UTF-8")) == LIBSSH2_ERROR_EAGAIN) {
    //   waitsocket(_sock, _session);
    // }

    while ((rc = libssh2_channel_request_pty(_channel, TERM)) == LIBSSH2_ERROR_EAGAIN) {
      waitsocket(_sock, _session);
    }
    if (rc) {
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      [self debugMsg:[NSString stringWithFormat:@"ssh_session_start: error creating channel: %s", errmsg]];
      return -1;
    }
    [self debugMsg:@"ssh_session_start: pty requested"];
    libssh2_channel_request_pty_size(_channel,
				     _stream.sz->ws_col,
				     _stream.sz->ws_row);
  }

  // Send command or start shell
  if (_command != NULL) {
    //  else {
    [self debugMsg:[NSString stringWithFormat:@"sending command: %s", _command]];
    while ((rc = libssh2_channel_exec(_channel, _command)) == LIBSSH2_ERROR_EAGAIN) {
      waitsocket(_sock, _session);
    }
    if (rc != 0) {
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      [self debugMsg:[NSString stringWithFormat:@"ssh_session_start: error exec: %s", errmsg]];
      return -1;
    }
    [self debugMsg:@"exec request accepted"];
  } else {
    [self debugMsg:@"requesting shell"];
    while ((rc = libssh2_channel_shell(_channel)) == LIBSSH2_ERROR_EAGAIN) {
      waitsocket(_sock, _session);
    }
    if (rc) {
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      [self debugMsg:[NSString stringWithFormat:@"ssh_session_start: error shell : %s", errmsg]];
      return -1;
    }
    [self debugMsg:@"shell request accepted"];
  }

  return [self ssh_client_loop];
}

- (int)verify_host:(char *)addr
{
  LIBSSH2_KNOWNHOSTS *kh;
  const char *key;
  size_t key_len;
  int key_type;
  char *type_str;

  if (!(kh = libssh2_knownhost_init(_session))) {
    return -1;
  }

  NSURL *dd = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  NSURL *khURL = [dd URLByAppendingPathComponent:@"known_hosts"];
  const char *khFilePath = [khURL.path UTF8String];

  libssh2_knownhost_readfile(kh, khFilePath, LIBSSH2_KNOWNHOST_FILE_OPENSSH);

  key = libssh2_session_hostkey(_session, &key_len, &key_type);
  int kh_key_type = (key_type == LIBSSH2_HOSTKEY_TYPE_RSA) ? LIBSSH2_KNOWNHOST_KEY_SSHRSA : LIBSSH2_KNOWNHOST_KEY_SSHDSS;
  type_str = (key_type == LIBSSH2_HOSTKEY_TYPE_RSA) ? "RSA" : "DSS";

  const char *hk_hash = libssh2_hostkey_hash(_session, LIBSSH2_HOSTKEY_HASH_SHA1);

  NSData *data = [NSData dataWithBytes:hk_hash length:20];
  
  NSString *fingerprint = [data base64EncodedStringWithOptions:0];

  [self debugMsg:[NSString stringWithFormat:@"Server host key: %s %@ ", type_str, fingerprint]];
  
  int succ = 0;
  if (key) {
    struct libssh2_knownhost *knownHost;
    int check = libssh2_knownhost_checkp(kh, _options.hostname, _options.port, key, key_len,
					 LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW | kh_key_type,
					 &knownHost);
    if (check == LIBSSH2_KNOWNHOST_CHECK_FAILURE) {
      [self errMsg:@"Known host check failed"];
    } else if (check == LIBSSH2_KNOWNHOST_CHECK_NOTFOUND) {
      [self errMsg:[NSString stringWithFormat:@"The authenticity of host %.200s (%s) can't be established.\r\n"
					       "%s key fingerprint is %@",
					      _options.hostname, addr,
					      type_str, fingerprint]];

    } else if (check == LIBSSH2_KNOWNHOST_CHECK_MISMATCH) {
      [self errMsg:[NSString stringWithFormat:@"@@@@@@ REMOTE HOST IDENTIFICATION HAS CHANGED @@@@@@\r\n"
					       "%s host key for %.200s (%s) has changed.\r\n"
					       "This might be due to someone doing something nasty or just a change in the host.\r\n"
					       "Current %s key fingerprint is %@",
					      type_str, _options.hostname, addr,
					      type_str, fingerprint]];
    } else if (check == LIBSSH2_KNOWNHOST_CHECK_MATCH) {
      succ = 1;
    }
  }

  if (!succ && (succ = [self confirm:"Are you sure you want to continue connecting (yes/no)?"])) {
    [self authorize_new_key:key length:key_len type:kh_key_type knownHosts:kh filePath:khFilePath];
  }

  libssh2_knownhost_free(kh);

  return succ;
}

- (int)authorize_new_key:(const char *)key length:(ssize_t)key_len type:(int)key_type knownHosts:(LIBSSH2_KNOWNHOSTS *)kh filePath:(const char *)kh_path
{
  int rc;

  // Add key to the server
  rc = libssh2_knownhost_addc(kh, _options.hostname,
			      NULL, // No hashed addr, no salt
			      key, key_len,
			      NULL, 0,                                                                // No comment
			      LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW | key_type, //LIBSSH2_KNOWNHOST_KEY_SSHRSA,
			      NULL);                                                                  // No pointer to the stored structure
  if (rc < 0) {
    char *errmsg;
    libssh2_session_last_error(_session, &errmsg, NULL, 0);
    [self errMsg:[NSString stringWithFormat:@"Error adding to the known host: %s", errmsg]];
  }

  rc = libssh2_knownhost_writefile(kh, kh_path, LIBSSH2_KNOWNHOST_FILE_OPENSSH);
  if (rc < 0) {
    char *errmsg;
    libssh2_session_last_error(_session, &errmsg, NULL, 0);
    [self errMsg:[NSString stringWithFormat:@"Error writing known host: %s", errmsg]];
  } else {
    [self errMsg:[NSString stringWithFormat:@"Permanently added key for %s to list of known hosts.", _options.hostname]];
  }
  return 1;
}

- (int)confirm:(const char *)prompt
{
  const char *msg, *again = "Please type 'yes' or 'no': ";
  char buffer[BUFSIZ] = "";
  int len = 0;
  int ret = -1;

  for (msg = prompt;; msg = again) {
    fprintf(_stream.err, "%s", msg);
    len = 0;
    do {
      char c;
      ssize_t n;

      if ((n = read(fileno(_stream.control.termin), &c, 1)) <= 0) {
	break;
      }

      if (c == '\n' || c == '\r') {
	fprintf(_stream.err, "\r\n");
	break;
      }
      fprintf(_stream.err, "%c", c);
      buffer[len++] = c;
      buffer[len] = '\0';
    } while (BUFSIZ - 1 - len > 0);

    if ((buffer[0] == '\0') || (buffer[0] == '\n') || strncasecmp(buffer, "no", 2) == 0) {
      ret = 0;
    }
    if (strncasecmp(buffer, "yes", 3) == 0) {
      ret = 1;
    }

    if (ret != -1) {
      return ret;
    }
  }

  return 0;
}

- (int)ssh_client_loop
{

  int numfds = 2;
  struct pollfd pfds[numfds];
  ssize_t rc;
  char inputbuf[BUFSIZ];
  char streambuf[BUFSIZ];
  BOOL mode;

  [self set_nonblock:_sock];

  libssh2_channel_set_blocking(_channel, 0);

  if (_tty_flag) {
    [self set_nonblock:fileno(_stream.in)];
    mode = [self.stream.control rawMode];
    [self.stream.control setRawMode:YES];
  }

  memset(pfds, 0, sizeof(struct pollfd) * numfds);

  pfds[0].fd = _sock;
  pfds[0].events = 0;
  pfds[0].revents = 0;

  pfds[1].fd = fileno(_stream.in);
  pfds[1].events = POLLIN;
  pfds[1].revents = 0;

  // Wait for stream->in or socket while not ready for reading
  do {
    if (!pfds[0].events || pfds[0].revents & (POLLIN)) {
      // Read from socket
      do {
	rc = libssh2_channel_read(_channel, inputbuf, BUFSIZ);
	if (rc > 0) {
	  fwrite(inputbuf, rc, 1, _stream.out);
	  pfds[0].events = 0;
	} else if (rc == LIBSSH2_ERROR_EAGAIN) {
	  // Request the socket for input
	  pfds[0].events = POLLIN;
	}
	memset(inputbuf, 0, BUFSIZ);
      } while (LIBSSH2_ERROR_EAGAIN != rc && rc > 0);
      
      do {
	rc = libssh2_channel_read_stderr(_channel, inputbuf, BUFSIZ);
	if (rc > 0) {
	  fwrite(inputbuf, rc, 1, _stream.err);	  
	  pfds[0].events |= 0;
	} else if (rc == LIBSSH2_ERROR_EAGAIN) {
	  pfds[0].events = POLLIN;
	}

	memset(inputbuf, 0, BUFSIZ);

      } while (LIBSSH2_ERROR_EAGAIN != rc && rc > 0);
    }
    if (rc < 0 && LIBSSH2_ERROR_EAGAIN != rc) {
      [self debugMsg:@"error reading from socket. exiting..."];
      break;
    }

    if (libssh2_channel_eof(_channel)) {
      break;
    }
    
    rc = poll(pfds, numfds, 15000);
    if (-1 == rc) {
      break;
    }

    ssize_t towrite = 0;

    if (!_stream.in || feof(_stream.in)) {
      // Propagate the EOF to the other end
      libssh2_channel_send_eof(_channel);
      break;
    }
    // Input from stream
    if (pfds[1].revents & POLLIN) {
      towrite = fread(streambuf, 1, BUFSIZ, _stream.in);
      rc = 0;
      do {
	rc = libssh2_channel_write(_channel, streambuf + rc, towrite);
	if (rc > 0) {
	  towrite -= rc;
	}
      } while (LIBSSH2_ERROR_EAGAIN != rc && rc > 0 && towrite > 0);
      memset(streambuf, 0, BUFSIZ);
    }
    if (rc < 0 && LIBSSH2_ERROR_EAGAIN != rc) {
      char *errmsg;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      [self debugMsg:[NSString stringWithFormat:@"%s", errmsg]];
      [self debugMsg:@"error writing to socket. exiting..."];
      break;
    }

  } while (1);

  // Free resources and try to cleanup
  [self unset_nonblock:_sock];
  if (_stream.in) {
    [self unset_nonblock:fileno(_stream.in)];
  }

  while ((rc = libssh2_channel_close(_channel)) == LIBSSH2_ERROR_EAGAIN)
    waitsocket(_sock, _session);

  CFRelease(*libssh2_session_abstract(_session));
  libssh2_channel_free(_channel);
  libssh2_session_free(_session);
  _channel = NULL;

  if (_tty_flag) {
    [self.stream.control setRawMode:mode];
  }

  if (rc < 0) {
    return -1;
  }

  return 0;
}

- (void)sigwinch
{
  libssh2_channel_request_pty_size(_channel,
				   _stream.sz->ws_col,
				   _stream.sz->ws_row);
}

- (void)kill
{
  if (_stream.in) {
    fclose(_stream.in);
    _stream.in = NULL;
  }
}

@end
