# dot2tree

A scripts that converts graphs like task-depends.dot or package information into filterable tree printed to console.
For it to work you will need

- anytree installed (``pip install anytree``)
- a populated bitbake build
- **for task-depends**: a dot file of your target (``bitbake -g <target>``)

## Usage

```shell
usage: oetree [-h] [--mode {taskdepends,pkgdepend}] [--endnode ENDNODE] [--renderdepth RENDERDEPTH] input root

print nice trees out of bitbake information

positional arguments:
  input                 Path to input files [depends on mode selected]
  root                  Name of the root node or path to an image manifest

options:
  -h, --help            show this help message and exit
  --mode {taskdepends,pkgdepend}
                        mode to operate in (default: taskdepends)
  --endnode ENDNODE     Stop tree at (default: None)
  --renderdepth RENDERDEPTH
                        Limit render depth (default: 1000000000)
```

### Example output

`oetree --mode=taskdepends --endnode=kern-tools-native task-depends.dot core-image-minimal`

returns

```shell
core-image-minimal
└── busybox
    └── kern-tools-native
```

`oetree --mode=pkgdepend /path/to/build-dir/tmp/pkgdata/<arch>/runtime-reverse/runtime-reverse ncurses-libtinfo`

returns

```shell
ncurses-libtinfo
├── glibc [4.2M - 5.2M]
│   └── ldconfig [949.0k - 949.0k]
└── ncurses-terminfo-base [25.8k - 25.8k]
```

**NOTE** the numbers in the brackets are the size of the package plus the summed up size of all packages required to be installed with it

`oetree --mode=pkgdepend --endnode=python3-core /path/to/build-dir/tmp/pkgdata/<arch>/runtime-reverse/runtime-reverse python3-math`

returns
```shell
python3-math
└── python3-core [5.6M - 11.5M]
    └── python3-compression [232.3k - 5.8M]
        └── python3-core [5.6M - 5.6M]
```

`oetree --mode=pkgdepend /path/to/build-dir/tmp/pkgdata/<arch>/runtime-reverse/runtime-reverse /path/to/build-dir/tmp/deploy/images/<arch>/<imagename>.rootfs.manifest`

returns

```shell
<imagename>.rootfs.manifest
├── base-files [4.0k - 4.0k]
├── base-passwd [0.0 - 0.0]
├── busybox [651.7k - 5.8M]
│   ├── busybox-udhcpc [2.7k - 2.7k]
│   ├── glibc [4.2M - 5.2M]
│   │   └── ldconfig [949.0k - 949.0k]
│   └── update-alternatives-opkg [4.6k - 4.6k]
├── busybox-hwclock [2.5k - 8.7k]
│   └── update-rc.d [6.2k - 6.2k]
├── busybox-syslog [4.2k - 5.8M]
│   ├── busybox [651.7k - 5.8M]
│   │   ├── busybox-udhcpc [2.7k - 2.7k]
│   │   ├── glibc [4.2M - 5.2M]
│   │   │   └── ldconfig [949.0k - 949.0k]
│   │   └── update-alternatives-opkg [4.6k - 4.6k]
...
```

`oetree --mode=pkgdepend --renderdepth=2 /path/to/build-dir/tmp/pkgdata/<arch>/runtime-reverse/runtime-reverse /path/to/build-dir/tmp/deploy/images/<arch>/<imagename>.rootfs.manifest`

returns

```shell
<imagename>.rootfs.manifest
├── bad-systemd [104.0 - 104.0]
├── base-files [4.0k - 4.0k]
├── base-passwd [0.0 - 0.0]
├── busybox [651.7k - 5.8M]
├── busybox-hwclock [2.5k - 8.7k]
├── busybox-syslog [4.2k - 5.8M]
├── dbus-1 [339.1k - 477.1M]
├── e2fsprogs-e2fsck [352.2k - 42.9M]
├── init-ifupdown [2.8k - 27.3k]
├── initscripts-functions [2.1k - 2.1k]
├── kbd [831.3k - 6.0M]
├── kbd-consolefonts [456.5k - 456.5k]
├── kbd-keymaps [554.9k - 556.9k]
├── kernel-6.12.8-yocto-tiny [62.8k - 62.8k]
├── kernel-image-6.12.8-yocto-tiny [0.0 - 0.0]
├── kernel-image-bzimage-6.12.8-yocto-tiny [3.8M - 3.8M]
...
```
