# Version 13.5.2

- Fixed 3f menu on new OS versions. #1049
- Updated JetBrainsMono to v2.3.
- Allow to remap < and > on German keyboards. 

# Version 13.5.1

- Fixed ctrl-space mapping. #782, #942, #727
- Fixed undefined text in terminal. #1017

# Version 13.5

- Rendering speed improvements
- Update wide char table to Unicode 13.0.0 release
- Fixed multiline copy. #961
- Removed duplicate share menu on selection
- Request authorization before scheduling notification
- Updated libssh to 0.9.4
  - Fixed CVE-2020-1730 (Possible DoS in client when handling AES-CTR keys with OpenSSL)
  - Added diffie-hellman-group14-sha256
  - Fixed several possible memory leaks

# Version 13.4

- Fixed selection
- Tmux/mosh/vim scroll

# Version 13.3

## Changes in Build 219

- Fixed Autolock bypass.

## Changes in Build 217

- Added support for OSC 9,777 for notification.
- Added support for OSC 10,11 color read operations.
- Fixed color palette refresh. #540

## Changes in Build 215

- Removed temporary output in mosh.
- Added option to bind `~` and `±` keys. #932
- Updated JetBrains Mono font to v1.0.2. #927
- Allow to map `|` with custom presses. #928
- Added option to disable third-party keyboards.

Special thanks to @arkku for PR

# Version 13.2

## Changes in Build 206

- Fixed alt+[non letter] on software kbs. #920

## Changes in Build 204

- Improved software kbs. #901, #915
- Fixed crash in appearance config view.
- Added JetBrains Mono font.
- Fixed unmapped CapsLock.

## Changes in Build 202

- Improved safe layout for devices with notch. #911
- Fixed software kb detection on iPhones.
- Added Discord to support and feedback screens.
- Prevent alt-tab to loose focus.

## Changes in Build 201

- Allow to map back `§` with custom presses.
- Basic support for Korean language. #909

## Changes in Build 200

- New auto lock based on LocalAuthentication.framework
- Guard private key copy/delete with LocalAuth
- Fixed disappearing config view
- New separate font size setting for external displays
- Improved stuck key view on external displays. #906

# Version 13.1

This is a very important release with just a single change. We had to rewrite
all our legendary keyboard code so that features like caps as control could
continue working on iOS 13. If you use a keyboard in a different language,
specially with accents and special characters, we need your help more than ever.
Here is what’s new:

- Caps as Control or escape is back!
- You can now also define what individual modifier keys do on presses. Want to
  press Caps and send escape? No problem!
- You can separate left and right modifiers. And even define key ups and downs.
- Shortcuts can now also be configured and redefined.
- You can now also assign a different key to Escape.
- You can also assign Ctrl-Space (emacs & tmux mark) to a different sequence
  within Blink.
- Accents are now considered too for specific sequences so if you have an
  international keyboard like French, Danish, etc... let us know how things are
  looking like.

## Changes in Build 195

- Updated libssh to 0.9.3
- Fixed import of ECDSA keys. #872
- Improved voice input.
- Added share option to selection menu. #758, #894, #743
- Guard stuck key view. #887
- Simplify keyboard config UI
- Tune IME placement
- Added last tab, prev/next tab cycle commands. #641
- Added mosh UDP port range support. #881
- Added reset button to kb config.
- Fixed kb accessory view on phones.
- Fixed arrows with modifiers. #886
- Profile file env vars support escapes.
- Add support for MOSH_ESCAPE_KEY. #875
- Fix for ctrl sequences on dvorak kb
- Bring back 3f menu
- Selection doesn't resign software KB
- Shortcut for config is working again
- Proper theme for software KB
- Allow to capture `°` in shortcuts

# Version 13.0

## Changes in Build 138

- Fixed dark theme for hosts
- Fixed selection
- Autorepeat for arrow keys, esc, tab on software kb
- Updated help for new gestures

- Fixed extanl monitor support
- 3 finger control panel
- iPhone 11 models support
- Dark theme support
- New Smarter keys
- Multiple windows support
- 2 finger mouse wheel terminal reports (tmux, emacs, vim)
- Native scroll
- Updated FiraCode 2.0

# Version 12.9

## Changes in Build 108

- Fixed Pragmata Pro (without ligatures) mu. #705
- Fixed row with image cleanup
- Fixed username from ./ssh/config. #379
- Added external screen overscan compensation modes. #708
- Speedup initial app start after new install. #734
- Updated mosh v1.3.2 (master). #609
- Updated libssh v0.9.0. #717, #711, #709, #616

Many thanks to @jakejarvis, @axot, @kkk669, @coppercash, @dmd, @pablopunk,
@hpetersen and @andrius.

# Version 12.8

## Changes in Build 97

- Fixed system wide font selection. #701, 704
- Added configuration views for x-callback-url.
- New font size measure algorithm. #702, #668
- Added Iosevka font.
- Added `config delete-activities all` command. #700
- Fixed missing host in siri shortcuts. #592
- Added xcall command for x-callback-url protocol.
- Added blinkshell://run?cmd=<> url handling.

Huge thanks to @toph-allen, @Kamik423, @comfortablynick, @Harwood and
@maurizio-manuguerra-mq.

# Version 12.7

## Changes in Build 87

- Updated libssh to 0.8.7
  - Added Encrypt-then-MAC support. #616
  - Fixed Ed25519 keys export. #681
- Updated openssl to v1.0.2r.
- Added brave and opera browsers support for opening urls.
- Fix crashes during closing windows. #602

Huge thanks to @holzschu, @TypedLambda, @botanicus, @vorband and @derekbelrose.

# Version 12.5

## Changes in Build 83

- New ifconfig and openurl commands.
- Fixed adding ecdsa keys to ssh-agent with ssh-add command. #681
- New openurl command and open selected links honors BROWSER env var
  (googlechrome and firefox). #529
- New load env vars from .blink/profile file.
- New auth with keys from agent. #685
- Fixed icloud hosts ports sync. #333

Huge thanks to @holzschu, @treyharris, @TypedLambda and @lohitv9.

# Version 12.4

## Changes in Build 81

- Fixed ssh use TERM env var for TTY. #604
- Fixed disabled kbd interactive auth method. #667
- Updated libssh to 0.8.6.
- Fixed images display over ssh. #663
- New cmd+shift+left/right shortcuts to switch terminals. #419, #496
- Fixed umlaut with capitals. #657
- Improved ssh pubkey authentication.
- Improved host verification. #648.
- Fixed command pipes. #637.
- Fixed geo command output, so it can be redirected. #626
- Clarify mosh configuration UI. #106
- Increased layout lock icon tappable area.

Huge thanks to @holzschu, @cjay, @jjarava, @DixonCider, @rdparker and @goerz.

Special thanks to @b00giZm for hist PR!

# Version 12.3

New iPad Pro ❤️😍

## Changes in Build 70

- New say command. #629
- Fixed font-family detection in single line css. #643
- Fixed prefer home indicator to be hidden. #608
- New bigger default font for ipads.
- New key auto repeat is on by default.
- Fixed few crashes.
- Fixed some memory leaks.
- Fixed completion of paths with spaces. #627
- Updated hterm to latest
- Improved keyboard interactive auth in ssh command.
- Fixed key generation for ECDSA 521. #632
- New layout modes (Fill, Fit, Cover)
- Improved layout system (fewer resizes)
- New cmd+o shortcut toggles focus on current session. #561
- New option to map ~ as ESC. PR #619

Huge thanks to @botanicus, @premist, @xipher1, @s8m2s, @jaydenk, and @reyharris.

Special thanks to @BillWSY for his PR!

# Version 12.2

## Changes in Build 57

- Fixes for ssh command.
- Fixed scp with custom port.
- Added -2 flag for ssh2 to mosh command.

## Changes in Build 53

- Updated libssh to 0.8.5.

## Changes in Build 52

- Improved mosh state restoration. #577
- Fixed grab ctrl+space option. #588, #606
- Fixed ssh default user. #605
- Fixed known_hosts check.
- Fixed restore cursor and text styles after command termination.
- Fixed memory leaks.

## Changes in Build 47

- Updated libssh to 0.8.3.
- Added alternate icon. #583
- Added xargs command.
- Fixed don't grab ctrl+space by default. #588
- Fixed log ssh connect error.
- Fixed partial auth in ssh. #582
- Fixed ecdsa public keys. #581
- Fixed use id_rsa key by default. #582
- Warn users for key dups in Blink Config and .ssh folder. #582

Huge thanks to @andrius, @solarfl4re, @mgbaozi, @shannonmoeller, @goerz, @avysk
for help and patience.

# Version 12.1

## Changes in Build 43

- Hot fix for ssh keys

Thanks to @thinkberg for alarm.

## Version 12.0

## Changes in Build 40

- Fixed extra space under software kb on iPads. #401

## Changes in Build 38

- Fixed interactive prompts in ssh command. #203
- Fixed passcode lock screen with external monitor. #570
- Fixed passcode lock screen crash. #571
- Fixed do not print remote ip by default in ssh command.

Huge thanks to @juneoh, @thariman, @saptarshiguha.

## Changes in Build 36

- Fixed crash with ssh agent forwarding. #563

## Changes in Build 35

- Fixed resize issue for sessions with proxy command.
- Fixed command line parsing with `>` inside quotes. #203
- Improve socket cleanup and error messages for `ssh-add` and `ssh-agent`
  commands. #563
- New scp use custom host port from blink host config. #564

Huge thanks to @holzschu, @0x0000null, @thariman, @saptarshiguha and [@x0wl](at
discrord).

## Changes in Build 34

- Fixed writes to ssh channels after EOF.
- New `ProxyCmd` option in hosts ssh config section. #203
- Fixed `del` (delete forward) key press on hardware keyboards. #559
- Fixed blank screen if custom theme use unknown js functions. #558
- Updated FiraCode to v1.206

Huge thanks to [@x0wl](at discrord), @aphecetche, @SilverEzhik.

## Changes in Build 33

- New `ssh-agent` command.
- New `ssh-add` command.
- New `ssh -A` flag. Enables forwarding of the authentication agent
  connection. #81, #204
- Fixed auth attempt with empty password.
- Fixed memory leaks.

Huge thanks to [@myneid](at discrord), @rfldn, @brandonshough.

## Changes in Build 29

- Fixed issue with ssh servers without compression.
- Fixed broken colors in remote tmux. #552.
- New `ssh -W` for standart io forwarded over secure channel.
- New Allow send env variables with `ssh -o sendenv=ENV` option. #287
- New `geo` command to get you coordinates in json format.
- New `mosh --key` flag allows run mosh client without ssh. #190
- Smother switching between terminals (no splashes).
- Better support for Siri shortcut.

Credits:

Huge thanks to [@rob](at discord), @goerz, @treyharris.

The road to 12. This is the version many have been waiting for. SSH is crucial
for Blink, so not only we are supercharging and getting ahead of everyone else,
we will also be ahead in the future. This release has a lot of under the covers
work to set the basis of what Blink will become in the future, so stay tuned!
Here is what is new and what we would like you to help us out testing:

- Support for new keys, including ECDSA and Ed25519! (DSA too, but you shouldn't
  be using that).
- Keys can now also be files stored on ~/.ssh within Blink. Please note those
  keys are not stored within the Secure Enclave, but you can always import them
  in Blink.
- Port Forwarding! Tunnel to a remote server using the usual -L and -R. Supports
  both direct/reverse!
- ProxyCommand support! (We are working on the agent and it should be ready
  before release).
- SSH connections should now last a lot longer too, without any tricks.
- Libssh supported ciphers, etc...
- SSH should now support piping with > and better exec commands.
- Resolving addresses within a VPN should now work better.
- Support for -o parameters within ssh (keep alive, etc...)
- Tuned authentication methods to be more in line with OpenSSH.
- Better verbose output with -v[vvvvv]

And then some more:

- Support to move sessions between screens when using AirTerminals.
- We have improved the speed of the main loop for ssh and now in many cases, it
  is even faster than Mosh for daily use.
- Fixed IPv6 addresses for Mosh.
- Fixed issue for servers without a password. Fixed ^L in built-in shell
  temporarily changing linefeed handling.
- Blink Keys stored within the Secure Enclave won't offer the passphrase option
  as that was redundant (the Secure Enclave already encrypts in hardware).
- iOS tuning and more general performance tweaks.
- We will keep libssh2 based version as ssh2 command.

# Version 11

- New Rendering engine. Smoother, faster and more accurate. We improved it so
  much that you may not need a new iPad next week. We had to go to desktop apps
  to compare the speed. Blink is now many times faster than Hyper.js and even
  faster than iTerm 2 long renderings. Big kudos to Yury for his outstanding
  work on this.
- Inertial Scrolling and Mouse events! As part of changing our rendering engine,
  we now support Inertial scrolling and mousedown and mouseup events. We will
  continue improving mouse support in next versions.
- Drag & Drop text from and to Blink.
- UNIX tools: You can now curl, scp, sftp, telnet, cd, ping, nc... I know what
  you are typing... telnet towel.blinkenlights.nl :)
- File Management: Blink's sandbox is now accessible within your device so you
  can operate with your files. Want to send something to a different app? Use
  the "open" command!
- iCloud Drive: Blink is now connected to iCloud Drive! You can seamlessly copy
  files from your iMac or any other devices to the Blink container.
- Linking to other apps: We took that further, and you can also "mount" other
  apps within Blink! You can now grep your git repositories from Working Copy,
  or curl a file and drop it to a different app!
- Better shell: We dropped linenoise and use REPL. We now have better
  autocompletions, "Reverse Search" and pipe commands or files!
- We have enabled ssh compression by default to increase speed.
- Multiple fixes and bugs crashed.

# Version 10.104

- PragmataPro
- Updated build server scripts and mosh version.
- IME mode support - multistage input for chinese, japanese, etc.
- New keyboard sequences for Alt-Backspace, Shitf-Tab and C-M-key.
- Updated app icon.
- Updated Fira Code.
- Updated Solarized theme.
- Faster rendering thanks to less DOM manipulations.
- Fixed emoji width rendering.

# Version 10.0

- Secured Mosh Persistent Connections and Restore.
- Image rendering!
- URL Links detection!
- Autocomplete for commands and hosts!
- Two fingers swipe up shows a new "control command" section.
- Support for Remote Copy under SSH.
- iPhone users, two fingers closes on-screen keyboard.
- More and better emojis support.
- Added "history" command to cleanup the history file.
- Bold fonts now with an option for bold or bright.
- New WWDC16 theme.
- Added Light/Dark keyboard setting.
- Support for installed fonts, so no more CSS is required.
- Control selections with keyboard! Read help for more information.
- Copy - Paste now works in unfocused mode too.
- Paste Selection.

- Faster Terminal rendering thanks to better writing flows.
- Updated HTerm!
- Updated Mosh to 1.3!
- Updated MBProgressHUD to fix race conditions.

- Fixed stuck Cmd key (deal with iOS issues).
- Fixed swipe ups triggering SmartKeys.
- Fixed Cmd as Ctrl for Ctrl+C and Ctlr+Z
- Fixed resize glitches.
- Improved loading time for terminal and custom fonts.
- Improved focus when switching between apps.
- Improved and smoother animations.
- Improved accessoryView handling if other screen is active.
- Improved all gestures internally.
- Fixed tab caching after closed.
- Fixed issues with irregular character widths misaligning columns.
- Fixed vertical rendering of fonts in some specific scenarios.
- Fixed issues with resizes and focus.
- Fixed unselect on tap.
- Fixed ssh restores crashing the app.
- Fixed external screen focus.

# Version 9.0

- Index and run commands from Spotlight
- Tune Selection

- Updated Layout guides for terminal. Better behaviour on iOS11 and iPhone X
- Shortcuts working again.
- Send INTerrupt instead of TERMinate to Mosh.
- Ignore commands when app doesn't have focus. Should fix empty tabs and improve
  stability.

# Version 8.026

- Fixed keyboard settings bug and alignment of controls

# Version 8.0

- Avoid kbd to collapse while performing a selection.
- Disable Smart Anything within iOS 11

# Version 7.0

- Selection Granularity at the character level.
- Mapped Ctrl+/ to 0x1f (undo on Emacs).
- Set Autolock with a timer.
- Improved behavior of SmartKeys when in SplitView.
- Remember KB language selection between sessions.

- Fixed issue with terminal resizing not resetting after rotation or SplitView
- Fixed issue with iOS11 beta 3 breaking due to WKWebView changing on non-main
  thread.

PLEASE NOTE: If using iOS11, disable smart punctuation to have quotes and dashes
behave as the terminal expects. This will be fixed once iOS11 goes gold.

# Version 5.028.1

- Fixed Cmd+v shortcut
- HostKey fingerprint as base64 encoding
- Smoothing the HUD on resize or SplitView
- Empty default user configuration bugs.
- Zoom shortcuts changed.
- Solarized theme fixes.

# Version 4.024.2

- AirTerminals! Put a terminal on your remote AirPlay screen :)
- Blink shortcuts. Use your external keyboard to move, create, or remove
  terminals. Configure the trigger too! View settings > Keyboard > Shortcuts for
  more info.
- Want to use SmartKeys when an external keyboard is connected? Now you can
  switch them on and off from configuration.
- View geometry of the screen from the overlay with each resize.
- Switch cursor blinking on/off from Appearance settings.

- Fixed TouchID issues when returning to the app.
- Fixed cursor blink sequence so that it always starts as ON.
- Fixed Host Port not resetting properly.
- Fixed overlay getting covered in landscape mode.

- Smoother experience thanks to cleanups and improvements.

# Version 3.021.2

- iCloud Hosts sync. Synchronize hosts between devices. If a Host already has
  been synced, it provides conflict resolution. No critical data like passwords
  is saved.
- Auto Lock. If enabled, when you lock/unlock your device, Blink will also be
  locked. Passcode and TouchID will be required to unlock the app.
- Added ARMv7 support. Support for 32 bit devices like iPad 2, 3, iPhone 5,
  etc... We will publish depending on how well it performs!
- Added IPv6 support for hosts.
- Share Public Encryption Keys. You can now share the public key from the Keys
  section to other apps, like Mail.

- Updated Fira Code font to v1.204.
- Improved error checking on Themes and Font uploads. Auto correct if the GH URL
  is not a raw one.

- Fixed bug with password not getting saved on host creation.
- Fixed crash when hitting arrows with landscape keyboard on Plus devices.
- Rolled back LC_CTYPE enforcement on server.

# Version 2.109 / 3.0

- NEW Autorepeat for normal keys on external keyboard. Vim users rejoice!
- NEW Default User for connections based on device.
- NEW Comments for Public Keys.

- Security updates to libraries.

- Fixed critical bugs affecting ssh connections.

# Version 1.031

- NEW On-screen keyboard with more space for modifiers, FKeys and Cursor keys.
  Redesigned for more space on the modifiers, and with a central scrollable area
  that handles more keys. Activate the Alternate keys by taping on the Alt key.
  And now tap on a modifier to activate it as a normal button, or make a long
  press to chain different combinations.
- NEW Add your own Fonts & Themes! More info on
  (https://github.com/blinksh/fonts) and (https://github.com/blinksh/themes)
- NEW Multistep authentication. Servers with google authenticator or similar
  will now connect without problems :)
- NEW Fira Code font with ligatures included.

- Added -l parameter to ssh for Hosts.
- Improved message on how use hosts after adding them.
- Fixed on-screen arrows.
- Fixed F0 as F10 on external keyboard.
- Fixed keys selection problem on settings
- Fixed ssh-copy-id issue when accessing the host for the first time

# Version 1.019

- Simplified build process.
- New README and BUILD instructions

# Version 0.1020

- "Get In Touch" and "About" sections completed.
- iOS 10 support.
- Added exception for iOS distribution.

- Improved gesture support, specially on iPhone and iOS10.
- MBProgressHUD updated with patch.
- Test Terminal fixes for fonts and updates.
- Disable font ligatures.
- SSH Session termination fixes.

# Version 0.1010

- Terminal customization! Customize your terminal with different default themes
  and fonts. Preview your changes within the Settings Preview section. Save your
  changes and restore them on each execution. Enjoy!

- Create an id_rsa on first boot as default key.

- Swipe and pinch conflicts
- Copy changes to settings

# Version 0.931

- Map Caps or Shift taps to Esc key.
- Cursor keys (Home, End, PgUp, PgDown) with default to Cmd+arrow.
- Function keys (F1-F10) with default to Cmd+number.
- Change mapping of any function key to a different combination.

- Improved placeholders for Hosts configurations.

- Removed Alt as Esc from initial defaults.

# Version 0.927

This version should complete the experience in relation to ssh and terminal
configurations, mimicking a big part of what you can do in a normal shell:

- Hosts Configuration. Preconfigure a host parameters, like user, port, key and
  commands.
- Connect to a Host by specifying its name. Do "mosh plankton"
- Overwrite parameters from host configuration from the shell. So
  carlos@plankton will override the user field on plankton.
- Default Modifier keys settings changed: Ctrl is Ctrl, and Alt sends Esc.
  Everything else is undefined.
- Modifier keys configuration. CAPS as Ctrl or ESC, no problem! Cmd as Ctrl? You
  have it! Configure everything to you liking.
- Added secure passwords stored on Keychain to Host Configuration.
- Exiting the session within the MCP closes the Space.

- Fixed hang after "exec request accepted". Establishing connections should be
  smooth now.
- Fixed adjustments on viewport after rotating the display.
- Fixed Ctrl + Space sequences.
- Fixed wrong/unexisting Ctrl sequences.
- Added Esc+any character support.

- New settings added to project. Will start to fill up in raw branch.

# Version 0.916

This version contains many important bug fixes that should improve the
experience a lot and reduce crashes to, hopefully, close to zero:

- Unicode support to Blink shell. Thanks Yury!
- Support for function keys + modifiers. Now you can do Ctrl/Alt/Shift + Arrows.
- Improved experience with drag down to close. Let me know what you think :)
- SSH with improved function keys in ncurses apps. htop, less, etc... should now
  work perfectly.
- New help message with version and gestures.
- Added asterisk, underscore and escape to SmartKeys.
- Added HockeySDKResources.bundle to project for improved updates.

- Fixed resize when in SplitView mode getting stuck.
- Fixed port bug.
- Optimized messaging to terminal to avoid overloading WKWebView.
- Optimized Terminal switching and closing that was causing crashes and
  inconsistencies.

# Version 0.722

- SSH session support. You can now start full ssh sessions inside the shell, or
  send remote ssh commands to a host.

# Version 0.716

- Improved focus to follow the Terminals.
- Pasting key from clipboard problems fixed.
- ssh-copy-id problems fixed.
- Mosh session support for ssh port and identity added (-I and -P)
- Scroll during a Mosh Session disabled.

# Version 0.713

- Releasing Blink as Open Source

- Copy and Paste support.
- SmartKeys: On-Screen keyboard display, with support for keyboard combos.
- Modifier keys support on SmartKeys: continuous presses.
- Closing a Terminal with Two Fingers down gesture.
- Space swiping notifications.
- Font size control with keyboard
- Fixed CAPS as Ctrl problem with normal characters.
- Smooth swiping spaces gestures.
- Scroll.

- New libssh2 based backend for ssh command.
- ssh command with exec, pty and shell support.
- DNS and Bonjour name resolution. Back to My Mac support.
- Known Hosts verification.
- Support for interactive authentication methods.
- Public Key authorization support.
- Settings dialog for Blink configuration.
- PK creation from settings.
- Support to run an external command from Mosh or SSH.

- ssh-copy-id command.
- stderr support for Sessions.
- Duplicated streams for each Session, attached or detached.
- Terminals freeing resources and correctly killing Sessions after termination.
- Mosh prediction modes support.

# Version 0.511

This version has seen major improvements on Mosh, terminal display and keyboard
support. Please read previous notes:

- The terminal is faster and most of the identified glitches have been fixed.
- We have added a Powerline font so you can have fun and test tools like zsh,
  tmux or spacemacs!
- Mosh is now cleaner when restoring.
- CAPS as Ctrl now preserves the state. Mapped Cmd and Alt special events to the
  right commands.

# Version 0.504

This version continues the previous goal to stabilise Mosh by exposing it to
real life scenarios. Many problems have been fixed since last version:

- Terminal problems have been fixed (misalignments, problems when switching to
  other apps, etc..)
- Mosh issues fixed: Restore the session after device suspension; Mosh crashing
  right after start; Threading problems restarting a session.

## New from this version:

- We now support Mosh < 1.2.5
- Added SplitView to continue the terminal work.

## What to test:

- Problems establishing a connection, multiple concurrent sessions open, closing
  connections correctly, reconnecting after long periods
- Keyboard support: For this version we have configured Ctrl, Cmd and Caps as
  Ctrl, Alt as meta.
- Terminal rendering glitches: Complex terminal layouts, split view positioning,
  Unicode, color rendering.

# Version 0.429

The purpose of this build is to test our Mosh version in real life scenarios
that could help us identify errors and misbehaviours. Sorry if there are no
bells and whistles yet, we want everyone to focus on stabilising our Mosh
changes.

## What to test:

- Problems establishing a connection, multiple concurrent sessions open, closing
  connections correctly, reconnecting after long periods...
- Keyboard support: For this version we have configured Ctrl, Cmd and Caps as
  Ctrl, Alt as meta.
- Terminal rendering glitches: Unicode, color rendering, garbled rendering...
