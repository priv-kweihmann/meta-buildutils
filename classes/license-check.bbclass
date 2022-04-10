## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2022, Konrad Weihmann
##
## Check LIC_FILES_CHKSUM for consistency

LICENSE_CHECK_EXCLUDES ?= ""

def license_check_get_files(d):
    import os
    import re

    res = set()

    if d.getVar("S") == d.getVar("WORKDIR"):
        # avoid scanning complete workdirs
        # as this will only lead to false positives
        return res

    for root, _, files in os.walk(d.getVar("S"), followlinks=False):
        for f in files:
            _fullname = os.path.join(root, f)
            if not os.path.isfile(_fullname) or os.path.islink(_fullname):
                continue
            _filename = os.path.relpath(_fullname, d.getVar("S"))
            if (re.match(r"^.*-*\.*licen[sc]e(s)*-*\.*.*", f, re.IGNORECASE)
                or re.match(r"^.*-*\.*copying-*\.*.*", f, re.IGNORECASE)):
                res.add(_filename)            
    return res


python do_license_check() {
    _known_settings = [x.split(";")[0].replace("file://", "", 1) for x in d.getVar("LIC_FILES_CHKSUM").split(" ") if x]
    if not _known_settings:
        return

    _common = [x for x in _known_settings if x.startswith(d.getVar("COMMON_LICENSE_DIR"))]
    _found_files = license_check_get_files(d)
    _excluded = d.getVar("LICENSE_CHECK_EXCLUDES").split(" ")

    if _common and _found_files:
        bb.warn("COMMON_LICENSE_DIR is used although license information is present in {}".format(",".join(_found_files)))

    for f in _found_files:
        if f not in _known_settings and f not in _excluded:
            bb.warn("{lic} is not part of LIC_FILES_CHKSUM".format(lic=f))
}

addtask do_license_check after do_patch before do_install
