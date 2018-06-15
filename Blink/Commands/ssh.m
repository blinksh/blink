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

#include <stdio.h>
#include "MCPSession.h"

#include <getopt.h>
#include <libssh/libssh.h>
#include <libssh/callbacks.h>
#include <sys/time.h>

#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"

#include "ios_system/ios_system.h"
#include "ios_error.h"


#define REQUEST_TTY_AUTO 0
#define REQUEST_TTY_NO 1
#define REQUEST_TTY_YES 2
#define REQUEST_TTY_FORCE 3

static const char *__usage_format =
"usage: ssh [options] [user@]hostname [command]\n"
"[-l login_name] [-i identity_file] [-p port]\n"
"[-t request_tty] [-v verbose]\n"
"\n";

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

void __logging_event(int priority, const char *message, const char *message2, void *userdata) {
  printf("%s\n", message);
//  FILE *out = (FILE *)userdata;
//  fprintf(out, "%s\n", message);
}

int __die_msg(const char *msg) {
  printf("%s\n", msg);
  return -1;
}

int __usage() {
  return __die_msg(__usage_format);
}

void __debug_msg(const char *msg) {
  //if (_debug) {
  printf("ssh2:DEBUG:%s\n", msg);
  //}
}

int __opts(session_options *options, int argc, char **argv)
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
        options->port = (unsigned int)strtol(optarg, &ep, 10);
        if (optarg == ep || *ep != '\0' || options->port > 65536) {
          return __die_msg("Wrong port value provided.");
        }
        break;
      case 'h':
        options->disableHostKeyCheck = true;
        break;
      case 'v':
        options->verbosity = SSH_LOG_PROTOCOL;
        break;
      case 'i':
        options->identity_file = optarg;
        break;
      case 't':
        options->request_tty = REQUEST_TTY_FORCE;
        break;
      case 'l':
        options->user = optarg;
        break;
      default:
        optind = 0;
        return __usage();
    }
  }
  
  if (argc - optind < 1) {
    return __usage();
  }
  
  BKHosts *savedHost;
  NSArray *userAtHost = [[NSString stringWithFormat:@"%s", argv[optind++]]
                         componentsSeparatedByString:@"@"];
  char **command_args = &argv[optind];
  int num_command_args = argc - optind;
  
  if ([userAtHost count] < 2) {
    options->hostname = [userAtHost[0] UTF8String];
  } else {
    options->user = [userAtHost[0] UTF8String];
    options->hostname = [userAtHost[1] UTF8String];
  }
  
  if ((savedHost = [BKHosts withHost:[NSString stringWithFormat:@"%s", options->hostname]])) {
    options->hostname = savedHost.hostName ? [savedHost.hostName UTF8String] : options->hostname;
    options->port = options->port ? options->port : [savedHost.port intValue];
    if (!options->user && [savedHost.user length]) {
      options->user = [savedHost.user UTF8String];
    }
    options->identity_file = options->identity_file ? options->identity_file : [savedHost.key UTF8String];
    options->password = savedHost.password ? [savedHost.password UTF8String] : NULL;
  }
  
  if (num_command_args) {
    NSString *command = [NSString stringWithFormat:@"%s", command_args[0]];
    
    for (int i = 1; i < num_command_args; i++) {
      NSString *arg = [NSString stringWithFormat:@" %s", command_args[i]];
      command = [command stringByAppendingString:arg];
    }
    options->command = [command UTF8String];
  }
  
  if (ios_isatty(fileno(thread_stdout))) {
    options->request_tty = REQUEST_TTY_YES;
  }
  
  return 0;
}

int __set_session_options(ssh_session session, session_options options) {
  //ssh_callbacks_init(&cb);
  //ssh_set_callbacks(_session, &cb);
  //  ssh_set_log_level(100);
  if (!ssh_is_connected(session)) {
    __debug_msg("Yo!");
  }
  
  if (ssh_options_set(session, SSH_OPTIONS_COMPRESSION, "yes") < 0) {
    __debug_msg("can't set compression");
  }
  if (ssh_options_set(session, SSH_OPTIONS_HOST, options.hostname) < 0) {
    return __die_msg("Error setting Host");
  }
  
  if (ssh_options_set(session, SSH_OPTIONS_USER, options.user) < 0) {
    return __die_msg("Error setting user");
  }
  
  if (options.port && ssh_options_set(session, SSH_OPTIONS_PORT, &options.port) < 0) {
    return __die_msg("Error setting port");
  }
  
  ssh_options_set(session, SSH_OPTIONS_SSH_DIR, "./");
  
  if (options.verbosity) {
    //    ssh_options_set(_session, SSH_OPTIONS_LOG_VERBOSITY, &_options.verbosity);
    ssh_set_log_callback(__logging_event);
    ssh_set_log_userdata(thread_stdout);
    ssh_set_log_level(options.verbosity);
  }
  
  return 0;
}

int __verify_known_host() {
  // TODO: Creating the file where we want, modifying entries, etc...
  return 1;
}

NSArray * __get_identities(session_options options) {
  // Obtain valid auths that will be tried for the connection
  NSMutableArray *identities = [[NSMutableArray alloc] init];
  BKPubKey *pk;
  
  if (options.identity_file) {
    if ((pk = [BKPubKey withID:[NSString stringWithUTF8String:options.identity_file]]) != nil) {
      [identities addObject:pk];
    }
  }
  
  if ((pk = [BKPubKey withID:@"id_rsa"]) != nil) {
    [identities addObject:pk];
  }
  
  return identities;
}

ssize_t __prompt_user(char **resp) {
  //char *line=NULL;
  size_t size = 0;
  ssize_t sz = 0;
  
  FILE *termin = thread_stdin;
  if ((sz = getdelim(resp, &size, '\n', termin)) == -1) {
    return -1;
  } else {
    if ((*resp)[sz - 1] == '\n') {
      (*resp)[--sz] = '\0';
    }
    return sz;
  }
}

ssize_t __prompt(const char *prompt, char *buf) {
  printf("%s", prompt);
  return __prompt_user(&buf);
}

int __auth_interactive(ssh_session session, const char *password) {
  int err = ssh_userauth_kbdint(session, NULL, NULL);
  while (err == SSH_AUTH_INFO) {
    const char *instruction;
    const char *name;
    
    int i, n;
    
    name = ssh_userauth_kbdint_getname(session);
    instruction = ssh_userauth_kbdint_getinstruction(session);
    n = ssh_userauth_kbdint_getnprompts(session);
    
    if (name && strlen(name) > 0) {
      printf("%s\n", name);
    }
    
    if (instruction && strlen(instruction) > 0) {
      printf("%s\n", instruction);
    }
    
    for (i = 0; i < n; i++) {
      const char *answer;
      const char *prompt;
      char echo;
      char *buffer = NULL;
      
      prompt = ssh_userauth_kbdint_getprompt(session, i, &echo);
      if (prompt == NULL) {
        break;
      }
      
      if (echo) {
        printf("%s", prompt);
        __prompt_user(&buffer);
        
        if (ssh_userauth_kbdint_setanswer(session, i, buffer) < 0) {
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
          
          printf("%s", prompt);
          if (__prompt_user(&buffer) < 0) {
            return SSH_AUTH_ERROR;
          }
          // if (ssh_getpass(prompt, buffer, sizeof(buffer), 0, 0) < 0) {
          //   return SSH_AUTH_ERROR;
          // }
          answer = buffer;
        }
        err = ssh_userauth_kbdint_setanswer(session, i, answer);
        if (buffer) {
          memset(buffer, 0, sizeof(*buffer));
          free(buffer);
        }
        if (err < 0) {
          return SSH_AUTH_ERROR;
        }
      }
    }
    err = ssh_userauth_kbdint(session,NULL,NULL);
  }
  
  return err;
}


int __auth_callback(const char *prompt, char *buf, size_t len,
                        int echo, int verify, void *userdata)
{
  return (int)__prompt(prompt, buf);
}

int __auth_public_key(ssh_session session, session_options options) {
  // Try all the identities until finding a successful one, and return
  NSArray *identities = __get_identities(options);
  
  for (BKPubKey *pk in identities) {
    // Import the private key and try it
    int rc;
    ssh_key privkey;
    const char *ckey = [pk.privateKey UTF8String];
    __debug_msg([NSString stringWithFormat:@"Attempting authentication with key: %@", pk.ID].UTF8String);
    
    // TODO: Request passphrase through interface
    // TODO: The agent can then store decrypted ssh_key objects, and free them once done.
    // TODO: The agent should be the one responsible to decrypt the key
    if (ssh_pki_import_privkey_base64(ckey, NULL, &__auth_callback,
                                      NULL, &privkey) == SSH_ERROR) {
      __debug_msg([NSString stringWithFormat:@"Error importing key %@ - %s", pk.ID, ssh_get_error(session)].UTF8String);
      continue;
    }
    
    rc = ssh_userauth_publickey(session, options.user, privkey);
    if (rc == SSH_AUTH_SUCCESS) {
      return rc;
    }
  }
  
  return SSH_AUTH_DENIED;
}


int __authenticate(ssh_session session, session_options options) {
  int rc;
  int method;
  char *banner;
  
  rc = ssh_userauth_none(session, NULL);
  if (rc == SSH_AUTH_ERROR) {
    return rc;
  }
  
  method = ssh_userauth_list(session, NULL);
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
      rc = __auth_public_key(session, options); //ssh_userauth_publickey_auto(_session, NULL, NULL);
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
      rc = __auth_interactive(session, NULL);
      if (rc == SSH_AUTH_ERROR) {
        //error(session);
        return rc;
      } else if (rc == SSH_AUTH_SUCCESS) {
        break;
      }
    }
    
    char *password = NULL;
    printf("%s", "Password: ");
    if (__prompt_user(&password) < 0) {
      return SSH_AUTH_ERROR;
    }
    
    // Try to authenticate with password
    if (method & SSH_AUTH_METHOD_PASSWORD) {
      rc = ssh_userauth_password(session, NULL, password);
      if (rc == SSH_AUTH_ERROR) {
        //error(session);
        return rc;
      } else if (rc == SSH_AUTH_SUCCESS) {
        break;
      }
    }
    memset(password, 0, sizeof(*password));
  }
  
  banner = ssh_get_issue_banner(session);
  if (banner) {
    printf("%s\n", banner);
    ssh_string_free_char(banner);
  }
  
  return rc;
}

void __refresh_size(ssh_channel channel) {
  MCPSession *mcp = (__bridge MCPSession *)thread_context;
  TermDevice *device = mcp.device;
  ssh_channel_change_pty_size(channel,
                              device->win.ws_col,
                              device->win.ws_row);
}

void __loop(ssh_session session, ssh_channel channel) {
  ssh_connector connector_in, connector_out, connector_err;
  ssh_event event = ssh_event_new();
  
  ssh_set_blocking(session, 0);
  ssh_channel_set_blocking(channel, 0);
  // stdin
  connector_in = ssh_connector_new(session);
  ssh_connector_set_out_channel(connector_in, channel, SSH_CONNECTOR_STDOUT);
  ssh_connector_set_in_fd(connector_in, fileno(thread_stdin));
  ssh_event_add_connector(event, connector_in);
  
  // stdout
  connector_out = ssh_connector_new(session);
  ssh_connector_set_out_fd(connector_out, fileno(thread_stdout));
  ssh_connector_set_in_channel(connector_out, channel, SSH_CONNECTOR_STDOUT);
  ssh_event_add_connector(event, connector_out);
  
  // stderr
  connector_err = ssh_connector_new(session);
  ssh_connector_set_out_fd(connector_err, fileno(thread_stdout));
  ssh_connector_set_in_channel(connector_err, channel, SSH_CONNECTOR_STDERR);
  ssh_event_add_connector(event, connector_err);
  
  while(ssh_channel_is_open(channel) && !ssh_channel_is_eof(channel)){
    //    if(signal_delayed)
    //      sizechanged();
    ssh_event_dopoll(event, 60000);
  }
  ssh_event_remove_connector(event, connector_in);
  ssh_event_remove_connector(event, connector_out);
  ssh_event_remove_connector(event, connector_err);
  
  ssh_connector_free(connector_in);
  ssh_connector_free(connector_out);
  ssh_connector_free(connector_err);
  
  ssh_event_free(event);
  ssh_channel_free(channel);
}

int __shell(ssh_session session, session_options options) {
  ssh_channel channel = ssh_channel_new(session);
  int rc = ssh_channel_open_session(channel);
  if (rc != SSH_OK) {
    ssh_channel_free(channel);
    return __die_msg("Error opening channel");
  }
  // TODO: Interactive vs non-interactive, but still requesting a shell?
  ssh_channel_request_pty(channel);
  __refresh_size(channel);
  
  
  if (options.command) {
    rc = ssh_channel_request_exec(channel, options.command);
  } else {
    rc = ssh_channel_request_shell(channel);
  }
  
  if (rc != SSH_OK) {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return __die_msg("Error requesting shell");
  }
  
  __loop(session, channel);
  return 1;
}

int __exec(ssh_session session, session_options options) {
  ssh_channel channel;
  int rc;
  char buffer[256];
  int nbytes;
  channel = ssh_channel_new(session);
  if (channel == NULL)
    return SSH_ERROR;
  rc = ssh_channel_open_session(channel);
  if (rc != SSH_OK)
  {
    ssh_channel_free(channel);
    return rc;
  }
  rc = ssh_channel_request_exec(channel, options.command);
  if (rc != SSH_OK)
  {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return rc;
  }
  nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  while (nbytes > 0)
  {
    if (write(1, buffer, nbytes) != (unsigned int) nbytes)
    {
      ssh_channel_close(channel);
      ssh_channel_free(channel);
      return SSH_ERROR;
    }
    nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  }
  
  if (nbytes < 0)
  {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return SSH_ERROR;
  }
  ssh_channel_send_eof(channel);
  ssh_channel_close(channel);
  ssh_channel_free(channel);
  return SSH_OK;
}

int ssh_main(int argc, char *argv[]) {
  
  session_options options = {};
  ssh_session session = ssh_new();
  
  
  int rc = __opts(&options, argc, argv);
  if (rc < 0) {
    ssh_free(session);
    return rc;
  }
  
  rc = ssh_options_getopt(session, &argc, argv);
  if (rc < 0) {
    ssh_free(session);
    return rc;
  }
  
  __set_session_options(session, options);
  
  rc = ssh_options_parse_config(session, NULL);
  if (rc < 0) {
    ssh_free(session);
    return rc;
  }
  
  if (!__verify_known_host()) {
    ssh_free(session);
    return __die_msg("Host key verification failed");
  }
  
  rc = ssh_connect(session);
  if (rc != SSH_OK) {
    ssh_free(session);
    // TODO: free on die? how were we doing this before? How about on cleanup of the object?
    return __die_msg("Error connecting to HOST");
  }
  
  ssh_userauth_none(session, NULL);
  char *banner = ssh_get_issue_banner(session);
  if (banner) {
    printf("%s\n", banner);
    free(banner);
  }
  
  if (__authenticate(session, options) < 0) {
    return __die_msg("Authentication error");
  }
  MCPSession *mcp = (__bridge MCPSession *)thread_context;
  
  if (options.request_tty) {
    [mcp.device setRawMode:YES];
    rc = __shell(session, options);
    [mcp.device setRawMode:NO];
  } else {
    rc = __exec(session, options);
  }
  ssh_free(session);
  
  return rc;
}

//TODO:

//- (void)sigwinch
//{
//  // TODO: Fails when changing apps, etc... if there is no app yet.
//  [self refreshSize];
//}

