# Building
Blink is currently in Alpha stage. If you would like to test it,
please tweet us @BlinkShell. You do not have to compile Blink unless
you want to make modifications to the code, which is accepted under the
[GPL License](http://github.com/blinksh/blink/COPYING).

## Cloning
Clone Blink into your local repository and make sure to obtain any submodules:
git submodule init
git submodule update

## Dependencies & Requirements
Blink makes use of multiple dependencies that you have to compile
separately before building Blink itself. There are simple scripts available
to perform this operation.
- XCode 9.3
- ncurses
- [Libssh2](https://github.com/carloscabanero/libssh2-for-iOS)
- [OpenSSL](https://github.com/x2on/OpenSSL-for-iPhone/tree/ee4665d089a91d7382fcb22b0b09c85a02935739)
- [Protobuf](https://gist.github.com/BennettSmith/9487468ae3375d0db0cc)
- [Mosh](https://github.com/blinksh/build-mosh)

Please note that Blink currently only supports armv64 and x86_64 (simulator)
platforms, so compilation for other architectures is not necessary.
### Installation
#### Libraries
All Mosh dependencies must be installed under the Framework folder
depending on the type of output. We are working on making all the
dependencies a .framework bundle, but it is a complicated project.
Framework bundles can be left at the Framework folder root, while
.a and .h files must go to the corresponding lib and include folder.

To install Libssh2 and OpenSSL in your Blink repository, please copy
the .framework files to the Framework folders.

For Protobuf, please copy the generated .h and .a files to the
Framework/include and Framework/lib respectively.

Mosh will output multiple .a library files, and unfortunately we
didn't find a simple way to just aggregate all of them yet. Please
copy all the .a library files from the output folder (mosh/output) to lib
folder and paste the src/frontend/MoshiOSController.h to the header folder.

Blink also makes use of two other projects, but those can be compiled
within the same project:
- UICKeyChainStore
- MBProgressHUD

Blink uses Linenoise as part of its code for the simple terminal interface.
It is provided within the project due to the big changes made to it. We will
change this piece at some point.

#### Resources
Blink's Terminal is running from JavaScript code linked at runtime.
Most of the available open source terminals can be made to work with Blink,
just by providing a "write" and "signal" functions. An example of this
is provided in the Resources/term.html file.

You can aggregate any terminal you want to the bundle. We are currently
using [Chromium's HTerm](https://chromium.googlesource.com/apps/libapps/+/master/hterm),
but we have been also successful plugin other terminals like [Terminal.js](http://terminal.js.org).

Generate a single term.js file and drop it under the Resources folder.

Font Style uploads requires [webfonts.js](https://github.com/typekit/webfontloader), but it isn't
needed for Blink to work.

## Compiling
Please note that to compile and install Blink in your personal
devices, you need to comply with Apple Developer Terms and Conditions,
including obtaining a Developer License for that purpose. You will also
need all the XCode command line developer tools and SDKs provided under
a separate license by Apple Inc.

Blink uses a standard .xcodeproj file. Any missing files will be marked in
red, what can be used to test your installation.

To configure the project:
1. Under Targets > Blink > General > Identities set a unique Bundle Identifier.
2. Under Targets > Blink > General > Identities set your Team.
3. If you do not want to make use of HockeyApp, please set the preprocessor variable
HOCKEYSDK = 0 under Build Settings.
4. You might be requested to accept your profile or setup your developer account
with XCode, follow the proper Apple Developer documentation in that case.

As a standard XCode project, just run it with Cmd-R.
