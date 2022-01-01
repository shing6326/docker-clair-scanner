FROM docker.io/library/golang:1.16-bullseye AS builder
WORKDIR /go/src/clair-scanner
RUN apt-get update -y && apt-get install -y build-essential liblvm2-dev libbtrfs-dev libgpgme-dev
ADD clair-scanner .
ADD clair ./clair
ADD clair-scanner-add-podman-support.patch .
RUN patch -p1 < clair-scanner-add-podman-support.patch
RUN cd ./clair && \
    go mod tidy && \
    make build

FROM quay.io/podman/stable
RUN dnf install -y iproute findutils python-requests && \
    dnf clean all && \
    rm -rf /var/cache/yum
COPY --from=builder /go/src/clair-scanner/clair-scanner /usr/local/bin/
ADD gitlab-report-converter /usr/local/bin/
