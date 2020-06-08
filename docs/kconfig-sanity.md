# kconfig-sanity

## Purpose

This class does check if __*.cfg__ fragments of KConfig-based systems are applied to resulting configuration.
It also tries to provide information why a particular __CONFIG__-option can't be applied.
This is very helpful when upgrading a system.
Also this class offers methods for comparing the actual used configuration against a known configuration in repository.

## Usage

Just inherit the class into any recipe using KConfig.
Stock recipes are **busybox**, **linux-yocto**, **u-boot**.

## Configuration

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

## Remarks

if you want to use the **complete**-mode when checking you have to prepare a __compare__-configuration file.
This file has to be named either

- compare-config.\${MACHINE} [e.g. compare-config.qemux86-64]
- compare-config

at least one of these files has to be included into __SRC_URI__-variable of the recipe to become effective
