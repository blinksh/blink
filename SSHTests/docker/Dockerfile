FROM fedora:latest

RUN dnf install -y openssh-server curl procps psmisc && rm -rf /var/cache/yum
# ADD https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.99.tar.xz /home/no-password/linux.tar.xz
ADD src/ .
RUN sh /bootstrap.sh && rm /bootstrap.sh

ENTRYPOINT [ "/usr/sbin/sshd", "-D", "-e" ]