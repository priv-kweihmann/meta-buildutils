# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2020, Konrad Weihmann

# This class create an inventory of each package
# containing
# - LICENSE
# - CVE_PRODUCT
# - DEPENDS
# - RDEPENDS
# - Files packaged
# - Source files used (binary + non-binaries)
# - recipes used
# - package name
#
# these will be placed at ${SWINVENTORY_DEPLOY}/<package-name>.json
#
# Following json schema applies
#
# {
#     "$schema": "http://json-schema.org/draft-04/schema#",
#     "type": "object",
#     "properties": {
#         "cveproduct": {
#             "description": "CVE product identifier",
#             "type": "string"
#         },
#         "depends": {
#             "type": "array",
#             "minItems": 0,
#             "items": [
#                 {
#                     "description": "buildtime dependencies",
#                     "type": "string"
#                 }
#             ]
#         },
#         "files": {
#             "type": "array",
#             "minItems": 0,
#             "description": "files installed by the package",
#             "items": [
#                 {
#                     "type": "object",
#                     "properties": {
#                         "hash": {
#                             "description": "sha256 sum of the file",
#                             "type": "string"
#                         },
#                         "name": {
#                             "description": "full path of the file",
#                             "type": "string"
#                         },
#                         "sources": {
#                             "type": "array",
#                             "items": {
#                                 "type": "object",
#                                 "properties": {
#                                     "hash": {
#                                         "description": "sha256 sum of the source file",
#                                         "type": "string"
#                                     },
#                                     "name": {
#                                         "description": "path of the source file relative to workspace",
#                                         "type": "string"
#                                     }
#                                 },
#                                 "additionalProperties": false,
#                                 "required": [
#                                     "hash",
#                                     "name"
#                                 ]
#                             }
#                         },
#                         "type": {
#                             "description": "MIME type of file",
#                             "type": "string"
#                         }
#                     },
#                     "additionalProperties": false,
#                     "required": [
#                         "hash",
#                         "name",
#                         "sources",
#                         "type"
#                     ]
#                 }
#             ]
#         },
#         "license": {
#             "type": "string",
#             "description": "license of package in SPDX format"
#         },
#         "name": {
#             "type": "string",
#             "description": "package name"
#         },
#         "rdepends": {
#             "type": "array",
#             "minItems": 0,
#             "items": {
#                 "description": "runtime dependencies",
#                 "type": "string"
#             }
#         },
#         "recipes": {
#             "type": "array",
#             "description": "recipes used to build this package",
#             "items": [
#                 {
#                     "type": "string",
#                     "description": "path to recipe relative to layer root"
#                 }
#             ]
#         }
#     },
#     "additionalProperties": false,
#     "required": [
#         "cveproduct",
#         "depends",
#         "files",
#         "license",
#         "name",
#         "rdepends",
#         "recipes"
#     ]
# }
#
# Using these information one could trace back individual files
# from an image

# local storage
SWINVENTORYDIR = "${WORKDIR}/swinventory"
# global storage
SWINVENTORY_DEPLOY ??= "${DEPLOY_DIR}/swinventory"
# pattern to probe for detecting direct file copies
SWINVENTORY_SRC_PATTERN ??= "${S}/** ${S} ${WORKDIR}"
# mime types to treat as binaries
SWINVENTORY_EXEC_MIME ??= "application/x-pie-executable application/x-executable"

def swinventory_sanitizes_recipe_paths(d, _in):
    import os
    for b in d.getVar("BBPATH").split(":"):
        _rpl = os.path.dirname(b)
        _in = _in.replace(_rpl, "", 1)
    return _in.lstrip("/")

def swinventory_sanitize_list(_list):
    if _list is None:
        return []
    if isinstance(_list, str):
        _list = _list.split(" ")
    _list = set(x for x in _list if x)
    return sorted(list(_list))

def swinventory_create_depends(d):
    res = []
    for p in d.getVar("DEPENDS").split(" "):
        if not p.strip():
            continue
        if p.startswith("virtual/"):
            p = d.getVar("PREFERRED_PROVIDER_{}".format(p))
            if not p:
                continue
        res.append(p)
    return res

def swinventory_hash_file(_file, _hashsource=None, abspath=False):
    import hashlib
    _hashsource = _hashsource or _file
    if not _file.startswith("/"):
        _file = "/" + _file
    _file = os.path.abspath(_file)
    if not abspath:
        _file = _file.lstrip("/")
    try:
        return {"name": _file, "hash": hashlib.sha256(open(_hashsource,'rb').read()).hexdigest() }
    except FileNotFoundError:
        return {"name": _file, "hash": "UNKNOWN" }
    except Exception:
        return {"name": _file, "hash": "UNKNOWN" }

def swinventory_getsrc_from_binary(d, binary, basepath):
    import subprocess
    res = []
    try:
        _src_files = subprocess.check_output(
                        ["{} -wi {} | grep -B1 DW_AT_comp_dir | awk '/DW_AT_name/{{name = $NF; getline; print name}}'".format(d.getVar("READELF"), binary)],
                        universal_newlines=True, shell=True).split("\n")
        _src_files = [x.lstrip("./") for x in _src_files]
        _src_files = [x for x in _src_files if x.startswith(d.getVar("PN"))]
        _src_files = [x.replace(basepath.lstrip("/"), "", 1) for x in _src_files]
        for _s in _src_files:
            res.append(swinventory_hash_file(_s, os.path.join(basepath, _s)))
    except:
        pass
    return res

def swinventory_getsrc_from_file(d, file):
    import glob
    _clean = file
    _pattern = d.getVar("SWINVENTORY_SRC_PATTERN").split(" ")
    for f in _pattern:
        _clean = _clean.replace(f, "", 1)
    _clean = _clean.lstrip("/")
    _clean = _clean.split("/")
    while _clean:
        for b in _pattern:
            _tmp = glob.glob(os.path.join(b, *_clean))
            if _tmp:
                return swinventory_hash_file(_tmp[0].replace(b.rstrip("*/"), "", 1), _tmp[0])
        _clean = _clean[1:]
    bb.note("No found match for > {}".format(file))
    return None

def swinventory_create_filelist_target(d, pkg):
    import os
    import subprocess
    res = []
    _pkroot = d.getVar("PKGDEST")
    _bin_pattern = d.getVar("SWINVENTORY_EXEC_MIME").split(" ")
    for root, dirs, files in os.walk(os.path.join(_pkroot, pkg)):
        for f in files:
            _filename = os.path.join(root, f)
            _rel_filename = _filename.replace(os.path.join(_pkroot, pkg), "", 1).lstrip("/")
            _item = swinventory_hash_file(_rel_filename, _filename, True)
            try:
                _item["type"] = subprocess.check_output(["file", "--brief", "--mime-type", _filename],
                                                        universal_newlines=True).strip("\n")
                if _item["type"] in _bin_pattern:
                    _item["sources"] = swinventory_getsrc_from_binary(d,
                                                                      os.path.join(d.getVar("D"), _rel_filename.lstrip("/")),
                                                                      d.getVar("WORKDIR"))
                else:
                    _tmp = swinventory_getsrc_from_file(d, _rel_filename)
                    _item["sources"] = [_tmp] if _tmp else []
            except:
                pass
            res.append(_item)
    return res

def swinventory_create_filelist_nontarget(d, pkg):
    import os
    import subprocess
    res = []
    _pkroot = d.getVar("D")
    # for native packages we need to strip staging_dir as well
    _staging_dir = d.getVar("STAGING_DIR_NATIVE")
    _bin_pattern = d.getVar("SWINVENTORY_EXEC_MIME").split(" ")
    for root, dirs, files in os.walk(_pkroot):
        for f in files:
            _filename = os.path.join(root, f)
            _rel_filename = _filename.replace(_pkroot, "").replace(_staging_dir.lstrip("/"), "").lstrip("/")
            _item = swinventory_hash_file(_rel_filename, _filename, True)
            try:
                _item["type"] = subprocess.check_output(["file", "--brief", "--mime-type", _filename],
                                                        universal_newlines=True).strip("\n")
                if _item["type"] in _bin_pattern:
                    _item["sources"] = swinventory_getsrc_from_binary(d,
                                                                      _filename,
                                                                      d.getVar("WORKDIR"))
                else:
                    _tmp = swinventory_getsrc_from_file(d, _rel_filename)
                    _item["sources"] = [_tmp] if _tmp else []
            except:
                pass
            res.append(_item)
    return res

def swinventory_create_packages(d, pkg, file_function):
    import re
    return {
            "name": pkg,
            "recipes": swinventory_sanitize_list(swinventory_sanitizes_recipe_paths(d, x) for x in d.getVar("BBINCLUDED").split(" ") if x),
            "depends": swinventory_sanitize_list(swinventory_create_depends(d)),
            "rdepends": swinventory_sanitize_list(re.sub(r"\(.*?\)", "", d.getVar("RDEPENDS_{}".format(pkg)) or "")),
            "cveproduct": d.getVar("CVE_PRODUCT") or d.getVar("BPN"),
            "files": file_function(d, pkg),
            "license": d.getVar("LICENSE_{}".format(pkg)) or d.getVar("LICENSE")
           }

def swinventory_create_dummy_package(d, pkg, depends):
    import re
    return {
            "name": pkg,
            "recipes": swinventory_sanitize_list(swinventory_sanitizes_recipe_paths(d, x) for x in d.getVar("BBINCLUDED").split(" ") if x),
            "depends": swinventory_sanitize_list(depends),
            "rdepends": swinventory_sanitize_list(re.sub(r"\(.*?\)", "", d.getVar("RDEPENDS_{}".format(pkg)) or "")),
            "cveproduct": d.getVar("CVE_PRODUCT") or d.getVar("BPN"),
            "files": [],
            "license": d.getVar("LICENSE_{}".format(pkg)) or d.getVar("LICENSE")
           }

python do_swinventory() {
    import json
    import os
    if bb.data.inherits_class('image', d):
        # doesn't make much sense in images
        return
    if bb.data.inherits_class('native', d) or \
       bb.data.inherits_class('nativesdk', d) or \
       bb.data.inherits_class('cross', d) or \
       bb.data.inherits_class('nopackages', d):
       pkg = d.getVar("PN")
       with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
            json.dump(swinventory_create_packages(d, pkg, swinventory_create_filelist_nontarget),
                      o,
                      indent=2,
                      sort_keys=True)
    else:
        for pkg in d.expand("${PACKAGES}").split(" "):
            if not pkg or not pkg.strip():
                continue
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_packages(d, pkg, swinventory_create_filelist_target),
                        o,
                        indent=2,
                        sort_keys=True)
        # in case there is no base package, create a dummy one
        if not d.getVar("PN") in d.expand("${PACKAGES}").split(" "):
            pkg = d.getVar("PN")
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_dummy_package(d, pkg, d.expand("${PACKAGES}").split(" ")),
                        o,
                        indent=2,
                        sort_keys=True)
}
do_swinventory[doc] = "Create an inventory of each package"
do_swinventory[vardepexclude] += "BBPATH BBINCLUDED"
do_swinventory[dirs] = "${SWINVENTORYDIR}"
do_swinventory[cleandirs] = "${SWINVENTORYDIR}"
do_swinventory[sstate-inputdirs] = "${SWINVENTORYDIR}"
do_swinventory[sstate-outputdirs] = "${SWINVENTORY_DEPLOY}/"

python() {
    # known exceptions
    _exceptions = {
        "buildtools-tarball": { "after": "", "before": "" },
        "base-passwd": { "after": "do_package", "before": "do_build" }
    }
    _pn = d.getVar("PN")
    if _pn in _exceptions:
        _after = _exceptions[_pn]["after"]
        _before = _exceptions[_pn]["before"]
    else:
        _after = "do_unpack"
        _needles = ["do_package" if not bb.data.inherits_class("nopackages", d) else "", "do_install"]
        for n in _needles:
            if not n:
                continue
            if "task" in (d.getVarFlags(n) or []):
                _after = n
                break
        _before = "do_build"
        _needles = ["do_populate_sysroot", "do_rmwork", "do_build"]
        for n in _needles:
            if "task" in (d.getVarFlags(n) or []):
                _before = n
                break

    if _after and _before:
        d.appendVarFlag(_before, 'depends', ' {}:do_swinventory'.format(_pn))
        d.appendVarFlag('do_swinventory', 'depends', ' {}:{}'.format(_pn, _after))
}

addtask do_swinventory

SSTATETASKS += "do_swinventory"

python do_swinventory_setscene() {
    sstate_setscene(d)
}
addtask do_swinventory_setscene
