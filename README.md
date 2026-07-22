Packaging cloudflared

## Layout

~~~~ {.text}
cloudflared-packaging/
├── README.md
├── Jenkinsfile.watcher
├── Jenkinsfile.build
├── keys/
│   └── RPM-GPG-KEY-cloudflared.pub
└── rpmbuild/
    ├── SOURCES/
    │   └── cloudflared.service
    └── SPECS/
        └── cloudflared.spec
~~~~

The non-secret RPM public key is stored in this repository and is used to
validate signed RPMs and publish the repository key. The private signing key
and its passphrase remain protected by Jenkins credentials.
