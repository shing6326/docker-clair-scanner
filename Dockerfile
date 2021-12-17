FROM docker.io/library/golang:1.16-bullseye AS builder
WORKDIR /go/src/clair-scanner
RUN apt-get update -y && apt-get install -y build-essential liblvm2-dev libbtrfs-dev libgpgme-dev
ADD clair-scanner .
ADD clair ./clair
ADD clair-scanner-add-podman-support.patch .
ADD clair-remove-usage-of-deprecated-handler.patch .
RUN patch -p1 < clair-scanner-add-podman-support.patch && patch -p0 < clair-remove-usage-of-deprecated-handler.patch
RUN cd ./clair && \
    go mod init && \
    go mod tidy
RUN make build

FROM quay.io/podman/stable
RUN dnf install -y iproute && \
    touch clair-whitelist.yml
COPY --from=builder /go/src/clair-scanner/clair-scanner /usr/local/bin
