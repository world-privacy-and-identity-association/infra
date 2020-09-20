# infra/packer

## Description

Packer provide an minimal Debian image which can be used to install the
required puppet modules. The image provided should be used for continues
integration and development.

At the moment it only builds with and for QEMU.

## Requirements

- [Bash](https://www.gnu.org/software/bash)
- [Packer](https://packer.io)
- [QEMU](https://www.qemu.org)

## Building

Verify which Debian version you would like to use.

``` sh
$ cd debian-${DEBIAN_VERSION}
$ packer build packer.json
```

## Login

Default username and password is generated and should be changed if it's
not used for development.

- username: `wpia`
- password: `wpia`
