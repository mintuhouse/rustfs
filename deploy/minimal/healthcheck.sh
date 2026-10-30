#!/bin/sh
set -eu

endpoint="http://127.0.0.1:${RUSTFS_PORT:-9000}"
if [ -n "${RUSTFS_BUCKET:-}" ]; then
  exec curl --fail --silent --show-error --max-time 4 \
    --aws-sigv4 "aws:amz:${RUSTFS_REGION:-us-east-1}:s3" \
    --user "$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY" --head "$endpoint/$RUSTFS_BUCKET"
fi
exec curl --fail --silent --show-error --max-time 4 "$endpoint/health/ready"
