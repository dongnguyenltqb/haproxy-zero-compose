FROM haproxy:2.6.1-alpine
USER root
RUN apk update && apk add curl net-tools bind-tools socat
COPY --chown=haproxy hosts.map /hosts.map
COPY --chown=haproxy haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
USER root
