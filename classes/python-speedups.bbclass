## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2019, Konrad Weihmann
## This implements several to speedup python startup time
## when running on target

PYTHON_SPEEDUP_TARGETS ?= "no_sitepackage binary_tweak compile_all"


## Implementation
ROOTFS_POSTPROCESS_COMMAND += "do_python_speedups;"
DEPENDS += "python3-native coreutils-native"

python do_python_speedups() {
    import bb
    for item in d.getVar("PYTHON_SPEEDUP_TARGETS").split(" "):
        bb.build.exec_func(item, d)
}

## This function remove the site-packages directory
## by copying all files into python lib-dir
## This reduces the lookup time of python imports
no_sitepackage() {
    pydir=$(find ${IMAGE_ROOTFS}${libdir} -type d -name "python*" | head -n 1)
    if [ -z ${pydir} ]; then
        ## Image does not contain a python-library
        bbnote "Can't locate python3 binary in image"
        exit 0
    fi
    if [ -d ${pydir}/site-packages ]; then
        if [ -d ${pydir}/site-packages/__pycache__ ]; then
            ## as __pycache__-folder already exists in parent dir it can't be moved
            ## so we copy the elements first
            cp -R ${pydir}/site-packages/__pycache__/* ${pydir}/__pycache__/
            rm -rf ${pydir}/site-packages/__pycache__/
        fi
        ## Sanity check on name-conflicts
        cd ${pydir}/site-packages/
        for _f in $(find -maxdepth 1); do
            if [ ! -f $(basename ${_f}) ] && [ ! -f $(basename ${_f}) ]; then
                continue
            fi
            if [ -e ${pydir}/$(basename ${_f}) ]; then
                bbfatal "Name-conflict: '$(basename ${_f})' exits in site-packages and core-library\nCan't proceed"
            fi
        done
        cd -
        mv ${pydir}/site-packages/* ${pydir}/

        ## create a symlink-directory to ensure code, using hardcoded-paths is 
        ## working after patching
        sympath=$(realpath --relative-to="${IMAGE_ROOTFS}" "${pydir}")
        rm -rf ${pydir}/site-packages
        ln -sf /${sympath} ${pydir}/site-packages
    fi
}

## This function replace the standard python3 binary run
## with python running with options -B -u -S
## this drastically reduces lookupp time of imports
## can only be used in combination with no_sitepackage-function
python binary_tweak() {
    import os
    import bb
    import glob

    if not "no_sitepackage" in d.getVar("PYTHON_SPEEDUP_TARGETS").split(" "):
        bb.error("binary_tweak can only be used in comibnation with no_sitepackage")
        return
    tmp = os.path.join(d.getVar("bindir"), "python3")
    if tmp.startswith("/"):
        tmp = tmp[1:]
    tweak_path = os.path.join(d.getVar("IMAGE_ROOTFS"), tmp)

    ## Lockup name of the real binary
    rel_binary = [x for x in glob.glob(tweak_path + "*") if os.path.isfile(x)]
    if not any(rel_binary):
        bb.note("Can't locate python3 binary in image")
        return

    rel_binary = os.path.basename(rel_binary[0])

    os.remove(tweak_path)
    with open(tweak_path, "w") as o:
        o.write("#!/bin/sh\n")
        o.write("{} -B -u -S \"$@\"\n".format(os.path.join(d.getVar("bindir"), rel_binary)))

    os.chmod(tweak_path, 0o755)
}

## This function force a compile of all python files
## in complete image
compile_all() {
    pydir=$(find ${IMAGE_ROOTFS}${libdir} -type d -name "python*" | head -n 1)
    if [ -z ${pydir} ]; then
        bbnote "Can't locate python3 binary in image"
        ## Image does not contain a python-library
        exit 0
    fi
    ## We will force a compileall run on the resulting python-library
    ## do precompile the leftovers
    if [ -d ${pydir} ]; then
        cd ${pydir}/
            ${STAGING_BINDIR_NATIVE}/python3-native/python3 -m compileall
        cd -
    fi
}