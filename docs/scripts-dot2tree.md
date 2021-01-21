# dot2tree

A scripts that converts graphs like task-depends.dot into filterable tree printed to console

## Usage

```shell
dot2tree <root-node> <end-node> <input file>
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
