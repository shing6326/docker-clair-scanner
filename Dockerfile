FROM docker.io/library/golang:1.16-bullseye AS clair-scanner-builder
WORKDIR /go/src/clair-scanner
RUN apt-get update -y && apt-get install -y build-essential liblvm2-dev libbtrfs-dev libgpgme-dev
ADD clair-scanner .
ADD clair-scanner-add-podman-support.patch .
RUN patch -p1 < clair-scanner-add-podman-support.patch
RUN go mod tidy
RUN make build

FROM quay.io/coreos/clair:v2.1.8 AS clair

FROM docker.io/postgres:11.14-alpine
ENV PGDATA=/var/lib/postgresql/clair
ENV POSTGRES_PASSWORD=password
COPY --from=clair /clair /clair
COPY clair-local-scan/clair/config.yaml /config/config.yaml
COPY clair-local-scan/clair/gitconfig /etc/gitconfig
COPY supervisord.conf /etc/supervisord.conf
COPY start_clair.sh /usr/local/bin/start_clair.sh
COPY check.sh /tmp/check.sh
COPY --from=clair-scanner-builder /go/src/clair-scanner/clair-scanner /usr/local/bin/
COPY gitlab-report-converter /usr/local/bin/
RUN apk update && \
    apk add --no-cache supervisor git rpm xz wget python3 py3-pip py3-requests podman fuse-overlayfs shadow slirp4netns && \
    sed -i -e 's|#mount_program = |mount_program = |g' /etc/containers/storage.conf && \
    chmod 755 /usr/local/bin/start_clair.sh && \
    sed -i -e 's|host=postgres|host=127.0.0.1|g' /config/config.yaml && \
    mkdir -p /var/log/supervisor && \
    echo "starting supervisord and services" && supervisord -c /etc/supervisord.conf -j /tmp/supervisord.pid && \
    /tmp/check.sh && \
    echo "stopping postgres" && su - postgres -c "pg_ctl -D $PGDATA -m fast -w stop" || true && \
    echo "stopping supervisord" && export SUPERVISORD_PID=$(cat /tmp/supervisord.pid) && kill $SUPERVISORD_PID && while $(kill -0 $SUPERVISORD_PID 2>/dev/null); do sleep 1 ;done || true && \
    rm -f /var/log/supervisor/* && \
    sed -i -e 's|interval: 2h|interval: 0|g' /config/config.yaml
