#!/usr/bin/env bash
# Prepare the upstream source and vendored Go dependencies OUTSIDE Mock.
# Mock only consumes the resulting source RPM and never needs network access.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="${1:-${VERSION:-}}"

if [[ ! "$version" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 VERSION (for example: 2026.10.1)" >&2
  exit 2
fi

for command in cmp curl go gzip mktemp sha256sum tar; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not available on the Jenkins build node: $command" >&2
    exit 1
  fi
done

# Do not silently download a different Go toolchain on the Jenkins node.
# The RPM build uses the Go 1.27+ toolchain supplied by the Mock template.
go_version="$(GOTOOLCHAIN=local go env GOVERSION)"
if [[ ! "$go_version" =~ ^go([0-9]+)\.([0-9]+)(\.[0-9]+)? ]]; then
  echo "Unable to parse the installed Go version: $go_version" >&2
  exit 1
fi
if (( 10#${BASH_REMATCH[1]} < 1 || (10#${BASH_REMATCH[1]} == 1 && 10#${BASH_REMATCH[2]} < 27) )); then
  echo "Go 1.27+ is required on the Jenkins build node; found $go_version" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/cloudflared-vendor.XXXXXXXX")"
trap 'rm -rf -- "$tmp_dir"' EXIT

source_archive="cloudflared-${version}.tar.gz"
vendor_archive="cloudflared-${version}-vendor.tar.gz"
source_url="${CLOUDFLARED_SOURCE_URL:-https://github.com/cloudflare/cloudflared/archive/refs/tags/${version}.tar.gz}"

printf 'Fetching cloudflared %s from %s\n' "$version" "$source_url"
curl --fail --location --retry 3 --retry-delay 2 \
  --output "$tmp_dir/$source_archive" "$source_url"

mkdir -p "$tmp_dir/source"
tar -xzf "$tmp_dir/$source_archive" -C "$tmp_dir/source" --strip-components=1
if [[ ! -s "$tmp_dir/source/go.mod" || ! -s "$tmp_dir/source/go.sum" ]]; then
  echo 'Upstream source archive does not contain go.mod and go.sum' >&2
  exit 1
fi

(
  cd "$tmp_dir/source"
  # Ignore any go.work or GOFLAGS configuration inherited from the agent.
  export GOWORK=off GOTOOLCHAIN=local GOFLAGS=
  cp go.mod "$tmp_dir/original.go.mod"
  cp go.sum "$tmp_dir/original.go.sum"

  echo 'Vendoring Go dependencies (network access permitted on the build node)'
  go mod vendor

  # Packaging must not silently modify the upstream dependency lockfiles.
  cmp -s go.mod "$tmp_dir/original.go.mod" || {
    echo 'go mod vendor modified upstream go.mod' >&2
    exit 1
  }
  cmp -s go.sum "$tmp_dir/original.go.sum" || {
    echo 'go mod vendor modified upstream go.sum' >&2
    exit 1
  }
  test -s vendor/modules.txt || {
    echo 'Vendoring did not produce vendor/modules.txt' >&2
    exit 1
  }

  # Prove that the production command's import graph resolves WITHOUT network.
  echo 'Validating the vendored dependency graph with GOPROXY=off'
  GOPROXY=off GOSUMDB=off go list -mod=vendor -deps ./cmd/cloudflared >/dev/null

  # Stable vendor tarball metadata; -n prevents gzip timestamps/filenames.
  tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -cf - vendor | gzip -n -9 > "$tmp_dir/$vendor_archive"
)

# Only replace outputs after BOTH archives are fully prepared and validated.
mv -f -- "$tmp_dir/$source_archive" "$script_dir/$source_archive"
mv -f -- "$tmp_dir/$vendor_archive" "$script_dir/$vendor_archive"
sha256sum "$script_dir/$source_archive" "$script_dir/$vendor_archive"
