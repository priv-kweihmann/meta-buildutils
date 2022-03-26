## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2022, Konrad Weihmann
##
## Automatically check if UPGRADE_STATUS check is working
## warn if it's not

python do_upgrade_check() {
    from oe.recipeutils import _get_recipe_upgrade_status
    _, status, _, _, _, _, _ = _get_recipe_upgrade_status(d)
    if status not in ["MATCH", "UPDATE", "KNOWN_BROKEN"]:
        bb.warn("UPSTREAM_CHECK is broken [status = %s], please check variables UPSTREAM_CHECK_REGEX, UPSTREAM_CHECK_URI and others" % status)
}
do_upgrade_check[network] = '1'

addtask do_upgrade_check after do_unpack before do_build
