## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2022, Konrad Weihmann
##
## Automatically check if UPGRADE_STATUS check is working
## warn if it's not

UPGRADE_CHECK_IGNORE ?= "npm-.*"

python do_upgrade_check() {
    import re

    if any(re.match(x, d.getVar("PN")) for x in d.getVar("UPGRADE_CHECK_IGNORE").split(" ") if x):
        return

    from oe.recipeutils import _get_recipe_upgrade_status

    dc = d.createCopy()
    # only add the very first time into the check
    _new = (d.getVar("SRC_URI") or "").strip().split(" ")[0]

    if str(dc.getVar("SRCREV")) in ["INVALID"]:
        # in case we only have named uris (name= in uri)
        # we will create a valid SRCREV from that resource
        # and remove the name from the uri
        # as otherwise the upgrade-check will fail
        # for various reasons
        _dict = {}
        for item in _new.split(";"):
            if "=" not in item:
                continue
            x = item.split("=")
            _dict[x[0].strip()] = x[1].strip()

        _rev = d.getVar("SRCREV_{}".format(_dict.get("name")))
        _new = _new.replace(";name={}".format(_dict.get("name")), "")
        dc.setVar("SRCREV", _rev)

    dc.setVar("SRC_URI", _new)

    _, status, _, _, _, _, _ = _get_recipe_upgrade_status(dc)
    if status not in ["MATCH", "UPDATE", "KNOWN_BROKEN", "UNKNOWN"]:
        bb.warn("UPSTREAM_CHECK is broken [status = %s], please check variables UPSTREAM_CHECK_REGEX, UPSTREAM_CHECK_URI and others" % status)
}
do_upgrade_check[network] = '1'

addtask do_upgrade_check before do_build
