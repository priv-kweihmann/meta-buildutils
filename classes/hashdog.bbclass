# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2020, Konrad Weihmann
#
# This class identifies variables used in tasks
# which lead to sstate corruptions as they either
# point to local hardcoded paths or are known to
# be specific to a build host
#
# each found issue will be reported as a warning to console

# variables known to be build host specific
HASHDOG_CULP ?= "DATETIME"
# exclude the following variables as they are not being used for
# creating the task hash
HASHDOG_EXCL ?= "${BB_HASHCONFIG_WHITELIST} ${BB_HASHBASE_WHITELIST} prefix"

def hashdog_get_varset(d, varname, res={}):
    for x in d.expandWithRefs(d.getVar(varname, False), varname).references or set():
        _flags = d.getVarFlags(varname) or {}
        if "vardepsexclude" in _flags and x in (_flags["vardepsexclude"] or "").split(" "):
            continue
        res[x] = d.getVar(x, False)
        hashdog_get_varset(d, x, res=res)
    return res

python do_hashdog() {
    import os
    _glob_excludes = set((d.expand("${HASHDOG_EXCL}") or "").split())
    _glob_culprits = set((d.expand("${HASHDOG_CULP}") or "").split())
    for k in d.keys():
        _flags = d.getVarFlags(k) or []
        if "func" in _flags and k.startswith("do_"):
            res = hashdog_get_varset(d, k, {})
            _excludes = set(_glob_excludes)
            if "vardepsexclude" in _flags:
                _excludes.update((d.getVarFlag(k, "vardepsexclude") or "").split())
            for _k, _v in res.items():
                _hit = _k in _glob_culprits
                if (_v or "").startswith("/") and os.path.exists(d.getVar(_k)):
                    _hit |= True
                if _hit and _k not in _excludes:
                    bb.warn("Task '{}' uses {} with the value of '{}' - this could lead to sstate corruptions.\nConsider adding '{}[vardepsexclude] += \"{}\"' to the recipe".format(k, _k, _v, k, _k))
}

addtask do_hashdog before do_build
