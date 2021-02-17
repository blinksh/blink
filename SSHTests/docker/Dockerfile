FROM alpine:latest

RUN apk --update add openssh-server-pam curl && rm -rf /var/cache/apk/*
ADD src/ .
RUN sh /bootstrap.sh && rm /bootstrap.sh

ENTRYPOINT [ "/usr/sbin/sshd", "-D", "-e" ]