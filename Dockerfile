FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

LABEL base=alpine engine=jvm version=java11 timezone=UTC port=8080 dir=/opt/app user=app
ARG ZULU_PKG="zulu11"

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apk update && wget -P /etc/apk/keys/ https://cdn.azul.com/public_keys/alpine-signing@azul.com-5d5dc44c.rsa.pub && \
    echo "https://repos.azul.com/zulu/alpine" >> /etc/apk/repositories && \
    apk --no-cache add ${ZULU_PKG}-jdk

ENV JAVA_HOME=/usr/lib/jvm/${ZULU_PKG}-ca

RUN apk update && apk add --no-cache tzdata curl bash gcompat && rm -rf /var/cache/apk/*
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

EXPOSE 8080

RUN mkdir -p /opt/app && ln -s /opt/app /libs && mkdir -p /opt/db-migrations && ln -s /opt/db-migrations /flyway

WORKDIR /opt/app

RUN addgroup -g 1000 -S app && adduser -u 1000 -G app -S app \
&& chown -R app:app /opt/app /libs /opt/db-migrations /flyway

USER app
