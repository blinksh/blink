# Tips and Tricks

## Basics 

### Mouse Support

Enabling mouse support comes in handy when using an iPad without a keyboard as you can freely change panes in tmux or scroll throughout your apps with your fingers, few popular ones include:

**TMUX:**
```tmux
set -g mouse on
```

**VIM:**
```vim
set mouse=a
```

**EMACS:**
```emacs
(xterm-mouse-mode 1)
```

### Serving development website over HTTPS

Fastest way of using HTTPS on remote machines for development is with the Caddy web server. First install it as an executable, but not service, then create Caddyfile with reverse_proxy line like this:

```json
example.com {
  reverse_proxy 127.0.0.1:1313
}
```

Or start Caddy directly in reverse-proxy mode from CLI:

```bash
sudo caddy reverse-proxy --from example.com --to 0.0.0.0:1313
```

### Starting TMUX/Screen on session start

Adding startup commands is as easy as going to Host settings, scrolling to bottom and inserting command we want to use:

```shell
tmux a -t session_name
screen -rd session_name
```
Or anything other that we want to run when starting a new session. It also can be run from Blink command line:
```shell
mosh host -- tmux a -t session_name
mosh host -- screen -rd session_name
```

### SSH port forwarding from remote machine to iPad

Forwards connections from a port on a local system to a port on a remote host:

```bash
ssh -L 3000:localhost:3000 ssh-host
```
### Blink: Using screen corners
Taping three fingers on the screen will bring a Blink menu in which you can set the Cover, Fill, and Fit setting, adapting Blink to different screens and devices.

![img](/tips-and-tricks/Cover-Fill-Fit.png)

### External Display: Apple TV
You can use Apple TV as a second monitor, just start screen share on Apple TV and Blink will use it as second monitor, not just mirroring. This is really cool if you are doing a presentation, or if you are on the couch with your phone and want to have a bigger display!

### External Display: Split View
For the external display to work, Blink needs to be an active window on the iPad. A very cool way to do this is to use Split View on the iPad, giving Blink ½ or ¼ of the screen, while the rest can be taken by Safari or anything else you need!

## Advanced

### Inline Images

Blink supports displaying images over SSH when using [iTerm2 imgact](https://iterm2.com/utilities/imgcat). Put it in local .bin folder ($HOME/.bin or any other in your %PATH) and use it as this:

```bash
imgcat image.png
```

**NOTE: This does not work in terminal multiplexers (TMUX, GNU Screen) or inside Mosh.**

Alternative that works inside every environment, but needs Rust installed is VIU. Install it using Cargo:

```bash
cargo install viu
```
And use:

```bash
viu image.png/animation.gif
```
More information: [VIU GitHub Repository](https://github.com/atanunq/viu)

### TMUX: Copy/Paste using OSC52

Enabling copy/paste between tmux and iOS needs SSH or Blink Mosh Server.

```tmux
set -g set-clipboard on
set -ag terminal-overrides "vte*:XT:Ms=\\E]52;c;%p2%s\\7,xterm*:XT:Ms=\\E]52;c;%p2%s\\7"
```

VIM users can set this to have similar experience to VIM:

```tmux
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection
bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
```

## Editors

### VIM: Copy/Paste between remote machine and iOS

To enable copy/paste you'll need to install [ojroques/vim-oscyank](https://github.com/ojroques/vim-oscyank) and add this line to .vimrc:

```vim
autocmd TextYankPost * if v:event.operator is 'y' && v:event.regname is '' | OSCYankReg " | endif"
```
And enable this setting:
```vim
set clipboard& clipboard^=unnamed,unnamedplus
```

### VIM: Exit insert mode without ESC key

Change CapsLock in Blink Settings to Control and press Ctrl(CapsLock) + [ to exit insert mode on iPad keyboards without ESC key.
