# Minimal single-node distribution

**Use this when:** building or deploying Mint House's minimal RustFS image, publishing a release, or updating this fork from upstream.

The distribution is based on RustFS 1.0.4, commit `46337942d55f3a8e6a97b147ca98d9ea8115555d`. The container is published as `ghcr.io/mintuhouse/rustfs`. This is a custom fork, not an official RustFS minimal release.

## Supported deployment

The build uses one local persistent directory and ordinary S3 bucket/object operations, authenticated requests and signed URLs. It retains local checksums and fsync. Web UI, admin services, cluster RPC, remote disks, SQL/S3 Select, multipart uploads, lifecycle and replication are omitted. `panic=abort` terminates the process on a panic. Test recovery and compatibility before upgrading existing data.

The image runs as UID/GID 10001:10001 and persists objects in `/data`. Alpine, curl and Tini provide authenticated health checks, bucket initialization and signal handling. Bind mounts must already be writable by that user. Dependency notices, UPX's commercial executable exception and unmodified MPL dependency source are included in `/licenses`.

Set `RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` before starting a container. `RUSTFS_BUCKET` enables idempotent bucket creation in the default `us-east-1` region. Readiness verifies authenticated access to that bucket. Without it, readiness uses `/health/ready`. `RUSTFS_PORT` controls the local port used by initialization and probes and must match the server's `--address` port.

Set upstream `RUSTFS_CORS_ALLOWED_ORIGINS` to the browser application's origin for fetches following signed redirects. Additional origins are comma-separated. CORS does not grant anonymous object access.

```sh
docker run -d --name rustfs-minimal \
  -p 127.0.0.1:9000:9000 \
  -e RUSTFS_ACCESS_KEY -e RUSTFS_SECRET_KEY \
  -e RUSTFS_BUCKET=astralbeam \
  -e RUSTFS_CORS_ALLOWED_ORIGINS=http://localhost:3000 \
  -v rustfs-minimal-data:/data \
  ghcr.io/mintuhouse/rustfs:1.0.4-minimal.1
```

Pin the multi-platform manifest digest in applications. Version tags identify releases, while the `minimal` channel is mutable. Deleting a container preserves a named volume. Deleting that volume destroys its objects. The image is not a backup or a multi-node storage system.

## Branches and upstream maintenance

`main` is an unmodified mirror of upstream. `feat/minimal` is this fork's default product branch. Keep customizations as ordinary focused commits on that branch. Do not keep a second patch file to apply at build time. The Dockerfile builds the checked-out source directly.

A separate product branch is a maintenance choice, not a GitHub requirement. It keeps upstream synchronization distinct from the version we deploy. Published history must not be rebased or force-pushed. Rebase only unpublished working branches when useful.

Configure the public parent as `upstream` once, then update the clean mirror:

```sh
git remote add upstream https://github.com/rustfs/rustfs.git
git fetch upstream --tags
git switch main
git merge --ff-only upstream/main
git push origin main
```

Review a chosen upstream release before bringing it into the product line. Create an update branch from `origin/feat/minimal`, merge that release tag, resolve feature-gate conflicts, and run the focused Rust checks and container smoke test. Review authentication, local durability, unsupported operations and compatibility with existing single-disk data. Merge only after the update passes. Never automatically deploy an upstream synchronization.

The GitHub Sync fork action targets a branch. Use it only for the clean mirror. The product line can deliberately remain on an older tested release while `main` follows upstream.

## Build and verify

Build from this repository's root. Rust, native compiler and UPX build tools remain in the build stage. The first build can take tens of minutes. Later builds can reuse their cache.

```sh
docker build -f deploy/minimal/Dockerfile \
  --build-arg VERSION="$(cat deploy/minimal/VERSION)" \
  --build-arg VCS_REF="$(git rev-parse HEAD)" \
  -t rustfs-minimal .
bash deploy/minimal/smoke.sh rustfs-minimal
```

The smoke test uses an isolated container and volume, then removes both. It tests authenticated PUT/GET, replacement, restart, container recreation on the same volume, CORS, denied anonymous access and deletion. Set `CONTAINER_ENGINE=podman` to use Podman locally.

## Publish a release

The minimal workflow builds and tests AMD64 and ARM64 on native hosted runners. Build jobs have read-only repository permission and no registry credentials. Only the publishing job receives `packages: write` and the repository's temporary `GITHUB_TOKEN`. Third-party actions are pinned to commit SHAs. Only the minimal publishing workflow is enabled in this fork; inherited upstream workflows remain disabled.

Update `deploy/minimal/VERSION` for each release, commit the change to the product line, then publish the matching tag:

```sh
git tag -a "v$(cat deploy/minimal/VERSION)" -m "Release minimal RustFS"
git push origin "v$(cat deploy/minimal/VERSION)"
```

The workflow publishes the versioned tag, `sha-<commit>` and the `minimal` channel only after both architecture tests pass. It refuses to overwrite an existing version tag. A manual run from the product branch refreshes the commit/channel tags without creating a versioned release.

After publication, verify anonymous pull access, both manifest architectures and the exact digest before updating consumers. Keep the previous digest available for rollback. Back up data before upgrades. Image rollback does not undo on-disk format changes.

See [GitHub fork synchronization](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/syncing-a-fork), [GitHub Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) and [Docker's GitHub Actions guidance](https://docs.docker.com/build/ci/github-actions/multi-platform/).
