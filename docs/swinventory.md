# swinventory

This class creates an inventory of each package, including

- LICENSE
- CVE_PRODUCT
- DEPENDS
- RDEPENDS
- Files packaged
- Source files used (binary + non-binaries)
- recipes used
- package name

this information is all put into a json-file, which will be deployed to `tmp/deploy/swinventory`, from where
you can construct further interesting insights for your software.

The format of the json file is explained in detail in the class header.

**NOTE**: the class is designed to work with sstate-caches, so the information should available even when working with **SSTATE_MIRRORS**

## Usage

Add

```bitbake
INHERIT += "swinventory"
```

to your local.conf

## Configuration

- SWINVENTORY_DEPLOY - global export-dir for all package information
- SWINVENTORY_SRC_PATTERN - pattern used to match installed file back to source files
- SWINVENTORY_EXEC_MIME - MIME-types detected which will treat files as binaries
