ARG KANIKO_VERSION=v1.23.2

FROM golang:1.22-alpine AS golang-base

FROM golang-base AS kaniko-build
ARG KANIKO_VERSION
ENV GO111MODULE=on GOFLAGS=-mod=vendor
WORKDIR /kaniko-src
COPY deps/kaniko-*.tar.gz /tmp/
RUN KANIKO_SRC_VERSION="${KANIKO_VERSION#v}" \
    && mkdir -p /kaniko-src \
    && tar -zxf "/tmp/kaniko-${KANIKO_SRC_VERSION}.tar.gz" --strip-components=2 -C /kaniko-src \
    && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /kaniko/executor ./cmd/executor

FROM alpine:3.20 AS alpine-base

FROM alpine-base

ARG KANIKO_VERSION
ENV KANIKO_VERSION=${KANIKO_VERSION} \
    HELM_VERSION=v3.15.4 \
    CHART_SCRIPT=/usr/local/bin/chart_build

COPY deps/apk-cache/ /var/cache/apk/
COPY deps/ /tmp/deps/
COPY --from=kaniko-build /kaniko/executor /usr/local/bin/kaniko

RUN apk add --no-network --allow-untrusted /var/cache/apk/*.apk \
    && tar -zx --strip-components=1 -C /usr/local/bin -f \
        /tmp/deps/helm-${HELM_VERSION}-linux-amd64.tar.gz linux-amd64/helm \
    && chmod +x /usr/local/bin/helm \
    && chmod +x /usr/local/bin/kaniko \
    && rm -rf /tmp/deps /var/cache/apk

COPY scripts/chart_build.sh ${CHART_SCRIPT}
RUN chmod +x ${CHART_SCRIPT}

ENTRYPOINT ["/bin/bash"]
