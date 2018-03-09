#include <getopt.h>
#include <libssh/libssh.h>
#include <libssh/callbacks.h>
#include <sys/time.h>

#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"
#import "SSHSession2.h"


#define REQUEST_TTY_AUTO 0
#define REQUEST_TTY_NO 1
#define REQUEST_TTY_YES 2
#define REQUEST_TTY_FORCE 3

static const char *usage_format =
"usage: ssh [options] [user@]hostname [command]\r\n"
"[-l login_name] [-i identity_file] [-p port]\r\n"
"[-t request_tty] [-v verbose]\r\n"
"\r\n";

typedef struct {
  int verbosity;
  int port;
  const char *hostname;
  const char *user;
  int request_tty;
  const char *identity_file;
  const char *password;
  BOOL disableHostKeyCheck;
  const char *command;
} session_options;

@interface SSHSession2 ()
@end

void loggingEvent(ssh_session session, int priority, const char *message, void *userdata)
{
  FILE *out = (FILE *)userdata;
  fprintf(out, "%s\r\n", message);
}

@implementation SSHSession2 {
  session_options _options;
  ssh_session _session;
  ssh_channel _channel;
}

- (int)usage
{
  return [self dieMsg:[NSString stringWithFormat:@"%s", usage_format]];
}

- (int)main:(int)argc argv:(char **)argv
{
  if ([self opts:argc argv:argv] < 0) {
    return [self usage];
  }
  
  [self client];
  
  return 0;
}

- (int)opts:(int)argc argv:(char **)argv
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
      _options.verbosity = SSH_LOG_PROTOCOL;
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
  
  BKHosts *savedHost;
  NSArray *userAtHost = [[NSString stringWithFormat:@"%s", argv[optind++]]
                         componentsSeparatedByString:@"@"];
  char **command_args = &argv[optind];
  int num_command_args = argc - optind;
  
  if ([userAtHost count] < 2) {
    _options.hostname = [userAtHost[0] UTF8String];
  } else {
    _options.user = [userAtHost[0] UTF8String];
    _options.hostname = [userAtHost[1] UTF8String];
  }
  
  if ((savedHost = [BKHosts withHost:[NSString stringWithFormat:@"%s", _options.hostname]])) {
    _options.hostname = savedHost.hostName ? [savedHost.hostName UTF8String] : _options.hostname;
    _options.port = _options.port ? _options.port : [savedHost.port intValue];
    if (!_options.user && [savedHost.user length]) {
      _options.user = [savedHost.user UTF8String];
    }
    _options.identity_file = _options.identity_file ? _options.identity_file : [savedHost.key UTF8String];
    _options.password = savedHost.password ? [savedHost.password UTF8String] : NULL;
  }
  
  if (num_command_args) {
    NSString *command = [NSString stringWithFormat:@"%s", command_args[0]];
    
    for (int i = 1; i < num_command_args; i++) {
      NSString *arg = [NSString stringWithFormat:@" %s", command_args[i]];
      command = [command stringByAppendingString:arg];
    }
    _options.command = [command UTF8String];
  } else {
    _options.request_tty = REQUEST_TTY_YES;
  }
  
  return 0;
}

- (int)client
{
  _session = ssh_new();
  
  [self setSessionOptions];
  
  if (![self verifyKnownHost]) {
    return [self dieMsg:@"Host key verification failed"];
  }
  
  int rc = ssh_connect(_session);
  if (rc != SSH_OK) {
    // TODO: free on die? how were we doing this before? How about on cleanup of the object?
    return [self dieMsg:@"Error connecting to HOST"];
  }
  
  ssh_userauth_none(_session, NULL);
  char *banner = ssh_get_issue_banner(_session);
  if (banner) {
    fprintf(self.stream.out, "%s\r\n", banner);
    free(banner);
  }
  
  if ([self authenticate] < 0) {
    return [self dieMsg:@"Authentication error"];
  }
  
  if (_options.request_tty) {
    [self shell];
  } else {
    // exec
    
  }
  return 0;
}

- (int)setSessionOptions
{
  //ssh_callbacks_init(&cb);
  //ssh_set_callbacks(_session, &cb);
  //  ssh_set_log_level(100);
  if (!ssh_is_connected(_session)) {
    [self debugMsg:@"Yo!"];
  }
  
  if (ssh_options_set(_session, SSH_OPTIONS_HOST, _options.hostname) < 0) {
    return [self dieMsg:@"Error setting Host"];
  }
  
  if (ssh_options_set(_session, SSH_OPTIONS_USER, _options.user) < 0) {
    return [self dieMsg:@"Error setting user"];
  }
  
  if (_options.port && ssh_options_set(_session, SSH_OPTIONS_PORT, &_options.port) < 0) {
    return [self dieMsg:@"Error setting port"];
  }
  
  ssh_options_set(_session, SSH_OPTIONS_SSH_DIR, "./");
  
  if (_options.verbosity) {
    //    ssh_options_set(_session, SSH_OPTIONS_LOG_VERBOSITY, &_options.verbosity);
    ssh_set_log_callback(loggingEvent);
    ssh_set_log_userdata(self.stream.out);
    ssh_set_log_level(_options.verbosity);
  }
  
  return 0;
}

- (int)verifyKnownHost
{
  // TODO: Creating the file where we want, modifying entries, etc...
  return 1;
}

- (int)authenticate
{
  int rc;
  int method;
  char *banner;
  
  rc = ssh_userauth_none(_session, NULL);
  if (rc == SSH_AUTH_ERROR) {
    return rc;
  }
  
  method = ssh_userauth_list(_session, NULL);
  while (rc != SSH_AUTH_SUCCESS) {
    // Disabled for now, as we are compiling libssh without gssapi support.
    // if (method & SSH_AUTH_METHOD_GSSAPI_MIC){
    //   rc = ssh_userauth_gssapi(session);
    //   if(rc == SSH_AUTH_ERROR) {
    //   error(session);
    //   return rc;
    //   } else if (rc == SSH_AUTH_SUCCESS) {
    //   break;
    //   }
    // }
    
    // Try to authenticate with public key first
    if (method & SSH_AUTH_METHOD_PUBLICKEY) {
      rc = [self authPublicKey]; //ssh_userauth_publickey_auto(_session, NULL, NULL);
      if (rc == SSH_AUTH_ERROR) {
        // TODO: Print Error message
        // [self sshError:@"Authentication failed"] - wrapped within a function to use ssh_error_message
        //error(session);
        return rc;
      } else if (rc == SSH_AUTH_SUCCESS) {
        break;
      }
    }
    
    // Try to authenticate with keyboard interactive
    if (method & SSH_AUTH_METHOD_INTERACTIVE) {
      // TODO: Pass initial password from default
      rc = [self authInteractive:NULL];
      if (rc == SSH_AUTH_ERROR) {
        //error(session);
        return rc;
      } else if (rc == SSH_AUTH_SUCCESS) {
        break;
      }
    }
    
    char *password = NULL;
    fprintf(self.stream.out, "Password: ");
    if ([self promptUser:&password] < 0) {
      return SSH_AUTH_ERROR;
    }
    
    // Try to authenticate with password
    if (method & SSH_AUTH_METHOD_PASSWORD) {
      rc = ssh_userauth_password(_session, NULL, password);
      if (rc == SSH_AUTH_ERROR) {
        //error(session);
        return rc;
      } else if (rc == SSH_AUTH_SUCCESS) {
        break;
      }
    }
    memset(password, 0, sizeof(*password));
  }
  
  banner = ssh_get_issue_banner(_session);
  if (banner) {
    fprintf(self.stream.out, "%s\r\n", banner);
    ssh_string_free_char(banner);
  }
  
  return rc;
}

- (int)authPublicKey
{
  // Try all the identities until finding a successful one, and return
  NSArray *identities = [self getIdentities];
  
  for (BKPubKey *pk in identities) {
    // Import the private key and try it
    int rc;
    ssh_key privkey;
    const char *ckey = [pk.privateKey UTF8String];
    [self debugMsg:[NSString stringWithFormat:@"Attempting authentication with key: %@", pk.ID]];
    
    // TODO: Request passphrase through interface
    // TODO: The agent can then store decrypted ssh_key objects, and free them once done.
    // TODO: The agent should be the one responsible to decrypt the key
    if (ssh_pki_import_privkey_base64(ckey, NULL, &authCallback,
                                      (__bridge void *)(self), &privkey) == SSH_ERROR) {
      [self debugMsg:[NSString stringWithFormat:@"Error importing key %@ - %s", pk.ID, ssh_get_error(_session)]];
      continue;
    }
    
    rc = ssh_userauth_publickey(_session, _options.user, privkey);
    if (rc == SSH_AUTH_SUCCESS) {
      return rc;
    }
  }
  
  return SSH_AUTH_DENIED;
}

- (ssize_t)prompt:(const char *)prompt output:(char *)buf
{
  fprintf(self.stream.out, "%s", prompt);
  return [self promptUser:&buf];
}

static int authCallback(const char *prompt, char *buf, size_t len,
                        int echo, int verify, void *userdata)
{
  SSHSession2 *s = (__bridge SSHSession2 *)(userdata);
  return (int)[s prompt:prompt output:buf];
}

- (NSArray *)getIdentities
{
  // Obtain valid auths that will be tried for the connection
  NSMutableArray *identities = [[NSMutableArray alloc] init];
  BKPubKey *pk;
  
  if (_options.identity_file) {
    if ((pk = [BKPubKey withID:[NSString stringWithUTF8String:_options.identity_file]]) != nil) {
      [identities addObject:pk];
    }
  }
  
  if ((pk = [BKPubKey withID:@"id_rsa"]) != nil) {
    [identities addObject:pk];
  }
  
  return identities;
}


- (int)authInteractive:(const char *)password
{
  int err;
  FILE *out = self.stream.out;
  
  err = ssh_userauth_kbdint(_session, NULL, NULL);
  while (err == SSH_AUTH_INFO) {
    const char *instruction;
    const char *name;
    
    int i, n;
    
    name = ssh_userauth_kbdint_getname(_session);
    instruction = ssh_userauth_kbdint_getinstruction(_session);
    n = ssh_userauth_kbdint_getnprompts(_session);
    
    if (name && strlen(name) > 0) {
      fprintf(out, "%s\r\n", name);
    }
    
    if (instruction && strlen(instruction) > 0) {
      fprintf(out, "%s\r\n", instruction);
    }
    
    for (i = 0; i < n; i++) {
      const char *answer;
      const char *prompt;
      char echo;
      char *buffer = NULL;
      
      prompt = ssh_userauth_kbdint_getprompt(_session, i, &echo);
      if (prompt == NULL) {
        break;
      }
      
      if (echo) {
        fprintf(out, "%s", prompt);
        [self promptUser: &buffer];
        
        if (ssh_userauth_kbdint_setanswer(_session, i, buffer) < 0) {
          return SSH_AUTH_ERROR;
        }
        if (buffer) {
          memset(buffer, 0, strlen(buffer));
          free(buffer);
        }
      } else {
        if (password && strstr(prompt, "Password:")) {
          answer = password;
        } else {
          //buffer[0] = '\0';
          
          fprintf(out, "%s", prompt);
          if ([self promptUser:&buffer] < 0) {
            return SSH_AUTH_ERROR;
          }
          // if (ssh_getpass(prompt, buffer, sizeof(buffer), 0, 0) < 0) {
          //   return SSH_AUTH_ERROR;
          // }
          answer = buffer;
        }
        err = ssh_userauth_kbdint_setanswer(_session, i, answer);
        if (buffer) {
          memset(buffer, 0, sizeof(*buffer));
          free(buffer);
        }
        if (err < 0) {
          return SSH_AUTH_ERROR;
        }
      }
    }
    err=ssh_userauth_kbdint(_session,NULL,NULL);
  }
  
  return err;
}

- (ssize_t)promptUser:(char **)resp
{
  //char *line=NULL;
  size_t size = 0;
  ssize_t sz = 0;
  
  FILE *termin = self.stream.in;
  if ((sz = getdelim(resp, &size, '\r', termin)) == -1) {
    return -1;
  } else {
    if ((*resp)[sz - 1] == '\r') {
      (*resp)[--sz] = '\0';
    }
    return sz;
  }
}

- (int)shell
{
  _channel = ssh_channel_new(_session);
  
  if (ssh_channel_open_session(_channel)) {
    return [self dieMsg:@"Error opening channel"];
  }
  // TODO: Interactive vs non-interactive, but still requesting a shell?
  ssh_channel_request_pty(_channel);
  [self refreshSize];
  
  if (ssh_channel_request_shell(_channel)) {
    return [self dieMsg:@"Error requesting shell"];
  }
  
  [self loop];
  return 1;
}

- (void)refreshSize {
  ssh_channel_change_pty_size(_channel,
                              self.device.sz->ws_col,
                              self.device.sz->ws_row);
}

- (void)processUserHostSettings:(NSString *)userhost
{
  BKHosts *savedHost;
  
  NSArray *chunks = [userhost componentsSeparatedByString:@"@"];
  NSString *hostname, *user;
  
  if ([chunks count] < 2) {
    hostname = chunks[0];
    _options.hostname = [hostname UTF8String];
  } else {
    user = chunks[0];
    hostname = chunks[1];
    _options.hostname = [hostname UTF8String];
    _options.user = [user UTF8String];
  }
  
  if (!(savedHost = [BKHosts withHost:hostname])) {
    return;
  }
  
  _options.hostname = savedHost.hostName ? [savedHost.hostName UTF8String] : _options.hostname;
  _options.port = _options.port ? _options.port : [savedHost.port intValue];
  
  if (!_options.user && [savedHost.user length]) {
    _options.user = [savedHost.user UTF8String];
  }
  _options.identity_file = _options.identity_file ? _options.identity_file : [savedHost.key UTF8String];
  _options.password = savedHost.password ? [savedHost.password UTF8String] : NULL;
  
  if (!_options.user) {
    // If no user provided, use the default
    _options.user = [[BKDefaults defaultUserName] UTF8String];
  }
}

- (void)loop
{
  ssh_connector connector_in, connector_out, connector_err;
  ssh_event event = ssh_event_new();
  
  ssh_set_blocking(_session, 0);
  ssh_channel_set_blocking(_channel, 0);
  /* stdin */
  connector_in = ssh_connector_new(_session);
  ssh_connector_set_out_channel(connector_in, _channel, SSH_CONNECTOR_STDOUT);
  ssh_connector_set_in_fd(connector_in, fileno(self.stream.in));
  ssh_event_add_connector(event, connector_in);
  
  /* stdout */
  connector_out = ssh_connector_new(_session);
  ssh_connector_set_out_fd(connector_out, fileno(self.stream.out));
  ssh_connector_set_in_channel(connector_out, _channel, SSH_CONNECTOR_STDOUT);
  ssh_event_add_connector(event, connector_out);
  
  /* stderr */
  //  connector_err = ssh_connector_new(_session);
  //  ssh_connector_set_out_fd(connector_err, fileno(_stream.err));
  //  ssh_connector_set_in_channel(connector_err, _channel, SSH_CONNECTOR_STDERR);
  //  ssh_event_add_connector(event, connector_err);
  
  while(ssh_channel_is_open(_channel)){
    //    if(signal_delayed)
    //      sizechanged();
    ssh_event_dopoll(event, 60000);
  }
  ssh_event_remove_connector(event, connector_in);
  ssh_event_remove_connector(event, connector_out);
  //ssh_event_remove_connector(event, connector_err);
  
  ssh_connector_free(connector_in);
  ssh_connector_free(connector_out);
  //ssh_connector_free(connector_err);
  
  ssh_event_free(event);
  ssh_channel_free(_channel);
}

- (int)dieMsg:(NSString *)msg
{
  fprintf(self.stream.out, "%s\r\n", [msg UTF8String]);
  return -1;
}

- (void)errMsg:(NSString *)msg
{
  fprintf(self.stream.err, "%s\r\n", [msg UTF8String]);
}

- (void)debugMsg:(NSString *)msg
{
  //if (_debug) {
  fprintf(self.stream.out, "SSHSession:DEBUG:%s\r\n", [msg UTF8String]);
  //}
}

- (void)sigwinch
{
  // TODO: Fails when changing apps, etc... if there is no app yet.
  [self refreshSize];
}

@end
