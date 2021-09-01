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
# - additional plain test files
#
# these will be placed at ${SWINVENTORY_DEPLOY}/<package-name>.json
#
# Following json schema applies
#
# {
#     "$schema": "http://json-schema.org/draft-04/schema#",
#     "additionalProperties": false,
#     "properties": {
#         "additionalFiles": {
#             "description": "recipes used to build this package",
#             "items": [
#                 {
#                     "additionalProperties": false,
#                     "properties": {
#                         "content": {
#                             "description": "plain content of the file",
#                             "type": "string"
#                         },
#                         "hash": {
#                             "description": "sha256 sum of the file",
#                             "type": "string"
#                         },
#                         "name": {
#                             "description": "full path of the file",
#                             "type": "string"
#                         }
#                     },
#                     "required": [
#                         "hash",
#                         "name",
#                         "type"
#                     ],
#                     "type": "object"
#                 }
#             ],
#             "type": "array"
#         },
#         "cveproduct": {
#             "description": "CVE product identifier",
#             "type": "string"
#         },
#         "depends": {
#             "items": [
#                 {
#                     "description": "buildtime dependencies",
#                     "type": "string"
#                 }
#             ],
#             "minItems": 0,
#             "type": "array"
#         },
#         "files": {
#             "description": "files installed by the package",
#             "items": [
#                 {
#                     "additionalProperties": false,
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
#                             "items": {
#                                 "additionalProperties": false,
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
#                                 "required": [
#                                     "hash",
#                                     "name"
#                                 ],
#                                 "type": "object"
#                             },
#                             "type": "array"
#                         },
#                         "type": {
#                             "description": "MIME type of file",
#                             "type": "string"
#                         }
#                     },
#                     "required": [
#                         "hash",
#                         "name",
#                         "sources",
#                         "type"
#                     ],
#                     "type": "object"
#                 }
#             ],
#             "minItems": 0,
#             "type": "array"
#         },
#         "license": {
#             "description": "license of package in SPDX format",
#             "type": "string"
#         },
#         "name": {
#             "description": "package name",
#             "type": "string"
#         },
#         "rdepends": {
#             "items": {
#                 "description": "runtime dependencies",
#                 "type": "string"
#             },
#             "minItems": 0,
#             "type": "array"
#         },
#         "recipes": {
#             "description": "recipes used to build this package",
#             "items": [
#                 {
#                     "description": "path to recipe relative to layer root",
#                     "type": "string"
#                 }
#             ],
#             "type": "array"
#         }
#     },
#     "required": [
#         "additionalFiles",
#         "cveproduct",
#         "depends",
#         "files",
#         "license",
#         "name",
#         "rdepends",
#         "recipes"
#     ],
#     "type": "object"
# }
# Using these information one could trace back individual files
# from an image

# local storage
SWINVENTORYDIR = "${WORKDIR}/swinventory"
# global storage
SWINVENTORY_DEPLOY ??= "${DEPLOY_DIR}/swinventory"
# (glob) pattern to probe for detecting direct file copies
SWINVENTORY_SRC_PATTERN ??= "${S}/** ${S} ${WORKDIR}"
# mime types to treat as binaries
SWINVENTORY_EXEC_MIME ??= "application/x-pie-executable application/x-executable application/x-sharedlib"
# exceptions for overriding autom. determined task order
# be sure to set both: 'after' and 'before'
SWINVENTORY_EXCEPT_buildtools-tarball[after] = ""
SWINVENTORY_EXCEPT_buildtools-tarball[before] = ""
SWINVENTORY_EXCEPT_base-passwd[after] = "do_package"
SWINVENTORY_EXCEPT_base-passwd[before] = "do_build"
SWINVENTORY_EXCEPT_package-index[after] = ""
SWINVENTORY_EXCEPT_package-index[before] = ""
# include files matching (glob) pattern into additionalFiles
SWINVENTORY_ADDFILES_PATTERN ??= ""
# list of full paths to collected manifest files
# can be e.g. used by a postfunc to do further processing 
SWINVENTORY_COLLECTED_MANIFESTS = ""

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
    _list = set(x.strip("\t ") for x in _list if x)
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

def swinventory_get_aliases(d, pkg):
    import subprocess
    res = {}
    try:
        out = subprocess.check_output(["grep", "-rh", "PKG_{}: ".format(pkg), d.expand("${PKGDATA_DIR}")],
                                      universal_newlines=True).split("\n")
        for o in out:
            _o = o.split(":")
            _pkg = _o[0].replace("PKG_", "").strip()
            _alias = _o[1].strip()
            if _pkg != _alias:
                res[_pkg] = _alias 
    except:
        pass
    return res

def swinventory_get_recipe_file(d):
    import os
    return sorted([x for x in d.getVar("BBINCLUDED").split(" ") if x and os.path.exists(x)])

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

def swinventory_get_additionalfiles(d):
    import glob
    res = []
    for _pattern in d.getVar("SWINVENTORY_ADDFILES_PATTERN").split(" "):
        if not _pattern or not _pattern.strip():
            continue
        for _file in glob.glob(_pattern):
            _tmp = swinventory_hash_file(os.path.basename(_file), _file)
            if _tmp:
                try:
                    with open(_file) as i:
                        _tmp["content"] = i.read() 
                except:
                    pass
                res.append(_tmp)
    return res

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

def swinventory_create_packages(d, pkg, file_function, native=False):
    import re
    return {
            "additionalFiles": swinventory_get_additionalfiles(d),
            "cveproduct": d.getVar("CVE_PRODUCT") or d.getVar("BPN"),
            "depends": swinventory_sanitize_list(swinventory_create_depends(d)),
            "files": file_function(d, pkg),
            "license": d.getVar("LICENSE_{}".format(pkg)) or d.getVar("LICENSE"),
            "name": pkg,
            "rdepends": swinventory_sanitize_list(re.sub(r"\(.*?\)", "", d.getVar("RDEPENDS:{}".format(pkg)) or "")) if not native else [],
            "recipes": swinventory_sanitize_list(swinventory_sanitizes_recipe_paths(d, x) for x in swinventory_get_recipe_file(d)),
           }

def swinventory_create_dummy_package(d, pkg, depends, native=False):
    import re
    return {
            "additionalFiles": swinventory_get_additionalfiles(d),
            "cveproduct": d.getVar("CVE_PRODUCT") or d.getVar("BPN"),
            "depends": swinventory_sanitize_list(depends),
            "files": [],
            "license": d.getVar("LICENSE_{}".format(pkg)) or d.getVar("LICENSE"),
            "name": pkg,
            "rdepends": swinventory_sanitize_list(re.sub(r"\(.*?\)", "", d.getVar("RDEPENDS:{}".format(pkg)) or "")) if not native else [],
            "recipes": swinventory_sanitize_list(swinventory_sanitizes_recipe_paths(d, x) for x in swinventory_get_recipe_file(d)),
           }

python do_swinventory() {
    import json
    import os
    _collected_manifests = []
    if bb.data.inherits_class('image', d):
        # doesn't make much sense in images
        return
    if bb.data.inherits_class('native', d) or \
       bb.data.inherits_class('nativesdk', d) or \
       bb.data.inherits_class('cross', d) or \
       bb.data.inherits_class('nopackages', d):
        pkg = d.getVar("PN")
        with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_packages(d, pkg, swinventory_create_filelist_nontarget, True),
                        o,
                        indent=2,
                        sort_keys=True)
                _collected_manifests.append(o.name)
        # now catch all PROVIDES overrides
        for _pkg in d.expand("${PROVIDES}").split(" "):
            if _pkg == pkg or (not _pkg or not _pkg.strip()):
                continue
            if _pkg.startswith("virtual/"):
                _pkg = _pkg.replace("virtual/", "", 1)
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(_pkg)), "w") as o:
                json.dump(swinventory_create_dummy_package(d, _pkg, [pkg], True),
                        o,
                        indent=2,
                        sort_keys=True)
                _collected_manifests.append(o.name)
    else:
        _pkgs = [os.path.basename(x.path) for x in os.scandir(d.getVar("PKGDEST")) if os.path.isdir(x.path)]
        for pkg in _pkgs:
            if not pkg or not pkg.strip():
                continue
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_packages(d, pkg, swinventory_create_filelist_target),
                        o,
                        indent=2,
                        sort_keys=True)
                _collected_manifests.append(o.name)
        # in case there is no base package, create a dummy one
        if not d.getVar("PN") in _pkgs:
            pkg = d.getVar("PN")
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_dummy_package(d, pkg, _pkgs),
                        o,
                        indent=2,
                        sort_keys=True)
                _collected_manifests.append(o.name)
        # now catch all the things created due to debian.bbclass renaming
        # for these another dummy package is created which links to the
        # rightly named package
        for _pkg in _pkgs:
            for pkg, alias in swinventory_get_aliases(d, _pkg).items():
                if not pkg or not pkg.strip():
                    continue
                if not alias or not alias.strip():
                    continue
                with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(alias)), "w") as o:
                    json.dump(swinventory_create_dummy_package(d, alias, [pkg]),
                            o,
                            indent=2,
                            sort_keys=True)
                    _collected_manifests.append(o.name)
        # now catch all PROVIDES overrides
        for pkg in d.expand("${PROVIDES}").split(" "):
            if pkg in _pkgs or (not pkg or not pkg.strip()):
                continue
            if pkg.startswith("virtual/"):
                pkg = pkg.replace("virtual/", "", 1)
            with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(pkg)), "w") as o:
                json.dump(swinventory_create_dummy_package(d, pkg, _pkgs),
                        o,
                        indent=2,
                        sort_keys=True)
                _collected_manifests.append(o.name)
        # now get all RPROVIDES
        for pkg in _pkgs:
            if not pkg or not pkg.strip():
                continue
            _rprovides = d.getVar(d.expand("RPROVIDES:{}".format(pkg))) or ""
            for rprov in [x for x in _rprovides.split(" ") if x]:
                with open(os.path.join(d.expand("${SWINVENTORYDIR}"), "{}.json".format(rprov)), "w") as o:
                    json.dump(swinventory_create_dummy_package(d, rprov, [pkg]),
                            o,
                            indent=2,
                            sort_keys=True)
                    _collected_manifests.append(o.name)
    d.setVar("SWINVENTORY_COLLECTED_MANIFESTS", " ".join(_collected_manifests))
}
do_swinventory[doc] = "Create an inventory of each package"
do_swinventory[vardepexclude] += "BBPATH BBINCLUDED"
do_swinventory[dirs] = "${SWINVENTORYDIR}"
do_swinventory[cleandirs] = "${SWINVENTORYDIR}"
do_swinventory[sstate-inputdirs] = "${SWINVENTORYDIR}"
do_swinventory[sstate-outputdirs] = "${SWINVENTORY_DEPLOY}/"

python() {
    _pn = d.getVar("PN")
    if d.getVarFlags("SWINVENTORY_EXCEPT_{}".format(_pn)):
        _after = d.getVarFlag("SWINVENTORY_EXCEPT_{}".format(_pn), "after") or ""
        _before = d.getVarFlag("SWINVENTORY_EXCEPT_{}".format(_pn), "before") or ""
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
        _needles = ["do_deploy", "do_populate_sysroot", "do_rmwork", "do_build"]
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
