Packaging cloudflared

## Layout

```text
cloudflared-packaging/
├── README.md
├── Jenkinsfile.watcher
├── Jenkinsfile.build
├── keys/
│   └── RPM-GPG-KEY-cloudflared.pub
└── rpmbuild/
    ├── SOURCES/
    │   ├── cloudflared.service
    │   └── prep-cloudflared.sh
    └── SPECS/
        └── cloudflared.spec
```

The non-secret RPM public key is stored in this repository and is used to
validate signed RPMs and publish the repository key. The private signing key
and its passphrase remain protected by Jenkins credentials.

## Network-independent Mock builds

The Jenkins build node must have network access, `curl`, GNU `tar`, `gzip`, and
Go **1.27 or later**. The Mock template must be `alma+epel+go-10-x86_64`, with
Go 1.27+ installed inside Mock too. The host Go toolchain is required to
**prepare** the vendor archive; the Mock Go toolchain **compiles** the RPM.

The pipeline runs `rpmbuild/SOURCES/prep-cloudflared.sh VERSION` *outside Mock*.
It downloads the upstream release archive and runs `go mod vendor`, validates
that the manifest is complete using `GOPROXY=off go list -mod=vendor`, and
creates two archives in the SOURCES directory:

- `cloudflared-VERSION.tar.gz` (upstream source, unmodified)
- `cloudflared-VERSION-vendor.tar.gz` (contains the top-level `vendor/` directory)

Both archives are embedded in the **source RPM**. `%prep` unpacks them into
the same module root; `%build` invokes `go build -mod=vendor -buildvcs=false`
with `GOPROXY=off`, `GOSUMDB=off`, and `GOTOOLCHAIN=local` to fail closed if any
dependency is missing. The upstream Makefile must **not** be used for this
operation because its build target hardcodes `-mod=readonly` and reads Git
metadata that is unavailable in the release archive.

For manual source preparation on a networked Go 1.27+ build host:

```bash
./rpmbuild/SOURCES/prep-cloudflared.sh 2026.10.1
```

Do not check generated source/vendor tarballs into Git. Prepare them per
upstream version, then build the SRPM with the current RPM spec as the pipeline
does. A standalone Mock rebuild of the same SRPM needs no Go dependency
network access (normal Mock package installation still needs configured RPM
repositories or their caches).

Optional: set `CLOUDFLARED_SOURCE_URL` when using a trusted internal source
mirror. It must serve the same upstream release archive.

When upgrading versions, regenerate the vendor tarball from that release. Do
not reuse one created from a previous version's `go.mod` and `go.sum`.
