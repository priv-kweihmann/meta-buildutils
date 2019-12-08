# meta-buildutils <!-- omit in toc -->

| version | build status                                                                                                |
|---------|:------------------------------------------------------------------------------------------------------------|
| master  | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[master]-standard/badge.svg)  |
| zeus    | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[zeus]-standard/badge.svg)    |
| warrior | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[warrior]-standard/badge.svg) |
| thud    | ![Nightly status](https://github.com/priv-kweihmann/meta-buildutils/workflows/[thud]-standard/badge.svg)    |

A collection of build utils to used in with YOCTO

## Table of content <!-- omit in toc -->

- [auto-inherit](#auto-inherit)
  - [Purpose](#purpose)
  - [Usage](#usage)
  - [Configuration](#configuration)
    - [Available builtin function](#available-builtin-function)
      - [auto_inherit_contains_package](#auto_inherit_contains_package)
      - [auto_inherit_is_at_path](#auto_inherit_is_at_path)
      - [auto_inherit_license](#auto_inherit_license)
      - [auto_inherit_has_source](#auto_inherit_has_source)
  - [Examples](#examples)
- [python-speedups](#python-speedups)
  - [Purpose](#purpose-1)
  - [Usage](#usage-1)
  - [Configuration](#configuration-1)
- [kconfig-sanity](#kconfig-sanity)
  - [Purpose](#purpose-2)
  - [Usage](#usage-2)
  - [Configuration](#configuration-2)
  - [Remarks](#remarks)
- [layer-sanity](#layer-sanity)
  - [Purpose](#purpose-3)
  - [Usage](#usage-3)
  - [Configuration](#configuration-3)
  - [Examples](#examples-1)
- [buildutils-helper](#buildutils-helper)
  - [Purpose](#purpose-4)
  - [Usage](#usage-4)
- [python-package-ident](#python-package-ident)
  - [Purpose](#purpose-5)
  - [Usage](#usage-5)
- [rm_orphans](#rm_orphans)
  - [Usage](#usage-6)

## auto-inherit

### Purpose

With the help of this class you can dynamically inherit other classes into any recipe based on conditions

### Usage

You can either insert

```bitbake
INHERIT += "auto-inherit.bbclass"
```

into your __distro configuration__ or into __conf/local.conf__ of your build directory

### Configuration

Configuration is done by bitbake variable __AUTO_INHERIT_CONF__.
It is a space separated list of items (see below).
Best is to place this variable along the inherit.
E.g.

```bitbake
INHERIT += "auto-inherit.bbclass"
AUTO_INHERIT_CONF = "BBClass=foo;props[a,b,c]"
```

each value is formatted in the following way

```bitbake
BBClass=<class>;props=[func_foo(d),func_foo2(d,param)]
```

The identifier __BBClass__ specifies what other bbclass to be included.
The __props__ identifier specifies a list of python-function, which all must return **true** for the class at __BBClass__ to become included into the recipe currently parsed.

#### Available builtin function

##### auto_inherit_contains_package

Checks if the current recipe **DEPENDS** on another package.
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __pn__ [string] for the package-name to be checked for
- __skipNative__ [bool:True] for ignoring -native packages on lookup

##### auto_inherit_is_at_path

Checks if the current recipe is located at a certain path (or below) relative to project root
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __path__ [string] path to check for
- __skip_bbappend__ [bool:True] for ignoring bbappend-files on lookup

##### auto_inherit_license

Checks if a recipe is published under a particular license
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __license_regex__ [regex] regular expression describing the license to check for

##### auto_inherit_has_source

Checks if the recipe contains specific resources in it's **SRC_URI** entry

- __d__ [object] for the current data-storage of bitbake
- __source_regex__ [regex] regular expression describing the entries to check for

### Examples

```bitbake
AUTO_INHERIT_CONF = "BBClass=foo;props=[auto_inherit_is_at_path(d,'meta-foo/recipes-foo/',False)]"
```

will inherit **foo.bbclass** into each recipe (and bbappend) placed under __meta-foo/recipes-foo/__

```bitbake
AUTO_INHERIT_CONF = "BBClass=bar;props=[auto_inherit_license(d,'GPL.*')]"
```

will inherit **bar.bbclass** into each recipe licensed under "GPL" (including all variants like GPLv2, GPLv3, a.s.o.)

```bitbake
AUTO_INHERIT_CONF = "BBClass=bar;props=[auto_inherit_contains_package(d,'python3')]"
```

will inherit **bar.bbclass** into each recipe which __DEPENDS__ of **python3**

## python-speedups

### Purpose

This class does try to improve the startup speed of the deployed python-interpreter by doing some tweaks.
There is a [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) which explains the background a little more in detail.
You can expect between 10-25% speedup of startup time, without the need to change any code.

### Usage

Just inherit the class into the **image-recipe** you want to tune

### Configuration

The tuneup amount can be controlled by variable __PYTHON_SPEEDUP_TARGETS__.
This variable is a space separated list which can contain the following items

- __compile_all__ - This forces a python-compiler run on the rootfs. Very useful when you have a readonly filesystem on your target
- __binary_tweak__ - This patches the python-CLI options. See [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) for details
- __no_sitepackage__ - This disables the usage of side-packages by integrating them into the standard lib

## kconfig-sanity

### Purpose

This class does check if __*.cfg__ fragments of KConfig-based systems are applied to resulting configuration.
It also tries to provide information why a particular __CONFIG__-option can't be applied.
This is very helpful when upgrading a system.
Also this class offers methods for comparing the actual used configuration against a known configuration in repository.

### Usage

Just inherit the class into any recipe using KConfig.
Stock recipes are **busybox**, **linux-yocto**, **u-boot**.

### Configuration

Following configuration variables can be used. All variables have reasonable default values, so you actually only have to alter things when needed

- **KCONFIG_SANITY_BLACKLIST** [string] - List of __CONFIG__-options to ignore on checkup
- **KCONFIG_SANITY_COMPAREFILES** [string] - List of files which will be compared to resulting configuration. Leave empty to disable **complete**-mode
- **KCONFIG_SANITY_COMPLETE_NEW_SET**  [note,warn,error] - Logger function to trigger if a new and set value has been detected in **complete**-mode
- **KCONFIG_SANITY_COMPLETE_NEW_UNSET** [note,warn,error] - Logger function to trigger if a new but unset value has been detected in **complete**-mode
- **KCONFIG_SANITY_COMPLETE_NO_MATCH** [note,warn,error] - Logger function to trigger if a value has changed in **complete**-mode
- **KCONFIG_SANITY_COMPLETE_OLD_NA** [note,warn,error] - Logger function to trigger if a value has been set previously but is now absent due to missing KConfig in **complete**-mode
- **KCONFIG_SANITY_COMPLETE_OLD_UNSET_EXISTS** [note,warn,error] - Logger function to trigger if a value has been set previously but is currently unset but existing in KConfig in **complete**-mode
- **KCONFIG_SANITY_CONFIG_PRE** [string] - prefix of __CONFIG__-options
- **KCONFIG_SANITY_DEFCONFIG** [path] - Path where the __defconfig__-file is placed in recipe workspace
- **KCONFIG_SANITY_FINALCONF** [path] - Path where the actually applied configuration is stored in recipe workspace
- **KCONFIG_SANITY_FRAGMENT_EVAL** [string 0:1] - Enables the check on __*.cfg__-fragments, the so called **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_KCONFIG_EXPLAIN** [string 0:1] - Enables detailed explanation why a __CONFIG__-option can't be applied
- **KCONFIG_SANITY_FRAGMENT_NEW_SET**  [note,warn,error] - Logger function to trigger if a new and set value has been detected in **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_NEW_UNSET** [note,warn,error] - Logger function to trigger if a new but unset value has been detected in **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_NO_MATCH** [note,warn,error] - Logger function to trigger if a value has changed in **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_OLD_NA** [note,warn,error] - Logger function to trigger if a value has been set previously but is now absent due to missing KConfig in **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_OLD_UNSET_EXISTS** [note,warn,error] - Logger function to trigger if a value has been set previously but is currently unset but existing in KConfig in **fragment**-mode
- **KCONFIG_SANITY_FRAGMENT_PATH** [path] - path where to search for __*.cfg__ fragments
- **KCONFIG_SANITY_KCONFIGS** [paths] - paths where to look for KConfig input file

### Remarks

if you want to use the **complete**-mode when checking you have to prepare a __compare__-configuration file.
This file has to be named either

- compare-config.\${MACHINE} [e.g. compare-config.qemux86-64]
- compare-config

at least one of these files has to be included into __SRC_URI__-variable of the recipe to become effective

## layer-sanity

### Purpose

When you are working with different layer, you may find it often confusing that, due to the bbappend-functionality, any layer can alter the recipe code without further notice.
This comes in very unhandy when you might be relying of a certain functionality or configuration.

This class does offer a possibility to 'protect' certain variables of a recipe from being altered by any bbappend.
Also it can 'protect' files from being overloaded by bbappends.

### Usage

Just inherit this class into any recipe

### Configuration

To protect a variable from being changed you have to add the variable name to **LAYER_SANITY_PROT_VARS**.
**LAYER_SANITY_PROT_VARS** is a list of regular expression separated by spaces.

To protect a files from being changed you have to add the file name (with relative path if needed) to **LAYER_SANITY_PROT_FILES**.

### Examples

Let's say you want the variable **EXTRA_OEMAKE** not being altered by any bbappend - then all you have insert into your recipe is

```bitbake
LAYER_SANITY_PROT_VARS += "EXTRA_OEMAKE.*"
```

if now any of the bbappends tries to modify the content of the variable an message will be shown with the change done.

If you also want to 'protect' the file __defconfig__ add the following into your recipe

```bitbake
LAYER_SANITY_PROT_FILES += "defconfig"
```

## buildutils-helper

### Purpose

A collection of helper functions.
Currently it does offer

- **buildutils_find_in_layer** - Finds a file somewhere among all configured layers
- **buildutils_get_files_by_shebang** - Find files by shebang
- **buildutils_get_files_by_extension** - Find files by file-extension
- **buildutils_get_files_by_extension_or_shebang** - Combined result of **buildutils_get_files_by_shebang** + **buildutils_get_files_by_extension**

### Usage

This should only be used indirectly

## python-package-ident

### Purpose

This class does try to identify the needed bitbake-packages for the python code found in the recipe-packages.
On any findings it will give advice via console

### Usage

For python3 installation please inherit **python3-package-ident**.

For python2 installation please inherit **python-package-ident**

## rm_orphans

This class can be included globally (meaning in the distro or local.conf) to remove the leftover log-files, which bitbake leaves for whatever reason in each recipe's TEMP-dir. After this process only files (run + log) from the last run will remain.
This should help mitigating the excessive disk spamming of bitbake

### Usage

Add e.g. to local.conf

```bitbake
INHERIT += "rm_orphans"
```
