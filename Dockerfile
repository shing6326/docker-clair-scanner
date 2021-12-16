FROM docker.io/library/golang:1.16-bullseye AS builder
WORKDIR /go/src/clair-scanner
RUN apt-get update -y && apt-get install -y build-essential liblvm2-dev libbtrfs-dev libgpgme-dev
ADD clair-scanner .
ADD clair ./clair
ADD clair-scanner-add-podman-support.patch .
ADD clair-remove-usage-of-deprecated-handler.patch .
RUN patch -p1 < clair-scanner-add-podman-support.patch && patch -p0 < clair-remove-usage-of-deprecated-handler.patch
RUN cd ./clair && go mod init && go mod tidy
RUN go mod tidy && go build

FROM docker.io/library/debian:bullseye
RUN apt-get update -y && apt-get install -y fuse-overlayfs iproute2 podman buildah skopeo containers-storage

RUN useradd podman; \
echo podman:10000:5000 > /etc/subuid; \
echo podman:10000:5000 > /etc/subgid;

ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/podman/.config/containers/containers.conf

RUN mkdir -p /home/podman/.local/share/containers; chown podman:podman -R /home/podman

# Note VOLUME options must always happen after the chown call above
# RUN commands can not modify existing volumes
VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /usr/share/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

COPY --from=builder /go/src/clair-scanner/clair-scanner /usr/local/bin
