#
# Removes orphaned logs after build
#
# To use it add that line to conf/local.conf:
#
# INHERIT += "rm_orphans"
#

python do_rm_orphans () {
    import glob
    import os
    import sys

    _oldcwd = os.getcwd()
    os.chdir(d.getVar("T"))
    _symlinks = [x for x in glob.glob("*") if os.path.islink(x)]
    for _link in _symlinks:
        for _f in glob.glob(_link + ".*"):
            if os.path.abspath(os.readlink(_link)) != os.path.abspath(_f):
                os.remove(_f)
    os.chdir(_oldcwd)
}

# Run it as a postfuncs of do_build
do_package_qa[postfuncs] += "do_rm_orphans"
do_populate_sdk[postfuncs] += "do_rm_orphans"
do_image_complete[postfuncs] += "do_rm_orphans"
