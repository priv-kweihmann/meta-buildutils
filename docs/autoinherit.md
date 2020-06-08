# auto-inherit

## Purpose

With the help of this class you can dynamically inherit other classes into any recipe based on conditions

## Usage

You can either insert

```bitbake
INHERIT += "auto-inherit.bbclass"
```

into your __distro configuration__ or into __conf/local.conf__ of your build directory

## Configuration

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

### Available builtin function

#### auto_inherit_contains_package

Checks if the current recipe **DEPENDS** on another package.
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __pn__ [string] for the package-name to be checked for
- __skipNative__ [bool:True] for ignoring -native packages on lookup

#### auto_inherit_is_at_path

Checks if the current recipe is located at a certain path (or below) relative to project root
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __path__ [string] path to check for
- __skip_bbappend__ [bool:True] for ignoring bbappend-files on lookup

#### auto_inherit_license

Checks if a recipe is published under a particular license
Parameters are

- __d__ [object] for the current data-storage of bitbake
- __license_regex__ [regex] regular expression describing the license to check for

#### auto_inherit_has_source

Checks if the recipe contains specific resources in it's **SRC_URI** entry

- __d__ [object] for the current data-storage of bitbake
- __source_regex__ [regex] regular expression describing the entries to check for

## Examples

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
