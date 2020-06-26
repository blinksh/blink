# All About Mosh

## Introduction

Mosh, a portmanteau word for mobile shell, is a terminal connection program that facilitates persistent shell sessions in less-than-ideal network situations. If you have a low-bandwidth or intermittent connection, switch between multiple devices or ISPs or even use devices with sporadic Internet access you will be able to maintain consistent shell sessions with Mosh.

Mosh accomplishes this feat by using the UDP-based state-synchronization protocol ([SSP](https://en.wikipedia.org/wiki/Mosh_(software)#Roaming)), which isn't bound to a particular network connection. SSP keeps the client and server in sync, while predictive local echo can "guess" what will be displayed after the user presses a key. This approach reduces input latency and transfers fewer bytes of data over the wire.

Mosh isn't just for mobile devices. Ever have to connect to a SSH server in another continent? Sometimes the input latency is so high on international SSH connections that editing files and typing on the command line can be a frustrating experience. Mosh can significantly decrease your latency and improve your worldwide server connections.

Mosh runs as the user and doesn't need root access so if the process were somehow compromised the damage would be contained to the user and the system's administrative account would be spared. SSH still governs the authentication process, so your standard authentication methods such as SSH keys and passwords are still useable. Once connected, Mosh takes over the connection.

## Installing Mosh

To use Mosh you must install it on the server. Blink Shell comes with mosh support right out of the box. Any other client that you use will also need to have Mosh installed.

### Debian, Ubuntu and apt-based Distribution

```bash
apt install mosh
```

### Arch-based Distribution

```bash
pacman -S mosh
```

### CentOS, Fedora and Amazon Linux

You mush enable the EPEL, instructions to do so may vary on distribution, and run:

```bash
yum install mosh
```

Or you can also compile it from [source](https://github.com/mobile-shell/mosh).

### Other and Compiling from Source

For a list of instructions on other systems please see [this](https://mosh.org) link.

## Using Mosh

To connect with Mosh, run:

```bash 
mosh remote
```

Where `remote` for the host or IP address of the remote server. Authentication occurs over SSH. You can use the `-P` switch to specify a port.

```bash
mosh -P 1234 remote
```

Replacing `1234` with the port number of your remote SSH server. The Mosh sesion ends when you use the `logout` or `exit` commands.

## Mosh and Command History

Due to Mosh's predictive local echo and unique transmission methods it cannot maintain a history of previously used commands. To work around this shortcoming, you can use `tmux` or `screen`.

## A World About Firewalls and Ports

Most system administrators open port `22` via TCP to SSH. Since Mosh uses UDP, you'll need to open UDP ports `60000` through `61000` for the SSP packets. This range opens one thousand ports which is more than enough but, if you only plan to make a few Mosh connections you can enable a smaller range, for example ports `60000` through `60005`,  that leaves room for five simultaneous sessions. You can also specify the UDP port with the `-p` option on the `mosh` command if you wish to use an entirely different range.

If SSH runs on a different port than the default you'll need to invoke Mosh with a custom SSH argument like this:

```bash
mosh --ssh="ssh -p 1234" remote
```

Replacing `1234` with the custom port and `remote` with the hostname or IP address of the server.

## SSH Tunnels and Bastion Hosts

Mosh has no concepts of SSH tunnels or bastion hosts but you can run a SSH tunnel in a different window. Once the SSH tunnel is established and the remote port brought to your machine, you can use `mosh localhost:1234` where `1234` is the port you tunneled, to connect via the SSH tunnel to Mosh. Doing this will counteract some of the advantages of Mosh, so using a VPN into the protected network is your best option.

## The Bleeding Edge of Mosh

Blink has additional support for new Mosh features like TrueColor rendering and remote clipboard. Some of these features are not supported in older versions of Mosh versions that may be installed on your servers. If that's the case, you can uninstall Mosh via your package manager or compile it and install it from source. Please see this [link](https://mosh.org) for more information.
