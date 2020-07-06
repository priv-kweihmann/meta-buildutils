## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2020, Konrad Weihmann

inherit swinventory-image

def _swinventory_image_unused_sanitizes_recipe_paths(d, _in):
    import os
    for b in d.getVar("BBPATH").split(":"):
        _rpl = os.path.dirname(b)
        _in = _in.replace(_rpl, "", 1)
    return _in.lstrip("/")

# This class lists all unused bitbake files from all layer
python do_swinventory_image_unused() {
    import json
    import glob
    
    used = set()
    files = [x for x in d.getVar("SWINVENTORY_IMAGE_COLLECTED_MANIFESTS").split(" ") if x]
    for k in files:
        try:
            content = json.load(k)
            used.update(content["recipes"])
        except:
            pass
    
    avail = set()
    for p in d.getVar("BBFILES").split(" "):
        if not p or not p.strip():
            continue
        avail.update([_swinventory_image_unused_sanitizes_recipe_paths(d, x) for x in glob.glob(p)])

    out = [x for x in avail if x not in used]   
    with open(d.expand("${DEPLOY_DIR_IMAGE}/${PN}-unused-bitbake.json"), "w") as o:
        json.dump(out, o, sort_keys=True, indent=2)
    
    d.setVar("SWINVENTORY_IMAGE_COLLECTED_MANIFESTS", " ".join(files))
}
do_swinventory_image[postfunc] += "do_swinventory_image_unused"
