### This class does check kconfig style configuration for sanity

## Enable the check of config fragements against resulting config
KCONFIG_SANITY_FRAGMENT_EVAL ?= "1"
## Enable a detauled explanation why a symbol can't be applied
KCONFIG_SANITY_FRAGEMENT_KCONFIG_EXPLAIN ?= "1"
## Path to defconfig
KCONFIG_SANITY_DEFCONFIG ?= "${WORKDIR}/defconfig"
## Path to final config
KCONFIG_SANITY_FINALCONF ?= "${B}/.config"
## Prefix of KCONFIG var
KCONFIG_SANITY_CONFIG_PRE ?= "CONFIG_"
## Search path for config-fragments
KCONFIG_SANITY_FRAGMENT_PATH ?= "${WORKDIR}"
## Path where KConfig input files can be found
KCONFIG_SANITY_KCONFIGS ?= "${S}/KConfig ${S}/Config.in"

## Blacklist of items that shall not be checked
KCONFIG_SANITY_BLACKLIST ?= "EXTRA_CFLAGS"

DEPENDS += "kconfiglib-native"

## List of compare configurations, first hit wins
KCONFIG_SANITY_COMPAREFILES ?= "${WORKDIR}/compare-config.${MACHINE} ${WORKDIR}/compare-config"

## Set severity of warnings in complete mode
## can be error,warning or note
KCONFIG_SANITY_COMPLETE_NO_MATCH = "error"
KCONFIG_SANITY_COMPLETE_NEW_SET = "error"
KCONFIG_SANITY_COMPLETE_NEW_UNSET = "error"
KCONFIG_SANITY_COMPLETE_OLD_UNSET_EXISTS = "error"
KCONFIG_SANITY_COMPLETE_OLD_NA = "note"

## Set severity of warnings in fragment mode
## can be error,warning or note
KCONFIG_SANITY_FRAGMENT_NO_MATCH = "error"
KCONFIG_SANITY_FRAGMENT_NEW_SET = "warn"
KCONFIG_SANITY_FRAGMENT_NEW_UNSET = "note"
KCONFIG_SANITY_FRAGMENT_OLD_UNSET_EXISTS = "error"
KCONFIG_SANITY_FRAGMENT_OLD_NA = "note"

def call_logging_function(d, key, msg):
    import bb
    getattr(bb, d.getVar(key))(msg) 

def get_kconfig_symbols_needed(d, deps, result=[]):
    import kconfiglib
    if isinstance(deps, kconfiglib.Symbol):
        result.append(deps.name)
    else:
        for item in deps:
            if isinstance(item, tuple):
                result += get_kconfig_symbols_needed(d, item, result)
            if isinstance(item, kconfiglib.Symbol):
                result.append(item.name)
    return result

def get_kconfig_explanation(d, symbol):
    import os
    from kconfiglib import Kconfig, TRI_TO_STR, expr_str
    result = ""
    path_bef = os.getcwd()
    for item in d.getVar("KCONFIG_SANITY_KCONFIGS").split(" "):
        if not os.path.exists(item):
            continue
        os.chdir(os.path.dirname(item))
        kconf = Kconfig(item)
        neededSyms = get_kconfig_symbols_needed(d, kconf.syms[symbol].direct_dep)
        currentState = []
        for nSym in neededSyms:
            currentState.append("{}={}".format(nSym, kconf.syms[nSym].str_value))
        result = "{} does need {}. Currently set is {}".format(symbol, expr_str(kconf.syms[symbol].direct_dep), " ".join(currentState))
        call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_NO_MATCH", result)
        os.chdir(path_bef)
        return
    os.chdir(path_bef)
    bb.warn("No KConfig found - can't give explanation")

def get_kconfig_symbol_refs(d, symbol):
    import os
    from kconfiglib import Kconfig, TRI_TO_STR, expr_str
    result = ""
    path_bef = os.getcwd()
    for item in d.getVar("KCONFIG_SANITY_KCONFIGS").split(" "):
        if not os.path.exists(item):
            continue
        os.chdir(os.path.dirname(item))
        kconf = Kconfig(item)
        os.chdir(path_bef)
        if not symbol in kconf.syms:
            return []
        return get_kconfig_symbols_needed(d, kconf.syms[symbol].direct_dep)
    os.chdir(path_bef)
    return []

def get_config_files(d):
    import glob
    import os
    res = [d.getVar("KCONFIG_SANITY_DEFCONFIG")]
    tmp = [os.path.join(d.getVar("KCONFIG_SANITY_FRAGMENT_PATH"), x.replace("file://", "").strip()) for x in d.getVar("SRC_URI").split(" ") if x.endswith(".cfg") != -1]
    res += tmp
    return [x for x in res if os.path.isfile(x)]

def get_config_results(d):
    return [ d.getVar("KCONFIG_SANITY_FINALCONF") ]

def get_symbols_from_fragement(d, _file):
    import os
    import re
    res = []
    with open(_file) as f:
        for m in re.finditer(r"^(#\s+)*{}(?P<name>[A-Z0-9_]*)(=|\s)(?P<value>.*)\s*$".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE")), f.read(), re.MULTILINE):
            val = m.group("value")
            if val.find("is not set") != -1:
                val = None
            res.append({m.group("name"): val})
    return res

def convert_to_symbol_table(d, raw, _file, global_symbols):
    for x in raw:
        for k,v in x.items():
            if (k in global_symbols and v != global_symbols[k]) or (k not in global_symbols):
                 global_symbols[k] = {"value": v, "file": os.path.basename(_file)}
    return global_symbols

python do_kconfig_sanity_fragement() {
    import os
    import bb
    known_symbols = {}
    
    if d.getVar("KCONFIG_SANITY_FRAGMENT_EVAL") != "1":
        return

    for item in get_config_files(d):
        known_symbols[os.path.basename(item)] = convert_to_symbol_table(d, get_symbols_from_fragement(d, item), item, {})
    
    if not "devconfig" in known_symbols.keys():
        ## no defconfig no processing here
        return

    defconfig_sym = known_symbols["defconfig"]    
    for k,v in known_symbols.items():
        if v == defconfig_sym:
            continue
        warning_syms = []
        for ik, iv in v.items():
            syms = get_kconfig_symbol_refs(d, ik)
            syms = [x for x in syms if not x in ["y", "n", "m"]]
            for s in syms:
                if s not in v.keys() and s not in defconfig_sym.keys():
                    warning_syms.append(s)
        if any(warning_syms):
            call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_NO_MATCH", "{} must be set in either defconfig or {} to be active".format(",".join(warning_syms), k))
}

do_configure[postfuncs] += "do_kconfig_sanity_fragement"

python do_kconfig_sanity_result() {
    import os
    import bb

    if d.getVar("KCONFIG_SANITY_FRAGMENT_EVAL") != "1":
        return

    known_symbols = {}
    for item in get_config_files(d):
        known_symbols = convert_to_symbol_table(d, get_symbols_from_fragement(d, item), item, known_symbols)

    if not any(known_symbols):
        ## maybe scc is used ot what ever - we don't have any symbols - so quit here
        return

    final_symbols = get_symbols_from_fragement(d, d.getVar("KCONFIG_SANITY_FINALCONF"))

    found_symbols = []
    for item in final_symbols:
        fk = list(item.keys())[0]
        fv = item[fk]
        if fk in d.getVar("KCONFIG_SANITY_BLACKLIST").split(" "):
            found_symbols.append(fk)
            continue
        if fk in known_symbols.keys():
            found_symbols.append(fk)
            exp_val = known_symbols[fk]["value"]
            if not exp_val:
                exp_val = None
            if fv != exp_val:
                if d.getVar("KCONFIG_SANITY_FRAGEMENT_KCONFIG_EXPLAIN") == "1":
                    get_kconfig_explanation(d, fk)
                else:
                    call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_NO_MATCH", "{}{} was set to '{}' - config-file {} configured '{}'".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk, fv, os.path.basename(known_symbols[fk]["file"]), exp_val))
        elif fv is not None:
            call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_NEW_SET", "{}{} is set to '{}' but not defined by any config".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk, fv))
        elif fv is None:
            call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_NEW_UNSET", "{}{} is new but unset".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
    for fk in [x for x in known_symbols if x not in found_symbols]:
        refs = get_kconfig_symbol_refs(d, fk)
        if not any(refs):
            call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_OLD_UNSET_EXISTS", "{}{} was unset although it still exists".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
        else:
            call_logging_function(d, "KCONFIG_SANITY_FRAGMENT_OLD_NA", "{}{} is no existsing anymore".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
}

do_configure[postfuncs] += "do_kconfig_sanity_result"

python do_kconfig_complete() {
    import os
    import bb
    found_symbols = []
    if any([x for x in d.getVar("KCONFIG_SANITY_COMPAREFILES").split(" ") if os.path.isfile(x)]):
        cmp_config = [x for x in d.getVar("KCONFIG_SANITY_COMPAREFILES").split(" ") if os.path.isfile(x)][0]
        cmp_symbols = {}
        new_symbols = convert_to_symbol_table(d, get_symbols_from_fragement(d, cmp_config), item, {})

        final_symbols = get_symbols_from_fragement(d, d.getVar("KCONFIG_SANITY_FINALCONF"))
        for item in final_symbols:
            fk = list(item.keys())[0]
            fv = item[fk]
            if fk in d.getVar("KCONFIG_SANITY_BLACKLIST").split(" "):
                found_symbols.append(fk)
                continue
            if fk in cmp_symbols.keys():
                found_symbols.append(fk)
                exp_val = cmp_symbols[fk]["value"]
                if not exp_val:
                    exp_val = None
                if fv != exp_val:
                    ## abort
                    call_logging_function(d, "KCONFIG_SANITY_COMPLETE_NO_MATCH", "{}{} was set to '{}' - compare-file {} configured '{}'".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk, fv, os.path.basename(cmp_symbols[fk]["file"]), exp_val))
            elif fv is not None:
                ## abort
                call_logging_function(d, "KCONFIG_SANITY_COMPLETE_NEW_SET", "{}{} is set but '{}' not defined in compare-config".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk, fv))
            elif fv is None:
                ## Note
                call_logging_function(d, "KCONFIG_SANITY_COMPLETE_NEW_UNSET", "{}{} is new but unset".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
        for fk in [x for x in new_symbols if x not in found_symbols]:
            refs = get_kconfig_symbol_refs(d, fk)
            if not any(refs):
                call_logging_function(d, "KCONFIG_SANITY_COMPLETE_OLD_UNSET_EXISTS", "{}{} was unset although it still exists".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
            else:
                call_logging_function(d, "KCONFIG_SANITY_COMPLETE_OLD_NA", "{}{} is no existsing anymore".format(d.getVar("KCONFIG_SANITY_CONFIG_PRE"), fk))
}

do_configure[postfuncs] += "do_kconfig_complete"
