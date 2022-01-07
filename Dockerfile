FROM docker.io/shing6326/clair-local-scan AS clair-local-scan
FROM docker.io/postgres:11.6-alpine
COPY --from=clair-local-scan /clair /clair
COPY --from=clair-local-scan /config/config.yaml /config/config.yaml
COPY supervisord.conf /etc/supervisord.conf
COPY start_clair.sh /usr/local/bin/start_clair.sh
COPY check.sh /tmp/check.sh
RUN apk update && \
    apk add --no-cache supervisor git rpm && \
    chmod 755 /usr/local/bin/start_clair.sh && \
    sed -i -e 's|host=postgres|host=127.0.0.1|g' /config/config.yaml && \
    mkdir -p /var/log/supervisor && \
    /usr/bin/supervisord -c /etc/supervisord.conf && \
    /tmp/check.sh

FROM docker.io/library/golang:1.16-bullseye AS clair-scanner-builder
WORKDIR /go/src/clair-scanner
RUN apt-get update -y && apt-get install -y build-essential liblvm2-dev libbtrfs-dev libgpgme-dev
ADD clair-scanner .
ADD clair-scanner-add-podman-support.patch .
RUN patch -p1 < clair-scanner-add-podman-support.patch
RUN go mod tidy
RUN make build





FROM quay.io/podman/stable
RUN dnf install -y iproute findutils python-requests && \
    dnf clean all && \
    rm -rf /var/cache/yum
COPY --from=clair-scanner-builder /go/src/clair-scanner/clair-scanner /usr/local/bin/
ADD gitlab-report-converter /usr/local/bin/
