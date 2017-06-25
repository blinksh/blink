# Blink Shell for iOS (edited for more shell utils)
Do Blink! [Blink](http://blink.sh) is the first professional, desktop-grade terminal for iOS that leverages the support of Mosh and SSH. Thus, we can unequivocally guarantee stable connections, lightning-fast speeds, and full configurations. It can and should be your all-day-long tool.

We did not create another terminal to fix your website on the go. Blink was built as a professional grade product from the onset. We started by analyzing what the must-haves were and we ended up grounding Blink on these three concepts:
- Fast rendering: dmesg in your Unix server should be instantaneous. We can't wait even a second to render. We didn't need to reinvent the wheel to make this happen. We simply used Chromium's HTerm to ensure that rendering is perfect and fast, even with those special, tricky encodings.
- Always on: Mosh transcends SSH's variability. Mosh overcomes the unstable and intermittent connectivity that we all associate with mobile connections. You can check your Safari without fear of having to restart the SSH connection. You can flawlessly jump from home, to the train, and then the office thanks to Mosh. Blink is rock-solid connected all the way. Mosh is readily available and can be easily installed on your server. Go to https://mosh.org. 
- Fully configurable: Blink embraces Bluetooth-coupled keyboards with gusto. Some like Caps as Esc on Vim, others Caps as Ctrl on Emacs. Blink champions them all. But there's more, because we want more. You can also add your own custom themes and fonts to Blink. During your always-on sessions, you're in your zone.

But, Blink is much more. Please read on:
- You should command your terminal, not navigate it. Blink will jump you right into a friendly shell and it'll be clear to you how to roll.
- The interface is straightforward. We dumped all menus and went full screen for your terminal.
- Use swipe to move between your open connections, slide down to close them, and even pinch to zoom!
- Configure your Blink connections by adding your own Hosts and RSA Encryption keys. Everything will look familiar and you get to work, fast!
- We've incorporated SplitView, for those necessary Google searches and chats with coworkers.

For more information, please visit [Blink Shell](http://blink.sh).

# Additions: 

This fork also contains a subset of shell utilities, so you can add / remove files, list them, etc.

Specifically, the commands available (as of now) are:

* Builtin: cd, setenv 
* From file_cmds:
ls, touch, cp, rm, ln, mv, mkdir, rmdir, 
df, du, chksum, chmod, chflags, chgrp, stat, readlink, 
compress, uncompress, gzip, gunzip,
* From shell_cmds: pwd, env, printenv, date, uname, id, groups, whoami, uptime
* From text_cmds: cat, grep, wc
* From curl: curl (includes http, https, scp, sftp...), scp, sftp


You will need to compile the following frameworks:
* blink/AppleSource/file_cmds-264.50.1/file_cmds_ios/file_cmds_ios.xcodeproj using XCode project (*not*  blink/file_cmds-264.50.1/file_cmds.xcodeproj which is for the OSX version of the commands).
* blink/AppleSource/shell_cmds-198/shell_cmds_ios/shell_cmds_ios.xcodeproj 
* blinkAppleSource/text_cmds-97/text_cmds_ios/text_cmds_ios.xcodeproj/
* blink/AppleSource/curl/curl_ios/curl_ios.xcodeproj

These create four static libraries: 
* file_cmds_ios.framework 
* shell_cmds_ios.framewok
* text_cmds_ios.framework
* curl_ios.framework


You will have to copy all of them the blink/Frameworks directory. You will also need to copy the header files: 
* file_cmds_ios/file_cmds_ios.h 
* shell_cmds_ios/shell_cmds_ios.h 
* text_cmds_ios/text_cmds_ios.h 
* curl_ios/curl_ios.h

to the blink/Frameworks/include directory. 


Since you are sideloading, you can also compile VimIOS (the best fork is: https://github.com/eminarcissus/VimIOS) and create an "App group" so Vim and Blink have access to the same directory. 

If you do that, there are 3 directories: 
- one that can only be accessed by Vim
- one that can only be accessed by Blink
- one that is accessed by both applications. 

In MCPSession.m, you will need to edit "appGroupFiles" to reflect the name of the shared directory (it will be related to your Apple ID). There are two environment variables: $HOME links to the Blink-specific directory, $SHARED links to the shared directory. 

From Vim, you can open the files in $SHARED. You can also edit Vim so it opens by default in the shared directory. 

curl opens access to file transfers to and from your iPad (ftp, http, scp, sftp...). It uses the key management system of BlinkShell (the keys you created with "config"). You can also specify keys with a path:
```
curl scp://host.name.edu/filename -o filename --key $SHARED/id_rsa --pass MyPassword 
```
You can also use the scp and sftp commands:
```
scp user@host.name.edu:filename . 
sftp localFilename user@host.name.edu:~/ 
```

scp and sftp are implemented through curl, by rewriting the arguments to follow the curl syntax. Pro: lighter implementation, smaller memory cost, less likely to have function name collisions. Con: some switches might not have exactly the same meaning. 

# Obtaining Blink
Blink is available now on the [AppStore](http://itunes.apple.com/app/id1156707581). Check it out!

If you would like to participate on its development, we would love to have you on board! There are two ways to collaborate with the project: you can download and build Blink yourself, or you can request an invitation to help us test future versions (on the raw branch). If you want to participate on the testing, follow and tweet us [@BlinkShell](https://twitter.com/BlinkShell) about your usage scenarios. Invitations will be sent out in waves, please be patient if you do not receive yours immediately.

Bugs should be reported here on GitHub. Crash reports will be automatically reported back to us thanks to HockeyApp. If you have any questions or want to make sure we do not miss on an interesting feature, please send your suggestions to our Twitter account [@BlinkShell](https://twitter.com/BlinkShell). We would love to discuss them with you! Please do not use Twitter to report bugs.

We can't wait to receive your valuable feedback. Enjoy!

## Build
We made a ton easier to build and install Blink yourself on your iOS devices through XCode. We provide a precompiled package with all the libraries for the master branch. Just extract this package in your Framework folder and build Blink.

```bash
git clone --recursive git@github.com:blinksh/blink.git && \
cd blink && ./get_frameworks.sh
```

Although this is the quickest method to get you up and running, if you would like to compile all libraries and resources yourself, refer to [BUILD](https://github.com/blinksh/blink/blob/master/BUILD). Please let us know if you find any issues. Blink is a complex project with multiple low level dependencies and we are still looking for ways to simplify and automate the full compilation process.

# Using Blink
Our UI is very straightforward and optimizes the experience on touch devices for the really important part, the terminal. You will jump right into a very simple shell, so you will know what to do. Here are a few more tricks:
- Type 'help' to find information at the shell.
- Use two fingers tap to create a new shell.
- Move between shells by swapping your finger.
- You can exit the session and get back to the shell to open a new connection.
- You can also close a session by dragging two fingers down.
- Use pinch gesture to increase or reduce size of text. You can also use Cmd+ or Cmd- if using the keyboard.
- Copy and Paste by selecting text o tapping the screen.
- Run 'config' to setup your keys. Install them to a server through ssh-copy-id.
- Ctrl and Alt modifiers at the SmartKeys bar allow for continuous presses, like in a real keyboard.

# Changelog
# Version 3.021.2
	- iCloud Hosts sync. Synchronize hosts between devices. If a Host already has been synced, it provides conflict resolution. No critical data like passwords is saved.
	- Auto Lock. If enabled, when you lock/unlock your device, Blink will also be locked. Passcode and TouchID will be required to unlock the app.
	- Added ARMv7 support. Support for 32 bit devices like iPad 2, 3, iPhone 5, etc... We will publish depending on how well it performs!
	- Added IPv6 support for hosts.
	- Share Public Encryption Keys. You can now share the public key from the Keys section to other apps, like Mail.

	- Updated Fira Code font to v1.204.
	- Improved error checking on Themes and Font uploads. Auto correct if the GH URL is not a raw one.

	- Fixed bug with password not getting saved on host creation
	- Fixed crash when hitting arrows with landscape keyboard on Plus devices.
	- Rolled back LC_CTYPE enforcement on server.

[View all changes](CHANGELOG.md)

# Attributions
- [Mosh](https://mosh.org) was written by Keith Winstein, along with Anders Kaseorg, Quentin Smith, Richard Tibbetts, Keegan McAllister, and John Hood.
- This product includes software developed by the OpenSSL Project
for use in the OpenSSL Toolkit. (http://www.openssl.org/).
- [Libssh2](https://www.libssh2.org)
- Entypo pictograms by Bruce Daniel www.entypo.com.
