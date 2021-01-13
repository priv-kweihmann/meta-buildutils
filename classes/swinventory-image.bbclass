## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2020, Konrad Weihmann

inherit swinventory

# list of full paths to collected manifest files
# can be e.g. used by a postfunc to do further processing 
SWINVENTORY_IMAGE_COLLECTED_MANIFESTS = ""

# special sauce translation
# translate the package that are linked to ASSUME_PROVIDED
# and therefore are not run, so swinventory can catch them
SWINVENTORY_ASSUME_PROVIDED_TRANSLATE ?= "bzip2-replacement-native:bzip2-native"

addhandler swinventory_image_eventhandler
swinventory_image_eventhandler[eventmask] = "bb.event.SanityCheck"
python swinventory_image_eventhandler() {
    if "swinventory" not in [x for x in d.getVar("INHERIT").split(" ") if x]:
        bb.error("swinventory-image requires 'swinventory' in global 'INHERIT'")
    if "swinventory-image" in [x for x in d.getVar("INHERIT").split(" ") if x]:
        bb.error("'swinventory-image' should not be put to global 'INHERIT'. Inherit it into the target image recipe only")
}

def swinventory_image_get_package(d, name, out, files):
    import os
    import json

    # Handle the super special cases, such as
    # bzip2-replacement-native being translated to bzip2-native
    # which is by default in ASSUME_PROVIDED
    # but the actual bzip2 recipe is never run
    _secret_sauce = {}
    for x in d.getVar("SWINVENTORY_ASSUME_PROVIDED_TRANSLATE").split(" "):
        if not x:
            continue
        _chunks = x.split(":")
        if len(_chunks) != 2:
            continue
        _secret_sauce[_chunks[0]] = _chunks[1]

    if name in _secret_sauce:
        name = _secret_sauce[name]

    name = name.strip()
    if name in d.getVar("ASSUME_PROVIDED").split(" "):
        # ASSUME_PROVIDED packages can be safely ignored
        return
    try:
        with open(os.path.join(d.getVar("SWINVENTORY_DEPLOY"), name + ".json")) as i:
            _in = json.load(i)
            files.append(i.name)
            out[name] = _in
            for _n in set(_in["depends"] + _in["rdepends"]):
                if _n not in out:
                    swinventory_image_get_package(d, _n, out, files)
    except FileNotFoundError:
        bb.warn("No swinventory for {} found".format(name))

python do_swinventory_image() {
    from oe.rootfs import image_list_installed_packages
    import json

    out = {}
    files = []
    for k in image_list_installed_packages(d):
        swinventory_image_get_package(d, k, out, files)
    
    with open(d.expand("${DEPLOY_DIR_IMAGE}/${PN}-swinventory.json"), "w") as o:
        json.dump(out, o, sort_keys=True, indent=2)
    
    d.setVar("SWINVENTORY_IMAGE_COLLECTED_MANIFESTS", " ".join(files))
}

ROOTFS_POSTPROCESS_COMMAND += " do_swinventory_image; "
