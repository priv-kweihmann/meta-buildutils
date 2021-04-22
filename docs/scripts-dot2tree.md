# dot2tree

A scripts that converts graphs like task-depends.dot into filterable tree printed to console

## Usage

```shell
usage: dot2tree [-h] [--mode {taskdepends,pkgdepend}] [--nosimplify] root endnode input

print nice trees out of bitbake information

positional arguments:
  root                  Name of the root node or path to an image manifest
  endnode               Stop tree at
  input                 Path to input files [depends on mode selected]

optional arguments:
  -h, --help            show this help message and exit
  --mode {taskdepends,pkgdepend}
                        mode to operate in (default: taskdepends)
  --nosimplify          Do not merge overlaping paths (default: False)
```

### Example output

`dot2tree systemd dbus task-depends.dot`

returns

```shell
systemd
├── systemd-compat-units
│   └── dbus
└── dbus
```

`dot2tree --mode=pkgdepend python3-core ncurses-libtinfo /path/to/your/workspace/tmp/pkgdata/<arch>/runtime-reverse`

returns

```shell
python3-core
└── readline
    └── ncurses-libtinfo
```

`dot2tree --mode=pkgdepend /path/to/your/workspace/tmp/deploy/images/<arch>/<image name>.manifest dbus-tools /path/to/your/workspace/tmp/pkgdata/<arch>/runtime-reverse`

returns

```shell
packagegroup-core-boot
└── systemd
    └── dbus
        └── dbus-tools
systemd
└── dbus
    └── dbus-tools
systemd-compat-units
└── systemd
    └── dbus
        └── dbus-tools
systemd-extra-utils
└── systemd
    └── dbus
        └── dbus-tools
systemd-vconsole-setup
└── systemd
    └── dbus
        └── dbus-tools
```