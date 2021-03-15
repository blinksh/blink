#!/bin/sh

dropbear -RB -p 23

exec /usr/sbin/sshd -D -e $@