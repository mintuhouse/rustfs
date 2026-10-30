#!/usr/bin/env bash
set -euo pipefail

engine=${CONTAINER_ENGINE:-docker}
image=${1:?container image is required}
name="rustfs-minimal-smoke-$$"
volume="$name-data"
directory=$(mktemp -d)
access="smoke-$$"
secret=$(openssl rand -hex 24)
endpoint=""
cleanup() {
  local status=$?
  if [ "$status" -ne 0 ]; then "$engine" logs "$name" >&2 || true; fi
  "$engine" rm -f "$name" >/dev/null 2>&1 || true
  "$engine" volume rm "$volume" >/dev/null 2>&1 || true
  rm -rf "$directory"
}
trap cleanup EXIT

start() {
  "$engine" run -d --name "$name" -p 127.0.0.1::9000 -v "$volume:/data" \
    -e RUSTFS_ACCESS_KEY="$access" -e RUSTFS_SECRET_KEY="$secret" \
    -e RUSTFS_BUCKET=smoke -e RUSTFS_CORS_ALLOWED_ORIGINS=http://localhost:3000 \
    "$image" >/dev/null
  local port
  port=$("$engine" port "$name" 9000/tcp | head -n 1 | sed 's/.*://')
  endpoint="http://127.0.0.1:$port"
}
ready() {
  for _ in {1..60}; do
    if "$engine" exec "$name" /usr/local/bin/rustfs-healthcheck >/dev/null 2>&1; then return; fi
    sleep 1
  done
  echo "Storage did not become ready" >&2
  return 1
}
s3() {
  curl --fail --silent --show-error --max-time 10 --noproxy '*' \
    --aws-sigv4 aws:amz:us-east-1:s3 --user "$access:$secret" "$@"
}

"$engine" volume create "$volume" >/dev/null
start
ready
dd if=/dev/urandom of="$directory/expected" bs=65536 count=1 status=none
s3 --upload-file "$directory/expected" "$endpoint/smoke/image.png"
s3 "$endpoint/smoke/image.png" --output "$directory/actual"
cmp "$directory/expected" "$directory/actual"
printf 'replacement image bytes\n' > "$directory/expected"
s3 --upload-file "$directory/expected" "$endpoint/smoke/image.png"
"$engine" restart "$name" >/dev/null
ready
s3 "$endpoint/smoke/image.png" --output "$directory/actual"
cmp "$directory/expected" "$directory/actual"
"$engine" rm -f "$name" >/dev/null
start
ready
s3 "$endpoint/smoke/image.png" --output "$directory/actual"
cmp "$directory/expected" "$directory/actual"
s3 -H 'Origin: http://localhost:3000' -D "$directory/headers" \
  "$endpoint/smoke/image.png" --output /dev/null
grep -qi '^access-control-allow-origin: http://localhost:3000' "$directory/headers"
s3 -H 'Origin: https://untrusted.example' -D "$directory/headers" \
  "$endpoint/smoke/image.png" --output /dev/null
if grep -qi '^access-control-allow-origin:' "$directory/headers"; then exit 1; fi
status=$(curl --silent --show-error --noproxy '*' -o /dev/null -w '%{http_code}' "$endpoint/smoke/image.png")
[ "$status" = 403 ]
s3 -X DELETE "$endpoint/smoke/image.png"
status=$(curl --silent --show-error --noproxy '*' --aws-sigv4 aws:amz:us-east-1:s3 \
  --user "$access:$secret" -o /dev/null -w '%{http_code}' "$endpoint/smoke/image.png")
[ "$status" = 404 ]
echo "Minimal RustFS smoke check passed"
