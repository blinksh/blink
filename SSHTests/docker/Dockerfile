FROM fedora:latest

RUN dnf install -y openssh-server curl procps psmisc autoconf automake which @development-tools && rm -rf /var/cache/yum

RUN mkdir -p /home/no-password && curl -X GET https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.99.tar.xz --output /home/no-password/linux.tar.xz

RUN curl -SL https://github.com/mkj/dropbear/archive/DROPBEAR_2020.81.tar.gz | tar -xzC /tmp \
    && cd /tmp/dropbear-DROPBEAR_2020.81 \
    && autoconf \
    && autoheader \
    && ./configure --disable-zlib \
    && make PROGRAMS=dropbear install \
    && rm -rf /tmp/dropbear-DROPBEAR_2020.81

ADD src/ .
RUN sh /bootstrap.sh && rm /bootstrap.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]