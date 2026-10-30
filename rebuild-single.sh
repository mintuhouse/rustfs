#!/bin/sh
set -eu
# Run in the supplied RustFS source directory. Rust 1.99.1 was used for the measured artifacts.
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z
export CARGO_PROFILE_RELEASE_LTO=fat
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_PANIC=abort
export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_INCREMENTAL=0
if [ "$#" -eq 0 ]; then
  cargo build --release --locked -p rustfs --bin rustfs-single --no-default-features --features single-node-narrow
else
  cargo zigbuild --release --locked --target "$1" -p rustfs --bin rustfs-single --no-default-features --features single-node-narrow
fi
