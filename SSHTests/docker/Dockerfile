FROM ubuntu

COPY ./bootstrap.sh /
COPY ./id_rsa.pub /

RUN apt-get update && apt-get clean && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN chmod +x /bootstrap.sh && ./bootstrap.sh

RUN sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseauthentication yes/g' /etc/ssh/sshd_config && \
    sed -i 's/PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
    sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM no/UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/#PasswordAuthentication no/g' /etc/ssh/sshd_config && \
    sed -i 's/AcceptEnv LANG LC_\*/AcceptEnv LANG LC_\* TEST/g' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 300' >> /etc/ssh/sshd_config && \
    echo 'Match user partial\n\tAuthenticationMethods publickey,password' >> /etc/ssh/sshd_config && \
    echo 'Match user vagrant\n\tPasswordAuthentication yes' >> /etc/ssh/sshd_config

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
