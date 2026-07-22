%define debug_package %{nil}

%define _GOPATH %{_builddir}/%{name}-%{version}/go

Name:           cloudflared
Summary:        Cloudflare DNS-over-HTTPS DNS Proxy
Version:  2026.3.0
Release:        1%{?dist}
Group:          Applications/Network
License:        AGPLv3
Vendor:         cloudflare
URL:            https://github.com/cloudflare/cloudflared
Source:         %{name}-%{version}.tar.gz
Source1:	%{name}.service
AutoReq:        no
BuildRequires:	glibc-devel, glibc-static, golang, systemd-rpm-macros

%description
Command-line client and its libraries for Argo Tunnel, a tunneling daemon that
proxies any local webserver through the Cloudflare network.

#%prep
#%setup -q

%build
export GOPATH=%{_GOPATH}
%{__mkdir_p} %{_GOPATH}/src/github.com/%{vendor}/%{name}
%{__mkdir_p} %{_GOPATH}/bin
tar -C %{_GOPATH}/src/github.com/%{vendor}/%{name} --strip-components=1 -zxf %{SOURCE0}

#go get -v github.com/%{vendor}/%{name}

pushd %{_GOPATH}/src/github.com/%{vendor}/%{name}
	%{__make} %{?_smp_mflags} LINK_FLAGS="-s -w" %{name}
	%{__mv} %{name} %{_GOPATH}/bin/
popd

#%{__cp} %{_GOPATH}/src/github.com/percona/node_exporter/example.prom		%{_GOPATH}/

%install
pushd %{_GOPATH}
%{__mkdir_p} %{buildroot}/%{_sbindir}
install -m 0755 bin/%{name} %{buildroot}/%{_sbindir}/%{name}
%{__mkdir_p} %{buildroot}/%{_unitdir}
install -m 644 %{SOURCE1} %{buildroot}/%{_unitdir}/%{name}.service

%clean
rm -rf %{buildroot}

%files
%{_sbindir}/%{name}
%{_unitdir}/%{name}.service

%changelog
