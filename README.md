# meta-buildutils
A collection of build utils to used in with yocto

## auto-inherit
### Purpose
With the help of this class you can dynamically inherit other classes into any recipe based on conditions

### Usage
You can either insert
```
INHERIT += "auto-inherit.bbclass"
```
into your __distro configuration__ or into __conf/local.conf__ of your build directory

### Configuration
Configuration is done by bitbake variable __AUTO_INHERIT_CONF__.
It is a space separated list of item (see below).
Best is to place this variable along the inherit.
E.g.
```
INHERIT += "auto-inherit.bbclass"
AUTO_INHERIT_CONF = "BBClass=foo;props[a,b,c]"
```

each value is formatted in the following way
```
BBClass=<class>;props=[func_foo(d),func_foo2(d,param)]
```

The identifier __BBClass__ specifies what other bbclass to be included.
The __props__ identifier specifies a list of python-function, which all must return **true** for the class at __BBClass__ to become included into the recipe currently parsed.

#### Available builtin function
##### auto_inherit_contains_package

Checks if the current recipe **DEPENDS** of another package.
Parameters are 
 * __d__ [object] for the current data-storage of bitbake
 * __pn__ [string] for the package-name to be checked for
 * __skipNative__ [bool:True] for ignoring -native packages on lookup

##### auto_inherit_is_at_path

Checks if the current recipe is located at a certain path (or below) relative to project root
Parameters are
 * __d__ [object] for the current data-storage of bitbake
 * __path__ [string] path to check for
 * __skip_bbappend__ [bool:True] for ignoring bbappend-files on lookup

##### auto_inherit_license

Checks if a recipe is published under a particular license
Parameters are
 * __d__ [object] for the current data-storage of bitbake
 * __license_regex__ [regex] regular expression describing the license to check for

##### auto_inherit_has_source

Checks if the recipe contains specific resources in it'S **SRC_URI** entry
 * __d__ [object] for the current data-storage of bitbake
 * __source_regex__ [regex] regular expression describing the entries to check for

### Examples

```
AUTO_INHERIT_CONF = "BBClass=foo;props=[auto_inherit_is_at_path(d,'meta-foo/recipes-foo/',False)]"
```

This will inherit **foo.bbclass** into each recipe (and bbappend) placed under __meta-foo/recipes-foo/__

```
AUTO_INHERIT_CONF = "BBClass=bar;props=[auto_inherit_license(d,'GPL.*')]"
```

This will inherit **bar.bbclass** into each recipe licensed under "GPL" (including all variants like GPLv2, GPLv3, a.s.o.)

```
AUTO_INHERIT_CONF = "BBClass=bar;props=[auto_inherit_contains_package(d,'python3')]"
```

This will inherit **bar.bbclass** into each recipe which __DEPENDS__ of **python3**

## python-speedups
### Purpose

This class does try to improve the startup speed of the deployed python-interpreter by doing some tweaks.
There is a [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) which explains the background a little more in detail.
You can expect between 10-25% speedup of startup time, without the need to change any code.

### Usage

Just inherit the class into the image-recipe you want to tune

### Configuration

The tuneup amount can be controlled by variable __PYTHON_SPEEDUP_TARGETS__.
This variable is a space separated list which can contain the following items
 * __compile_all__ - This forces a python-compiler run on the rootfs. Very useful when you have a readonly filesystem on your target
 * __binary_tweak__ - This patches the python-CLI options. See [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) for details
 * __no_sitepackage__ - This disables the usage of side-packages by integration them into the standard lib

## kconfig-sanity
### Purpose

This class does check if __*.cfg__ fragments of KConfig-based systems are apply to resulting configuration - It also tries to provide information why a particular __CONFIG___-option can't be applied.
This is very helpful when upgrading a system.
Also this class offers methods for comparing the actual used configuration against a known configuration in repository.

### Usage

Just inherit the class into any recipe using KConfig.
Stock recipes are **busybox**, **linux-yocto**, **u-boot**.

### Configuration 

Following configuration variables can be used. All variables have reasonable default values, so you actually only have to alter the things needed

 * **KCONFIG_SANITY_FRAGMENT_EVAL** [string 0:1] - Enables the check on __*.cfg__-fragments, the so called **fragment**-mode
 * **KCONFIG_SANITY_FRAGEMENT_KCONFIG_EXPLAIN** [string 0:1] - Enables detailed explanation why an __CONFIG___-option can't be applied
 * **KCONFIG_SANITY_DEFCONFIG** [path] - Path where the __defconfig__-file is placed in recipe workspace
 * **KCONFIG_SANITY_FINALCONF** [path] - Path where the actually applied configuration is stored in recipe workspace
 * **KCONFIG_SANITY_CONFIG_PRE** [string] - prefix of __CONFIG___-options
 * **KCONFIG_SANITY_FRAGMENT_PATH** [path] - path where to search for __*.cfg__ fragments
 * **KCONFIG_SANITY_KCONFIGS** [paths] - paths where to look for KConfig input file
 * **KCONFIG_SANITY_BLACKLIST** [string] - List of __CONFIG___-options to ignore on checkup
 * **KCONFIG_SANITY_COMPAREFILES** [string] - List of files which will be compared to resulting configuration. Leave empty to disable **complete**-mode
 * **KCONFIG_SANITY_COMPLETE_NO_MATCH** [note,warn,error] - Logger function to trigger if a value has changed in **complete**-mode
 * **KCONFIG_SANITY_COMPLETE_NEW_SET**  [note,warn,error] - Logger function to trigger if a new and set value has been detected in **complete**-mode
 * **KCONFIG_SANITY_COMPLETE_NEW_UNSET** [note,warn,error] - Logger function to trigger if a new but unset value has been detected in **complete**-mode
 * **KCONFIG_SANITY_COMPLETE_OLD_UNSET_EXISTS** [note,warn,error] - Logger function to trigger if a value has been set previously but is currently unset but existing in KConfig in **complete**-mode
 * **KCONFIG_SANITY_COMPLETE_OLD_NA** [note,warn,error] - Logger function to trigger if a value has been set previously but is no absent due to missing KConfig in **complete**-mode

 * **KCONFIG_SANITY_FRAGMENT_NO_MATCH** [note,warn,error] - Logger function to trigger if a value has changed in **fragment**-mode
 * **KCONFIG_SANITY_FRAGMENT_NEW_SET**  [note,warn,error] - Logger function to trigger if a new and set value has been detected in **fragment**-mode
 * **KCONFIG_SANITY_FRAGMENT_NEW_UNSET** [note,warn,error] - Logger function to trigger if a new but unset value has been detected in **fragment**-mode
 * **KCONFIG_SANITY_FRAGMENT_OLD_UNSET_EXISTS** [note,warn,error] - Logger function to trigger if a value has been set previously but is currently unset but existing in KConfig in **fragment**-mode
 * **KCONFIG_SANITY_FRAGMENT_OLD_NA** [note,warn,error] - Logger function to trigger if a value has been set previously but is no absent due to missing KConfig in **fragment**-mode

### Remarks

if you want to use the **complete**-mode when checking you have to prepare a __compare__-configuration file.
This file has to be named either
 * compare-config.${MACHINE} [e.g. compare-config.qemux86-64]
 * compare-config

at least one of these files has to be included into __SRC_URI__-variable of the recipe to become effective

