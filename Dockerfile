FROM alpine:3.24

RUN apk add --no-cache \
    bash \
    openssh-client \
    jq \
    sudo \
    bats

COPY assets/ /opt/resource/

RUN chmod +x /opt/resource/*
