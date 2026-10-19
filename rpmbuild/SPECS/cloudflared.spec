%define debug_package %{nil}


Name:           cloudflared
Summary:        Cloudflare DNS-over-HTTPS DNS Proxy
Version:        2026.3.0
Release:        1%{?dist}
Group:          Applications/Network
License:        AGPLv3
Vendor:         cloudflare
URL:            https://github.com/cloudflare/cloudflared
Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}.service
# Vendored Go modules are prepared on the networked Jenkins node.
Source2:        %{name}-%{version}-vendor.tar.gz
AutoReq:        no
BuildRequires:  gcc, glibc-devel, glibc-static, golang >= 1.27, systemd-rpm-macros

%description
Command-line client and its libraries for Argo Tunnel, a tunneling daemon that
proxies any local webserver through the Cloudflare network.

%prep
# Extract upstream sources and the vendor/ directory at the module root.
%setup -q -a 2
test -s vendor/modules.txt

%build
# Enforce an offline, reproducible Go build. In particular, do not run the
# upstream Makefile: its cloudflared target hardcodes -mod=readonly and calls git
# (which is absent from source tarballs and need not be installed in Mock).
export GOTOOLCHAIN=local
export GOPROXY=off
export GOSUMDB=off
export GOWORK=off
export GOFLAGS=
export GOFIPS140=off
export CGO_ENABLED=1
export GOOS=linux GOARCH=amd64

# Mirror the upstream version/build-time linker variables without needing git.
build_time="$(date -u -r RELEASE_NOTES '+%Y-%m-%d-%H:%M UTC')"
go build -mod=vendor -buildvcs=false -trimpath \
  -ldflags "-s -w -X main.Version=%{version} -X 'main.BuildTime=${build_time}'" \
  -o cloudflared ./cmd/cloudflared

%install
install -D -p -m 0755 cloudflared %{buildroot}%{_sbindir}/%{name}
install -D -p -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/%{name}.service

%files
%{_sbindir}/%{name}
%{_unitdir}/%{name}.service

%changelog
