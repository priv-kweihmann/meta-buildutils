# meta-buildutils

| version | build status                                                                                                |
| ------- | :---------------------------------------------------------------------------------------------------------- |
| master  | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[master]-standard/badge.svg)  |
| zeus    | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[zeus]-standard/badge.svg)    |
| warrior | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[warrior]-standard/badge.svg) |
| thud    | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[thud]-standard/badge.svg)    |

A collection of build utils to be used in with YOCTO

## Available classes

| class                | summary                                                                                                   | documentation                        |
| -------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| autoinherit          | inherit bbclasses based on programmable conditions                                                        | [docu](docs/autoinherit.md)          |
| buildutils-helper    | internal collection of helper methods                                                                     | [docu](docs/buildutils-helper.md)    |
| hashdog              | warn about variables in function which corrupt sstate hashing                                             | [docu](docs/hashdog.md)              |
| kconfig-sanity       | check if .cfg-fragements are applied correctly in kconfig-based systems                                   | [docu](docs/kconfig-sanity.md)       |
| layer-sanity         | check that variables are not altered by bbappends                                                         | [docu](docs/layer-sanity.md)         |
| python-package-ident | automatically determine RDEPENDS of python packages                                                       | [docu](docs/python-package-ident.md) |
| python-speedups      | speedup python on the target system using some hackery                                                    | [docu](docs/python-speedups.md)      |
| rm_orphans           | automatically remove obsolete log files from temp-folder                                                  | [docu](docs/rm_orphans.md)           |
| rootfs-chart         | generate dot graphs for a specific image (packages, used recipes)                                         | [docu](docs/rootfs-chart.md)         |
| swinventory          | generate a manifest for each package containing things like used source files, used recipes and much more | [docu](docs/swinventory.md)          |
| swinventory-image    | generate a manifest based on `swinventory` for packages of an image                                       | [docu](docs/swinventory-image.md)    |

## Available scripts

| script        | summary                                                             | documentation                         |
| ------------- | ------------------------------------------------------------------- | ------------------------------------- |
| dot2tree      | create filterable trees from e.g. task-depends.dot                  | [docu](docs/dot2tree.md)              |
| newlayercheck | check a layer for possible corruptions/changes of an existing stack | [docu](docs/scripts-newlayercheck.md) |
| unused        | identify unused recipes in a layer                                  | [docu](docs/scripts-unused.md)        |
