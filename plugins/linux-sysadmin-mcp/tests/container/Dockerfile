FROM fedora:43
ENV container=docker

# Services for testing all 15 tool modules (systemd must be installed first)
RUN dnf -y install \
    systemd procps-ng iproute net-tools bind-utils hostname \
    util-linux findutils diffutils which file lsof \
    openssh-server openssh-clients \
    nginx \
    cronie \
    firewalld \
    shadow-utils sudo \
    dnf-utils \
    nodejs \
    rsyslog \
    && dnf clean all

# Minimal systemd — remove unnecessary sysinit targets
# Fedora 43 uses /usr/lib/systemd/system/ (not /lib/systemd/system/)
RUN (cd /usr/lib/systemd/system/sysinit.target.wants/ 2>/dev/null && \
     for i in *; do [ "$i" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done) || true && \
    rm -f /usr/lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /usr/lib/systemd/system/local-fs.target.wants/* && \
    rm -f /usr/lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /usr/lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /usr/lib/systemd/system/basic.target.wants/*

# Test user with passwordless sudo
RUN useradd -m testadmin && \
    echo "testadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testadmin && \
    chmod 440 /etc/sudoers.d/testadmin

# Enable services that tools expect
RUN systemctl enable sshd nginx crond firewalld rsyslog

# Generate SSH host keys
RUN ssh-keygen -A

VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
