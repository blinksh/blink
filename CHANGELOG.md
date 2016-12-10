# Version 2.109
	- NEW Autorepeat for normal keys on external keyboard. Vim users rejoice!
	- NEW Default User for connections based on device.
	- NEW Comments for Public Keys.

	- Security updates to libraries.

	- Fixed critical bugs affecting ssh connections.

# Version 1.031
	- NEW On-screen keyboard with more space for modifiers, FKeys and Cursor keys. Redesigned for more space on the modifiers, and with a central scrollable area that handles more keys. Activate the Alternate keys by taping on the Alt key. And now tap on a modifier to activate it as a normal button, or make a long press to chain different combinations.
	- NEW Add your own Fonts & Themes! More info on (https://github.com/blinksh/fonts) and (https://github.com/blinksh/themes)
	- NEW Multistep authentication. Servers with google authenticator or similar will now connect without problems :)
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
	- Terminal customization! Customize your terminal with different default themes and fonts. Preview your changes within the Settings Preview section. Save your changes and restore them on each execution. Enjoy!

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
	This version should complete the experience in relation to ssh and terminal configurations, mimicking a big part of what you can do in a normal shell:
	- Hosts Configuration. Preconfigure a host parameters, like user, port, key and commands.
	- Connect to a Host by specifying its name. Do "mosh plankton"
	- Overwrite parameters from host configuration from the shell. So carlos@plankton will override the user field on plankton.
	- Default Modifier keys settings changed: Ctrl is Ctrl, and Alt sends Esc. Everything else is undefined.
	- Modifier keys configuration. CAPS as Ctrl or ESC, no problem! Cmd as Ctrl? You have it! Configure everything to you liking.
	- Added secure passwords stored on Keychain to Host Configuration.
	- Exiting the session within the MCP closes the Space.

	- Fixed hang after "exec request accepted". Establishing connections should be smooth now.
	- Fixed adjustments on viewport after rotating the display.
	- Fixed Ctrl + Space sequences.
	- Fixed wrong/unexisting Ctrl sequences.
	- Added Esc+any character support.

	- New settings added to project. Will start to fill up in raw branch.

# Version 0.916
	This version contains many important bug fixes that should improve the experience a lot and reduce crashes to, hopefully, close to zero:
	- Unicode support to Blink shell. Thanks Yury!
	- Support for function keys + modifiers. Now you can do Ctrl/Alt/Shift + Arrows.
	- Improved experience with drag down to close. Let me know what you think :)
	- SSH with improved function keys in ncurses apps. htop, less, etc... should now work perfectly.
	- New help message with version and gestures.
	- Added asterisk, underscore and escape to SmartKeys.
	- Added HockeySDKResources.bundle to project for improved updates.

	- Fixed resize when in SplitView mode getting stuck.
	- Fixed port bug.
	- Optimized messaging to terminal to avoid overloading WKWebView.
	- Optimized Terminal switching and closing that was causing crashes and inconsistencies.

# Version 0.722
	- SSH session support. You can now start full ssh sessions inside the shell, or send remote ssh commands to a host.

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
This version has seen major improvements on Mosh, terminal display and keyboard support. Please read previous notes:
	- The terminal is faster and most of the identified glitches have been fixed.
	- We have added a Powerline font so you can have fun and test tools like zsh, tmux or spacemacs!
	- Mosh is now cleaner when restoring.
	- CAPS as Ctrl now preserves the state. Mapped Cmd and Alt special events to the right commands.

# Version 0.504
This version continues the previous goal to stabilise Mosh by exposing it to real life scenarios. Many problems have been fixed since last version:
	- Terminal problems have been fixed (misalignments, problems when switching to other apps, etc..)
	- Mosh issues fixed: Restore the session after device suspension; Mosh crashing right after start; Threading problems restarting a session.

## New from this version:
	- We now support Mosh < 1.2.5
	- Added SplitView to continue the terminal work.

## What to test:
	- Problems establishing a connection, multiple concurrent sessions open, closing connections correctly, reconnecting after long periods
	- Keyboard support:  For this version we have configured Ctrl, Cmd and Caps as Ctrl, Alt as meta.
	- Terminal rendering glitches: Complex terminal layouts, split view positioning, Unicode, color rendering.

# Version 0.429
The purpose of this build is to test our Mosh version in real life scenarios that could help us identify errors and misbehaviours. Sorry if there are no bells and whistles yet, we want everyone to focus on stabilising our Mosh changes.
##What to test:
	- Problems establishing a connection, multiple concurrent sessions open, closing connections correctly, reconnecting after long periods...
	- Keyboard support:  For this version we have configured Ctrl, Cmd and Caps as Ctrl, Alt as meta.
	- Terminal rendering glitches: Unicode, color rendering, garbled rendering...
