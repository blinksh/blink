# Advanced SSH: Tunnels, Jump Hosts and Agents

## Introduction

All system administrators know that SSH is arguably the most useful and powerful remote administration tool available for UNIX/Linux systems. SSH brings a remote system's command-line interface to our local mahcine unlocking the real source of the magic behind NIX systems - the shell.

Bash, ZSH, fish and other shells allow us to run powerful command-line utilities that alone provide more capability than our average commercial GUI desktop program. Combining all of this with pipes and filters, these gems knit together an unrivaled system that empowers us all.

And yet, you can spend years in the shell and not know about some of its most unique and useful features. Let us dig into some of the more obscure, but useful, features of SSH.

## Persistent SSH Connections with Blink

Phones and tablets are tuned for extended battery life, but the power saving technology in iOS works against long-running SSH connections. Fortunately, we have developed a workaround to help with this. The `geo track` command available on Blink Shell will enable the location tracking feature in iOS to ensure Blink can maintain active SSH connections. Rest asured, we don't use or store any of the location data from your device. The `geo track` command bypasses the power saving system to ensure you remain connected while keeping your privacy intact.

## SSH Agent and Forwarding

When stored securely, SSH keys provide strong security for your remote connections. SSH keys should be encrypted with a password to help guard against key theft. While this setup is incredibly secure, repeatedly entering passwords can be annoying. Fortunately, there's a solution - the SSH agent.

The SSH agent stores your key passwords in memory to prevent you from having to enter your password each time you want to connect. While incredibly useful in a local console setting, this benefit can also be securely extended to remote machines via SSH agent forwarding.

Let's see the SSH agent forwarding in action. First, load the SSH agent with the `ssh-agent` command. To load all of your stored keys (i.e., `id_rsa`, `id_dsa`, `id_ed25519`, etc.) run `ssh-add`. You can load specific keys by specifying the filename with `ssh-add KEY_FILE`. To see which keys are already loaded in the agent, run `ssh-add -l`. The agent will prompt you once for the passphrases to each of the keys (in the order they are added), then loaded into memory for use with future connections.

The PID (**p**rogram **ID**) of the SSH agent is stored in the environment variables `SSH_AGENT`. If you were on a desktop you would need to export that variable for use in subsequent shells. Fortunately, Blink Shell handles this for you.

By default, the `ssh` command doesn't forward the agent's passwords. To enable SSH agent forwarding, connect with `ssh -A` option. This securely makes the keys available to the remote machine. Don't worry - the SSH keys won't be copied to the remote server's filesystem, they are only used to make outgoing connections for the duration of that specific SSH connection. 

Even though SSH agent forwarding has numerous safeguards in place, an application running on the remote server can still use your key for unintended or possibly malicious purposes. To help mitigate this risk, we recommend using a separate key for SSH agent forwarding.

To learn more about the security implications of SSH agent forwarding, please see [this](https://heipei.io/2015/02/26/SSH-Agent-Forwarding-considered-harmful/).

## Tunnels

VPNs are incredibly useful in a wide variety of ways, and with increasing privacy and censorship concerns, they're becoming a practical necessity. While not an exact replacement for VPN technology, SSH tunnels provide secure network routes to or from your local machine to a remote network.

The simplest example is bringing a port from a remote system to your local machine. If you had a development server running a service on port `8080` that wasn't exposed to the Internet and wanted to access it, you could run this command:

```bash
ssh -L 8080:localhost:8080 host
```

Replacing `host` with the remote hostname or IP. Once authenticated, a service listening on port `8080` on the remote machine will now be accesible as though it were on your local device. A connection to `localhost:8080` will be forwarded via the SSH tunnel to the remote computer.

## Jump/Bastion Hosts

A jump host (sometimes referred to as a bastion host or server) is an intermediate SSH server that acts as a gateway to other networks. This setup is a common way to provide SSH access to a protected server (or group of servers) while allowing only one IP address (the jump host) access. This setup prevents other machines from accessing the protected server and ensures that connections first authenticate through the jump host.

To facilitate this, SSH has a `ProxyCommand` option that allows you to specify the intermediate server:

```bash
ssh -o ProxyCommand="ssh -W %h:%p jumphost" host
```

Where `jumphost` with the jump/bastion server and `host` with the remote host.

SSH jump hosts eliminate the need for SSH agent forwarding, offering a more secure approach to connect to protected networks.

## Venture Forth with Your Advanced SSH Knowledge

We hope this guide to advanced SSH has been helpful. Blink Shell, with its native shell and SSH support combined with your knowledge of SSH agent forwarding, jump hosts, SSH tunnels and persistent connections transforms your iOS device into a networking and development powerhouse.
