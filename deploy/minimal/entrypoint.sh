#!/bin/sh
set -eu

if [ -n "${RUSTFS_BUCKET:-}" ]; then
  server_pid=$$
  (
    if ! curl --fail --silent --show-error --retry 30 --retry-all-errors --retry-delay 1 \
      --retry-max-time 60 --max-time 5 --aws-sigv4 "aws:amz:${RUSTFS_REGION:-us-east-1}:s3" \
      --user "$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY" --request PUT \
      "http://127.0.0.1:${RUSTFS_PORT:-9000}/$RUSTFS_BUCKET"; then
      echo "RustFS bucket initialization failed" >&2
      kill -TERM "$server_pid"
    fi
  ) &
fi

exec /usr/local/bin/rustfs-single "$@"
