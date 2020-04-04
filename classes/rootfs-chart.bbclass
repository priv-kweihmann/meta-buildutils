def rootfs_get_tasks_deps(d, name, seen=[]):
    import oe.sstatesig
    import pickle
    import os

    out = []
    _siginfo = oe.sstatesig.find_siginfo(name, "do_prepare_recipe_sysroot", None, d)
    if _siginfo:
        _latest = [k for k, v in sorted(_siginfo.items(), key=lambda item: item[1], reverse=True)][0]
        with open(_latest, 'rb') as f:
            _p = pickle.Unpickler(f)
            for a in _p.load()['runtaskdeps']:
                _clean = "_".join(os.path.basename(a.split(":")[0]).split("_")[:-1])
                if _clean in seen:
                    continue
                seen.append(_clean)
                out.append({"name": name, "dep": _clean, "recipe": _clean})
                _tmp = rootfs_get_tasks_deps(d, _clean, seen)
                if _tmp:
                    out += _tmp
                else:
                    out.append({"name": _clean, "dep": "", "recipe": _clean})
    return out

def rootfs_get_rootfs_info_rec(d, name, pkgmap, seen=[]):
    import oe.packagedata
    import re
    out = []
    pkgdata = oe.packagedata.read_subpkgdata_dict(name, d)
    if "RDEPENDS" in pkgdata:
        _clean = re.sub(r"\(.*?\)", "", pkgdata["RDEPENDS"])
        for r in [x for x in _clean.split(" ") if x]:
            if r in seen:
                continue
            try:
                _key = pkgmap[r] if r in pkgmap else r
                out.append({"name": name, "dep": r, "recipe": _key})
                seen.append(r)
                _tmp = rootfs_get_rootfs_info_rec(d, r, pkgmap, seen)
                if _tmp:
                    out += _tmp
                else:
                    out.append({"name": r, "dep": "", "recipe": _key})
            except:
                bb.warn(r)
                pass
    return out

def rootfs_generate_output(d, stash, output):
    report = set()
    label = set()
    for k in stash:
        if not k["name"]:
            continue
        label.add("\"{}\" [shape=component]".format(k["name"]))
        if not k["dep"]:
            continue
        label.add("\"{}\" [shape=component]".format(k["dep"]))
        if k["dep"] == k["name"]:
            continue
        report.add("\"{}\" -> \"{}\"".format(k["dep"], k["name"]))
    with open(output, "w") as o:
        o.write("digraph D {{\nrankdir=\"LR\"\n{}\n{}\n}}".format("\n".join(sorted(label)), "\n".join(sorted(report))))

python do_rootfs_chart_packages() {
    from oe.rootfs import image_list_installed_packages
    import oe.packagedata

    pkgmap = oe.packagedata.pkgmap(d)

    out = []
    for k in image_list_installed_packages(d):
        _key = pkgmap[k] if k in pkgmap else k
        out.append({"name": d.getVar("PN"), "dep": k, "recipe": _key})
        out += rootfs_get_rootfs_info_rec(d, k, pkgmap)

    rootfs_generate_output(d, out, d.expand("${DEPLOY_DIR_IMAGE}/${PN}-packages.dot"))
}

python do_rootfs_chart_recipes() {
    from oe.rootfs import image_list_installed_packages
    import oe.packagedata

    _image = d.getVar("PN")
    pkgmap = oe.packagedata.pkgmap(d)

    out = rootfs_get_tasks_deps(d, _image)
    for k in image_list_installed_packages(d):
        _key = pkgmap[k] if k in pkgmap else k
        out.append({"name": _image, "dep": _key, "recipe": _key}) 
        out += rootfs_get_tasks_deps(d, k)
        
    rootfs_generate_output(d, out, d.expand("${DEPLOY_DIR_IMAGE}/${PN}-recipes.dot"))
}

ROOTFS_POSTPROCESS_COMMAND += " do_rootfs_chart_recipes; do_rootfs_chart_packages; "
