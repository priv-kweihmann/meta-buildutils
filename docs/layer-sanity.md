# layer-sanity

## Purpose

When you are working with different layer, you may find it often confusing that, due to the bbappend-functionality, any layer can alter the recipe code without further notice.
This comes in very unhandy when you might be relying of a certain functionality or configuration.

This class does offer a possibility to 'protect' certain variables of a recipe from being altered by any bbappend.
Also it can 'protect' files from being overloaded by bbappends.

## Usage

Just inherit this class into any recipe

## Configuration

To protect a variable from being changed you have to add the variable name to **LAYER_SANITY_PROT_VARS**.
**LAYER_SANITY_PROT_VARS** is a list of regular expression separated by spaces.

To protect a files from being changed you have to add the file name (with relative path if needed) to **LAYER_SANITY_PROT_FILES**.

## Examples

Let's say you want the variable **EXTRA_OEMAKE** not being altered by any bbappend - then all you have insert into your recipe is

```bitbake
LAYER_SANITY_PROT_VARS += "EXTRA_OEMAKE.*"
```

if now any of the bbappends tries to modify the content of the variable an message will be shown with the change done.

If you also want to 'protect' the file __defconfig__ add the following into your recipe

```bitbake
LAYER_SANITY_PROT_FILES += "defconfig"
```
