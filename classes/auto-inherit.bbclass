## Auto inherit
## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2019, Konrad Weihmann

## This class automatically inherits other bbclasses into
## any recipe based on configurable criteria

## E.g. if you want to inherit your bbclass "foo"
## to any CLOSED-source component which is located under
## root/path/foo but not into any other recipe
## this class is a great help

## Ther configuration is done by the variable 
## AUTO_INHERIT_CONF

## To activate simple put INHERIT += "auto-inherit" into either
## your local.conf or into your distro.conf

## The variable is contain space separated values
## each value is formatted in the following way
## BBClass=<class>;props=[func_foo(d),func_foo2(d,param)]
##
## BBClass is the bbclass you want to inherit
## props is a list of python functions returning a boolean value
## if all props-function return True the class under BBCLass will be
## inherited into the current recipe

## For convinience several premade function can be found at the bottom
## of this file

AUTO_INHERIT_CONF ?= ""

## Example:
## inherit class foo on all recipe whcih depend on recipe BAR and are licensed under any GPL-variant
## AUTO_INHERIT_CONF = "BBClass=python-speedups;props=[auto_inherit_is_at_path(d,'meta-buildutils/recipes-foo/',False)]"

# Variables to be masked out to avoid hash corruption
AUTO_INHERIT_MASK_VARS ?= "BBINCLUDED"

addhandler auto_inherit_handler
auto_inherit_handler[eventmask] = "bb.event.RecipePreFinalise"
python auto_inherit_handler() {
    import os
    import re
    import bb
    from bb.parse.parse_py import BBHandler

    # if filename is not set it's likely a call from
    # further down this function so ignore it
    if not e.fn:
        return
    res = []
    __saved_handler = d.getVar("__BBHANDLERS", False)
    for item in [x for x in d.getVar("AUTO_INHERIT_CONF").split(" ") if x]:
        args = dict(e.split('=') for e in item.split(';'))
        include = True
        if not "props" in args.keys() or not "BBClass" in args.keys():
            continue
        args["props"] = eval(args["props"])
        for prop_func in args["props"]:
            try:
                compile(str(prop_func), "pattern_test", "eval")
                include &= eval(str(prop_func))
            except Exception as e:
                bb.warn("Prop-Func {} is not well-formed: {}".format(prop_func, e))
        if include:
            bb.note("Inheriting {} caused by auto-inherit".format(args["BBClass"]))
            BBHandler.inherit(args["BBClass"], "lb-inherit", 1, d)
            # now check if the new classes include some more handler, we should be registered
            _new_handler = [x for x in d.getVar("__BBHANDLERS", False) if x not in __saved_handler]
            for new_handler in _new_handler:
                _nh_filename = d.getVarFlag(new_handler, "filename", False)
                _nh_line = int(d.getVarFlag(new_handler, "lineno", False))
                _nh_eventmask = (d.getVarFlag(new_handler, "eventmask") or "").split()
                bb.event.register(new_handler, d.getVar(new_handler, False), _nh_eventmask, _nh_filename, _nh_line)
            # in case there are new handler to be fired do that now
            if _new_handler:
                bb.event.fire(bb.event.RecipePreFinalise(None), d)
                __saved_handler = d.getVar("__BBHANDLERS", False)
    if d.getVar("AUTO_INHERIT_CONF"):
        for e in d.keys():
            if d.getVarFlag(e, 'task'):
                d.appendVarFlag(e, "vardepsexclude", " " + d.getVar("AUTO_INHERIT_MASK_VARS"))
}


## Check if a recipe depends on a package
## pn = Package name
## skipNative = skip native packages
def auto_inherit_contains_package(d, pn, skipNative=True):
    depends = d.getVar("DEPENDS") or ""
    rdepends = d.getVar("RDEPENDS_{}".format(d.getVar("PN"))) or ""
    pkgs = list(set(depends.split(" ") + rdepends.split(" ")))
    return any(x for x in pkgs if x.startswith(pn) and (skipNative or not x.endswith("-native")))

## Check if a recipe is located in a given path
## path = path relative to root of project
## skip_bbappend = don't use only bbappends
def auto_inherit_is_at_path(d, path, skip_bbappend=True):
    files = [x[0] for x in d.getVar('__depends') if os.path.exists(x[0])]
    tmp = d.getVar("BBINCLUDED") or ""
    files += tmp.split(" ")
    files = list(set(files))
    file_ext = [".bb"]
    if not skip_bbappend:
        file_ext += [".bbappend"]
    files = [x for x in files if os.path.splitext(x)[1] in file_ext]
    files = [x for x in files if x.find(path) != -1 ]
    return any(files)

## Check if recipe's license
## license_regex = RegEx for license
def auto_inherit_license(d, license_regex):
    import re
    return re.match(license_regex, d.getVar("LICENSE")) is not None

## Check if recipe contains a source item - checks SRC_URI
## source_regex = RegEx for source item
def auto_inherit_has_source(d, source_regex):
    import re
    return re.match(source_regex, d.getVar("SRC_URI")) is not None
