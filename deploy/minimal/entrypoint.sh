#!/bin/sh
set -eu
: "${RUSTFS_ACCESS_KEY:?RUSTFS_ACCESS_KEY is required}"
: "${RUSTFS_SECRET_KEY:?RUSTFS_SECRET_KEY is required}"

if [ -n "${RUSTFS_BUCKET:-}" ]; then
  server_pid=$$
  (
    endpoint="http://127.0.0.1:${RUSTFS_ADDRESS##*:}"
    s3() {
      curl --fail --silent --show-error --max-time 5 \
        --aws-sigv4 "aws:amz:${RUSTFS_REGION:-us-east-1}:s3" \
        --user "$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY" "$@"
    }
    if ! { curl -fsS --retry 30 --retry-all-errors --retry-delay 1 --retry-max-time 60 --max-time 5 \
        "$endpoint/health/ready" >/dev/null && \
        { s3 --head "$endpoint/$RUSTFS_BUCKET" >/dev/null 2>&1 || s3 --request PUT "$endpoint/$RUSTFS_BUCKET"; }; }; then
      echo "RustFS bucket initialization failed" >&2
      kill -TERM "$server_pid"
    fi
  ) &
fi

exec /sbin/tini -- /usr/local/bin/rustfs "$@"
