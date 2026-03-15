FROM alpine:3.19

RUN apk add --no-cache \
    openssh \
    sudo \
    bash

RUN ssh-keygen -A

RUN adduser -D -s /bin/bash testuser && \
    echo "testuser:testpassword" | chpasswd && \
    adduser testuser wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir -p /home/testuser/.ssh && \
    chmod 700 /home/testuser/.ssh && \
    chown testuser:testuser /home/testuser/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

CMD ["/entrypoint.sh"]
