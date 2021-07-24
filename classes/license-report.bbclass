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
    if not (d.getVar("LICENSE_CREATE_PACKAGE") or ""):
        bb.fatal("'LICENSE_CREATE_PACKAGE' needs to be enabled. Can't proceed")
    for item in (d.getVar("LICENSE_REPORT_FORMATS") or "").split(" "):
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
            subprocess.check_call(_cmd, shell=True)
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

def license_report_intermediate_report(_map):
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

python do_license_report() {
    import os
    import shutil

    from oe.rootfs import image_list_installed_packages
    from oe.packagedata import has_subpkgdata, read_subpkgdata_dict 
    
    _temppath = d.expand("${T}/pkgtmp")
    os.makedirs(_temppath, exist_ok=True)
    _map = {}

    img_type = d.getVar('IMAGE_PKGTYPE')
    if img_type == "rpm":
        from oe.package_manager.rpm import RpmPM
        from oe.package_manager.rpm.manifest import RpmManifest

        manifest = RpmManifest(d, None)
        pm = RpmPM(d, _temppath, d.getVar('TARGET_VENDOR'))
    elif img_type == "ipk":
        from oe.package_manager.ipk import OpkgPM
        from oe.package_manager.ipk.manifest import OpkgManifest

        manifest = OpkgManifest(d, None)
        pm = OpkgPM(d, _temppath, d.getVar("IPKGCONF_TARGET"), d.getVar("ALL_MULTILIB_PACKAGE_ARCHS"))
        pm.write_index()
        pm.update()
    elif img_type == "deb":
        from oe.package_manager.deb import DpkgPM
        from oe.package_manager.deb.manifest import DpkgManifest

        manifest = DpkgManifest(d, None)
        pm = DpkgPM(d, _temppath, d.getVar('PACKAGE_ARCHS'), d.getVar('DPKG_ARCH'))
        pm.insert_feeds_uris(d.getVar('PACKAGE_FEED_URIS') or "",
                             d.getVar('PACKAGE_FEED_BASE_PATHS') or "",
                             d.getVar('PACKAGE_FEED_ARCHS'))
        bb.utils.mkdirhier(d.expand("${IMAGE_ROOTFS}/var/lib/dpkg/alternatives"))
        pm.write_index()
        pm.update()
        
    for pkg in image_list_installed_packages(d):
        _licpkg = "{}-lic".format(pkg)
        if not has_subpkgdata(_licpkg, d):
            continue
        # translate packagename to workaround debian renaming
        _recipeinfo = read_subpkgdata_dict(_licpkg, d)
        _licpkg = _recipeinfo.get("PKG", _licpkg)
        if img_type == "rpm":
            bb.utils.mkdirhier(os.path.join(_temppath, "etc/dnf/vars/"))
            bb.utils.mkdirhier(os.path.join(_temppath, "var/lib/rpm/"))
            open(oe.path.join(_temppath, "etc/dnf/dnf.conf"), 'w').write("")
        if img_type == "deb":
            bb.utils.mkdirhier(os.path.join(_temppath, "etc/apt/apt.conf.d/"))
            bb.utils.mkdirhier(os.path.join(_temppath, "etc/apt/sources.list.d/"))
            bb.utils.mkdirhier(os.path.join(_temppath, "var/lib/dpkg/"))
            bb.utils.mkdirhier(os.path.join(_temppath, "var/lib/dpkg/alternatives"))
        try:
            _tmpdir = pm.extract(_licpkg)
            _x = license_report_walk_tree(d, read_subpkgdata_dict(_licpkg, d), _tmpdir)
            if _x:
                _map[pkg] = _x
            shutil.rmtree(_tmpdir, ignore_errors=True)
        except Exception as e:
            bb.warn("General exception:" + str(e))
    
    with open(d.getVar("LICENSE_REPORT_INTERMEDIATE"), "w") as o:
        o.write(license_report_intermediate_report(_map))

    bb.build.exec_func("do_license_report_export", d)
}
do_rootfs[postfuncs] += "do_license_report"
do_license_report[doc] = "create a license report from all used packages"
