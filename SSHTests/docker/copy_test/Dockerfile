FROM fedora:latest

RUN dnf install -y openssh-server curl procps && rm -rf /var/cache/yum
#RUN apk --update add linux-pam openssh-server-pam psmisc curl && rm -rf /var/cache/apk/*
#RUN apt-get update && apt-get install -y openssh-server curl && rm -rf /var/lib/apt/lists/*
ADD src/ .
RUN sh /bootstrap.sh && rm /bootstrap.sh

ENTRYPOINT [ "/usr/sbin/sshd", "-D", "-e" ]