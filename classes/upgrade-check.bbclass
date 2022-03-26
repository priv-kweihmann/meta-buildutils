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
    _, status, _, _, _, _, _ = _get_recipe_upgrade_status(d)
    if status not in ["MATCH", "UPDATE", "KNOWN_BROKEN", "UNKNOWN"]:
        bb.warn("UPSTREAM_CHECK is broken [status = %s], please check variables UPSTREAM_CHECK_REGEX, UPSTREAM_CHECK_URI and others" % status)
}
do_upgrade_check[network] = '1'

addtask do_upgrade_check before do_build
