## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2019, Konrad Weihmann
##

## Try to identify site-packages as well
## be aware that the naming package vs. site-package
## might not be a 100% match
PYTHON_IDENT_SITEPACKAGES = "1"

def get_modules_from_path(path_glob, strip_path, _ignore = ["__pycache__", "lib-dynload"]):
    import glob
    modules = []
    for _gfile in glob.glob(path_glob):
        if not _gfile.endswith(".py"):
            continue
        _gfile_clean = _gfile[:-3].replace(strip_path, "").lstrip("/")
        _clean_name_chunks = [x for x in _gfile_clean.split("/") if x]
        if any(list(set(_clean_name_chunks).intersection(_ignore))):
            continue
        for i in range(len(_clean_name_chunks), 0, -1):
            modules += [".".join(_clean_name_chunks[0:i])]
    return modules

def get_python_modules(d):
    import json
    import os

    modules = {}
    if not d.getVar("PYTHON_MAJMIN"):
        d.setVar("PYTHON_MAJMIN", d.getVar("PYTHON_BASEVERSION"))

    _module_man = buildutils_find_in_layer(d, d.getVar("PYTHON_MODULE_MANIFEST"))
    if _module_man:
        _module_dict = {}
        with open(_module_man) as i:
            tmp = i.read()
            if tmp.startswith("#"):
                ## Probe for manifest with or without preambel
                tmp = tmp[tmp.find('# EOC') + 6:] # EOC + \n -> taken from meta/recipes-devtools/python/python3/create_manifest3.py
            try:
                _module_dict = json.loads(tmp)
            except json.JSONDecodeError as e:
                bb.warn("Something went wrong on loading python-manifest: {}".format(e))
                _module_dict = {}
        _strip_path = os.path.join(d.getVar("STAGING_LIBDIR"), d.getVar("PYTHON_DIR"))
        
        for k,v in _module_dict.items():
            modules[k] = []
            for _file in [x for x in v["files"]]:
                modules[k] += list(set(get_modules_from_path(os.path.join(d.getVar("STAGING_DIR_TARGET"), d.expand(_file).lstrip("/")), _strip_path) + \
                             get_modules_from_path(os.path.join(d.getVar("STAGING_DIR_TARGET"), d.expand(_file).lstrip("/")) + "/**/*.py", _strip_path)))
    else:
        bb.warn("Can't find python-package-manifest '{}' anywhere".format(d.getVar("PYTHON_MODULE_MANIFEST")))
    
    if d.getVar("PYTHON_IDENT_SITEPACKAGES") == "1":
        _strip_path = os.path.join(d.getVar("STAGING_DIR_TARGET"), d.getVar("PYTHON_SITEPACKAGES_DIR").lstrip("/"))
        for _dir in os.listdir(_strip_path):
            if _dir.endswith(".egg-info"):
                continue
            modules[_dir] = list(set(get_modules_from_path(os.path.join(_strip_path, _dir) + "**/*.py", _strip_path) + \
                                    get_modules_from_path(os.path.join(_strip_path, _dir) + "*.py", _strip_path)))
    return modules

def get_package_dependencies(d, element):
    return list(set([x for x in d.getVar("RDEPENDS_{}".format(element)).split(" ") if x]))
    

python do_ident_python_packages() {
    import os
    import bb
    import dis

    _modules = get_python_modules(d)
    _package_dir = d.getVar("PKGDEST")
    
    for _dir in os.listdir(_package_dir):
        _dir_wo_pn = _dir.replace(d.getVar("PN"), "", 1)
        _imports = []
        _full_path = os.path.join(_package_dir, _dir)
        for _file in buildutils_get_files_by_extension_or_shebang(d, _full_path, ".*python", [".py"]):
            try:
                bb.note("Check on file {}".format(_file))
                with open(_file) as f:
                    instructions = dis.get_instructions(f.read())
                    imports = [__ for __ in instructions if 'IMPORT' in __.opname]
                    for instr in imports:
                        _imports.append(instr.argval)
            except:
                pass
        _imports = list(set(_imports))

        bb.note("{} requires following python-imports: {}".format(_dir, _imports))
        if not any(_imports):
            continue

        _depends = get_package_dependencies(d, _dir)
        _depends = [x for x in _depends if x.startswith(d.getVar("PYTHON_PN"))]
        _depends_stripped = [x.replace(d.getVar("PYTHON_PN") + "-", "", 1) for x in _depends]

        _needed_depends = ["core"]

        for _imp in sorted(_imports):
            found = False
            for k,v in _modules.items():
                if _imp in v:
                    found = True
                    if k not in _needed_depends:
                        _needed_depends.append(k)
            if not found:
                bb.note("No package found for import '{}'".format(_imp))
            if not found and "misc" not in _needed_depends:
                _needed_depends.append("misc")
        
        _deps_too_much = ["{}-{}".format(d.getVar("PYTHON_PN"), x) for x in _depends_stripped if not x in _needed_depends]
        _deps_too_less = ["{}-{}".format(d.getVar("PYTHON_PN"), x) for x in _needed_depends if not x in _depends_stripped]

        if any(_deps_too_less):
            bb.warn("{} uses code from python-packages:{}. Please add them to RDEPENDS_${{PN}}{}".format(_dir, ",".join(sorted(_deps_too_less)), _dir_wo_pn))
        if any(_deps_too_much):
            bb.warn("{} don't uses code from python-packages:{}. Please remove them from RDEPENDS_${{PN}}{}".format(_dir, ",".join(sorted(_deps_too_much)), _dir_wo_pn))    
}
do_package[postfuncs] = "do_ident_python_packages"
