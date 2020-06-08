# python-speedups

## Purpose

This class does try to improve the startup speed of the deployed python-interpreter by doing some tweaks.
There is a [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) which explains the background a little more in detail.
You can expect between 10-25% speedup of startup time, without the need to change any code.

## Usage

Just inherit the class into the **image-recipe** you want to tune

## Configuration

The tuneup amount can be controlled by variable __PYTHON_SPEEDUP_TARGETS__.
This variable is a space separated list which can contain the following items

- __compile_all__ - This forces a python-compiler run on the rootfs. Very useful when you have a readonly filesystem on your target
- __binary_tweak__ - This patches the python-CLI options. See [blog-post](https://bitbakesoda.blogspot.com/2019/03/speedup-python-on-embedded-systems.html) for details
- __no_sitepackage__ - This disables the usage of side-packages by integrating them into the standard lib
