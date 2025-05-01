#!/bin/bash -ex

BIN_DIR="/rootfs/usr/local/bin"
CONFIG_DIR="/rootfs/etc/containerd"

wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc.sha512
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/containerd-shim-runsc-v1
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/containerd-shim-runsc-v1.sha512

sha512sum -c runsc.sha512 -c containerd-shim-runsc-v1.sha512 \
  && rm -f *.sha512

chmod a+rx runsc containerd-shim-runsc-v1

cp runsc ${BIN_DIR}
cp containerd-shim-runsc-v1 ${BIN_DIR}

cat << 'EOF' | sudo tee -a ${CONFIG_DIR}/config.toml > /dev/null

[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
