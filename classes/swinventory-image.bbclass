## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2020, Konrad Weihmann

inherit swinventory

# list of full paths to collected manifest files
# can be e.g. used by a postfunc to do further processing 
SWINVENTORY_IMAGE_COLLECTED_MANIFESTS = ""

def swinventory_image_get_package(d, name, out, files):
    import os
    import json

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
