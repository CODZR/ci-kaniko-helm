ARG MIRROR_REGISTRY=2c9ttmy29gq3er.xuanyuan.run
ARG GOLANG_IMAGE=${MIRROR_REGISTRY}/golang:1.22-alpine
ARG ALPINE_IMAGE=${MIRROR_REGISTRY}/alpine:3.20
ARG KANIKO_VERSION=v1.23.2

FROM --platform=$BUILDPLATFORM ${GOLANG_IMAGE} AS kaniko-build
ARG KANIKO_VERSION
ARG TARGETOS
ARG TARGETARCH
ENV GO111MODULE=on GOFLAGS=-mod=vendor
WORKDIR /kaniko-src
COPY deps/kaniko-*.tar.gz /tmp/
RUN KANIKO_SRC_VERSION="${KANIKO_VERSION#v}" \
    && mkdir -p /kaniko-src \
    && tar -zxf "/tmp/kaniko-${KANIKO_SRC_VERSION}.tar.gz" --strip-components=2 -C /kaniko-src \
    && CGO_ENABLED=0 GOOS="${TARGETOS:-linux}" GOARCH="${TARGETARCH:-amd64}" go build -o /kaniko/executor ./cmd/executor

ARG TARGETARCH

FROM ${ALPINE_IMAGE}

ARG TARGETARCH
ARG HELM_VERSION=v3.15.4
ARG HELM_BASE_URL=https://get.helm.sh
ARG APK_REPO_BASE=https://mirrors.aliyun.com/alpine
ARG APK_REPO_VERSION=v3.20

ENV HELM_VERSION=${HELM_VERSION} \
    CHART_SCRIPT=/usr/local/bin/chart_build

COPY --from=kaniko-build /kaniko/executor /usr/local/bin/kaniko

RUN printf '%s\n' \
    "${APK_REPO_BASE}/${APK_REPO_VERSION}/main" \
    "${APK_REPO_BASE}/${APK_REPO_VERSION}/community" \
    > /etc/apk/repositories

RUN apk add bash ca-certificates curl tar \
    && update-ca-certificates

RUN set -eu; \
    case "${TARGETARCH:-amd64}" in amd64|arm64) helm_arch="${TARGETARCH:-amd64}" ;; *) echo "Unsupported TARGETARCH: ${TARGETARCH:-}" >&2; exit 3 ;; esac; \
    curl -fsSL -o /tmp/helm.tgz "${HELM_BASE_URL}/helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz"; \
    tar -zx --strip-components=1 -C /usr/local/bin -f /tmp/helm.tgz "linux-${helm_arch}/helm"; \
    rm -f /tmp/helm.tgz; \
    chmod +x /usr/local/bin/helm /usr/local/bin/kaniko

COPY scripts/chart_build.sh ${CHART_SCRIPT}
RUN chmod +x ${CHART_SCRIPT}

ENTRYPOINT ["/bin/bash"]
