FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    openssh-client \
    jq \
    sudo

COPY assets/ /opt/resource/

RUN chmod +x /opt/resource/*
