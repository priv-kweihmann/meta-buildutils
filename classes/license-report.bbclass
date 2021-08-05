# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021, Konrad Weihmann
#
# create a license report for packages installed to an image
# Usage:
# 
# add inherit license-report to any of your images
# add LICENSE_CREATE_PACKAGE = "1" to your local.conf or distro.conf settings
# 
# optional:
# 
# if you want to have other than the markdown export
# you need to install pandoc and pdflatex to your host
# and add HOSTTOOLS += "pandoc pdflatex" to your local.conf or distro.conf
#
# Note: debian packages sometimes create non-utf8 files, those will be ignored for the export
#       please stick to rpm or ipk to have a proper export

addhandler license_report_handler
license_report_handler[eventmask] = "bb.event.SanityCheck bb.event.RecipeParsed"
python license_report_handler() {
    if (d.getVar("LICENSE_CREATE_PACKAGE") or "") != "1":
        bb.fatal("'LICENSE_CREATE_PACKAGE' needs to be enabled. Can't proceed")
    for item in (d.getVar("LICENSE_REPORT_FORMATS") or "").split(" "):
        if not item.strip():
            continue
        for tool in (d.getVarFlag("LICENSE_REPORT_FORMATS", item) or "").split(" "):
            if not tool:
                continue
            if tool not in d.getVar("HOSTTOOLS").split(" "):
                bb.fatal("'LICENSE_REPORT_FORMATS' sets {}, but required tool {} is not installed or not part of 'HOSTTOOLS'".format(item, tool))
}

# basename of the exported report file
LICENSE_REPORT_FILENAME ??= "${DEPLOY_DIR_IMAGE}/${IMAGE_BASENAME}-${MACHINE}.license-report"

# formats to export
LICENSE_REPORT_FORMATS ??= "md"
LICENSE_REPORT_FORMATS[html] = "pandoc"
LICENSE_REPORT_FORMATS[md] = "cp"
LICENSE_REPORT_FORMATS[pdf] = "pandoc pdflatex"

LICENSE_REPORT_EXPORT[html] = "pandoc --toc -o ${LICENSE_REPORT_FILENAME}.html ${LICENSE_REPORT_INTERMEDIATE}"
LICENSE_REPORT_EXPORT[md] = "cp -f ${LICENSE_REPORT_INTERMEDIATE} ${LICENSE_REPORT_FILENAME}.md"
LICENSE_REPORT_EXPORT[pdf] = "pandoc --toc -o ${LICENSE_REPORT_FILENAME}.pdf ${LICENSE_REPORT_INTERMEDIATE}"

LICENSE_REPORT_INTERMEDIATE ?= "${T}/report.md"

# Licenses to exclude from export (could be a space separated list)
LICENSE_REPORT_LIC_EXCEPTION = "CLOSED"
# Files to ignore in report (could be a space separated list of regex)
LICENSE_REPORT_FILE_EXCEPTION = "generic-*"

# Additional text to add to the report header
LICENSE_REPORT_PREAMBLE ??= ""

python do_license_report_export() {
    import subprocess

    for item in (d.getVar("LICENSE_REPORT_FORMATS") or "").split(" "):
        _cmd = d.getVarFlag("LICENSE_REPORT_EXPORT", item)
        try:
            subprocess.check_call(_cmd or "exit 1", shell=True)
        except subprocess.CalledProcessError as e:
            bb.warn("License-report export to {format} failed with {e}".format(format=item, e=e))
}

def license_report_walk_tree(d, recipeinfo, base):
    import re

    _lic_exceptions = (d.getVar("LICENSE_REPORT_LIC_EXCEPTION") or "").split(" ")
    _file_exceptions = (d.getVar("LICENSE_REPORT_FILE_EXCEPTION") or "").split(" ")
    _map = {"licenses": [], "recipeinfo": recipeinfo }
    if _map["recipeinfo"].get("LICENSE", "CLOSED") in _lic_exceptions:
        return {}
    for root, dirs, files in os.walk(base):
        for f in files:
            _filepath = os.path.join(root, f)
            if not os.path.isfile(_filepath):
                continue
            if not any(re.match(x, os.path.basename(_filepath)) for x in _file_exceptions):
                try:
                    with open(_filepath) as i:
                        _map["licenses"].append(i.read().strip())
                except UnicodeDecodeError:
                    bb.warn("Can't decode {} - ignoring this file".format(_filepath))
    return _map

def license_report_intermediate_report(d, _map):
    import datetime

    _res = "# License report\n\nCreated at {date}\n".format(date=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    if d.getVar("LICENSE_REPORT_PREAMBLE"):
        _res += "\n" + d.getVar("LICENSE_REPORT_PREAMBLE") + "\n"
    _res += "\n"
    for k,v in sorted(_map.items()):
        _res += "## {comp} - Version {ver}\n\n".format(comp=k, ver=v["recipeinfo"]["PV"])
        _res += "**licensed under {lic}**\n\n".format(lic=v["recipeinfo"]["LICENSE"])
        for lic in v["licenses"]:
            _res += "```text\n"
            _res += lic + "\n"
            _res += "```\n\n"
    return _res

def license_report_get_from_rprovides(dc, pkg):
    import oe.packagedata

    pkg_info = os.path.join(dc.getVar('PKGDATA_DIR'), 'runtime-rprovides', pkg, pkg)
    if os.path.exists(pkg_info):
        _info = oe.packagedata.read_pkgdatafile(pkg_info)
        bb.debug(2, "rprovides: {} -> {}".format(pkg, _info.get("PKG_" + pkg, "")))
        return _info.get("PKG_" + pkg, "")
    return ""

def license_report_get_from_reverse(dc, pkg, with_rcomm=False):
    import oe.packagedata

    pkg_info = os.path.join(dc.getVar('PKGDATA_DIR'), 'runtime-reverse', pkg)
    if os.path.exists(pkg_info):
        _info = oe.packagedata.read_pkgdatafile(pkg_info)
        if with_rcomm:
            for k, _ in _info.items():
                if k.startswith("RRECOMMENDS_"):
                    _rcomm = [x for x in _info.get(k, "").split(" ") if x.endswith("-lic")]
                    if _rcomm:
                        return license_report_get_from_rprovides(dc, _rcomm[0])
        return _info.get("PN", "") + "-lic"
    return ""

def license_report_pkg_exists(dc, pkg):
    import glob
    return any(glob.glob(os.path.join(dc.getVar("DEPLOY_DIR"), dc.getVar("IMAGE_PKGTYPE"), "*", pkg + "*")))

python do_license_report() {
    # exit if reporting is disabled
    if not d.getVar("LICENSE_REPORT_FORMATS"):
        return

    import os
    import json
    import shutil

    from oe.rootfs import image_list_installed_packages
    from oe.packagedata import has_subpkgdata, read_subpkgdata_dict 
    
    _temppath = d.expand("${T}/pkgtmp")
    os.makedirs(_temppath, exist_ok=True)
    _map = {}

    dc = d.createCopy()
    dc.setVar("IMAGE_ROOTFS", _temppath)

    img_type = d.getVar('IMAGE_PKGTYPE')
    if img_type == "rpm":
        from oe.package_manager.rpm import RpmPM
        from oe.package_manager.rpm.manifest import RpmManifest

        manifest = RpmManifest(dc, None)
        pm = RpmPM(dc, dc.getVar('IMAGE_ROOTFS'), dc.getVar('TARGET_VENDOR'),
                   rpm_repo_workdir="oe-rootfs-repo-lr")
        pm.create_configs()
        pm.write_index()
        pm.update()
    elif img_type == "ipk":
        from oe.package_manager.ipk import OpkgPM
        from oe.package_manager.ipk.manifest import OpkgManifest

        manifest = OpkgManifest(dc, None)
        pm = OpkgPM(dc, dc.getVar('IMAGE_ROOTFS'), dc.getVar("IPKGCONF_TARGET"), dc.getVar("ALL_MULTILIB_PACKAGE_ARCHS"))
        pm.write_index()
        pm.update()
    elif img_type == "deb":
        from oe.package_manager.deb import DpkgPM
        from oe.package_manager.deb.manifest import DpkgManifest

        manifest = DpkgManifest(dc, None)
        pm = DpkgPM(dc, dc.getVar('IMAGE_ROOTFS'), dc.getVar('PACKAGE_ARCHS'), dc.getVar('DPKG_ARCH'))
        pm.insert_feeds_uris(dc.getVar('PACKAGE_FEED_URIS') or "",
                             dc.getVar('PACKAGE_FEED_BASE_PATHS') or "",
                             dc.getVar('PACKAGE_FEED_ARCHS'))
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/dpkg/alternatives"))
        pm.write_index()
        pm.update()

    if img_type == "rpm":
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/dnf/vars/"))
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/rpm/"))
        open(dc.expand("${IMAGE_ROOTFS}/etc/dnf/dnf.conf"), 'w').write("")
    if img_type == "deb":
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/apt/apt.conf.d/"))
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/apt/sources.list.d/"))
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/dpkg/"))
        bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/dpkg/alternatives"))

    with open(d.getVar("LICENSE_REPORT_PKGLIST")) as i:
        pkgs = json.load(i)

    bb.note("Found packages: {}".format(" ".join(pkgs)))

    for pkg in pkgs:
        bb.note("Try getting license for {}".format(pkg))
        _licpkg = None
        for needle in [license_report_get_from_reverse(dc, pkg),
                       license_report_get_from_reverse(dc, pkg, with_rcomm=True)]:
            if license_report_pkg_exists(dc, needle): ##has_subpkgdata(needle, dc) and 
                bb.note("{} uses {} as license package provider".format(pkg, needle))
                _licpkg = needle
                break
            _licpkg = None

        if not _licpkg:
            bb.note("No package data found for {}".format(pkg))
            continue
        if img_type == "rpm":
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/dnf/vars/"))
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/rpm/"))
            open(dc.expand("${IMAGE_ROOTFS}/etc/dnf/dnf.conf"), 'w').write("")
        if img_type == "deb":
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/apt/apt.conf.d/"))
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/etc/apt/sources.list.d/"))
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/dpkg/"))
            bb.utils.mkdirhier(dc.expand("${IMAGE_ROOTFS}/var/lib/dpkg/alternatives"))
        try:
            _tmpdir = pm.extract(_licpkg)
            _x = license_report_walk_tree(dc, read_subpkgdata_dict(_licpkg, dc), _tmpdir)
            if _x:
                _map[pkg] = _x
            shutil.rmtree(_tmpdir, ignore_errors=True)
        except Exception as e:
            bb.warn("General exception [{}/{}]:{}".format(pkg, _licpkg, e))

    bb.verbnote("Found {} license packages to report".format(len(_map.keys())))
    
    with open(d.getVar("LICENSE_REPORT_INTERMEDIATE"), "w") as o:
        o.write(license_report_intermediate_report(dc, _map))

    bb.build.exec_func("do_license_report_export", d)
}
addtask do_license_report after do_image before do_image_complete
do_license_report[doc] = "create a license report from all used packages"

ROOTFS_POSTPROCESS_COMMAND =+ " do_sca_image_pkg_list; "

LICENSE_REPORT_PKGLIST = "${T}/lr-pkgs.json"

python do_sca_image_pkg_list() {
    # Get the used packages in rootfs stage
    # in later stages the method does not return
    # the needed data
    import json
    from oe.rootfs import image_list_installed_packages
    with open(d.getVar("LICENSE_REPORT_PKGLIST"), "w") as o:
        json.dump(list(image_list_installed_packages(d).keys()), o)
}
