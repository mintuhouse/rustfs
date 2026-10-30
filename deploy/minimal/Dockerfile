# syntax=docker/dockerfile:1
FROM rust:1.99.1-alpine3.23 AS build
RUN apk add --no-cache build-base clang cmake curl git linux-headers perl protobuf-dev python3
WORKDIR /src
COPY Cargo.toml Cargo.lock rust-toolchain.toml rustfmt.toml LICENSE ./
COPY .cargo .cargo/
COPY crates crates/
COPY rustfs rustfs/
COPY protocol protocol/
ENV RUSTUP_TOOLCHAIN=1.99.1 CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_BUILD_JOBS=4
RUN mkdir -p rustfs/static && cargo build --release --locked -p rustfs --bin rustfs --no-default-features
# Use the unmodified upstream packer and retain its commercial executable exception.
RUN curl -fsSL https://github.com/upx/upx/releases/download/v5.3.0/upx-5.3.0-src.tar.xz -o /tmp/upx.tar.xz \
    && echo "6229b5564dd91dd423a5280a7c15b70fc05449d2605bb853ce076743057fcf55  /tmp/upx.tar.xz" | sha256sum -c - \
    && mkdir /tmp/upx-src \
    && tar -xJf /tmp/upx.tar.xz -C /tmp/upx-src --strip-components=1 \
    && cmake -S /tmp/upx-src -B /tmp/upx-build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/upx-build --parallel 4 \
    && /tmp/upx-build/upx --best --lzma target/release/rustfs \
    && /tmp/upx-build/upx -t target/release/rustfs
COPY deploy/minimal/collect-licenses.py /tmp/collect-licenses.py
RUN python3 /tmp/collect-licenses.py

FROM alpine:3.23
ARG VERSION=dev
ARG VCS_REF=unknown
# Compose needs SigV4 bucket provisioning and an HTTP readiness probe. Tini reaps the startup helper.
RUN apk add --no-cache ca-certificates curl tini \
    && addgroup -g 10001 rustfs \
    && adduser -D -H -u 10001 -G rustfs rustfs \
    && mkdir /data && chown 10001:10001 /data
COPY --from=build /src/target/release/rustfs /usr/local/bin/rustfs
COPY --from=build /licenses /licenses
COPY --chmod=755 deploy/minimal/entrypoint.sh /usr/local/bin/rustfs-entrypoint
LABEL org.opencontainers.image.source="https://github.com/mintuhouse/rustfs" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$VCS_REF"
ENV RUSTFS_ADDRESS=:9000 RUSTFS_CONSOLE_ENABLE=false
USER 10001:10001
EXPOSE 9000
VOLUME ["/data"]
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s CMD if [ -n "$RUSTFS_BUCKET" ]; then \
    curl -fsSI --aws-sigv4 "aws:amz:${RUSTFS_REGION:-us-east-1}:s3" --user "$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY" "http://127.0.0.1:${RUSTFS_ADDRESS##*:}/$RUSTFS_BUCKET"; \
    else curl -fsS "http://127.0.0.1:${RUSTFS_ADDRESS##*:}/health/ready"; fi
ENTRYPOINT ["/usr/local/bin/rustfs-entrypoint"]
CMD ["/data"]
