FROM alpine:3.20 AS builder

RUN apk add --no-cache git build-base autoconf automake libtool asciidoc

RUN git clone https://github.com/tinyproxy/tinyproxy.git /src
WORKDIR /src
RUN ./autogen.sh && ./configure --prefix=/usr --sysconfdir=/etc && make && make install

FROM alpine:3.20

COPY --from=builder /usr/bin/tinyproxy /usr/bin/tinyproxy
COPY --from=builder /usr/share/tinyproxy /usr/share/tinyproxy

RUN addgroup -S tinyproxy && adduser -S -G tinyproxy tinyproxy \
    && mkdir -p /etc/tinyproxy /var/log/tinyproxy /var/run/tinyproxy \
    && chown -R tinyproxy:tinyproxy /var/log/tinyproxy /var/run/tinyproxy

EXPOSE 8888

ENTRYPOINT ["tinyproxy", "-d"]
CMD ["-c", "/etc/tinyproxy/tinyproxy.conf"]
