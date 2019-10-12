## This class does sanity check if a 
## variable is not altered by a .bbappend-file
## To 'protect' the variable just insert any
## valid regular expression into LAYER_SANITY_PROT_VARS
## and inherit this class into any recipe
##
## On a finding the build will issue an error
## telling you want has changed
LAYER_SANITY_PROT_VARS ?= "\
                            SRC_URI.* \
                            IMAGE_INSTALL.*\
                            LICENSE.* \
                            EXTRA_OEMAKE.* \
                            ALTERNATIVE_PRIORITY.* \
                        "
## Futhermore you can 'protect' files from being overloaded
## by any bbappend
## Just place the filename (with relative path if needed)
## in the following space separated list
LAYER_SANITY_PROT_FILES ?= "defconfig"

def prep_clean_datasmart(d):
    import bb.data_smart
    import copy

    newd = bb.data_smart.DataSmart()
    newd.dict["_data"] = copy.deepcopy(d.dict["_data"])
    return newd

python do_layer_safety() {
    import copy
    import logging
    from bb.parse.parse_py import ConfHandler, BBHandler
    import re

    base_file = d.getVar("FILE")
    appends = d.getVar("BBINCLUDED") or ""
    appends = list(set([x for x in appends.split(" ") if x and x != base_file and x.strip().endswith(".bbappend")]))

    prot_keys = [x for x in d.getVar("LAYER_SANITY_PROT_VARS").split(" ") if x]

    ## Because the hacking effeorts put into this class
    ## it might happen that there will be a double inclusion warning
    ## issued - we just suppress them in global logger
    lvl_bef = logging.getLogger("BitBake").getEffectiveLevel()
    logging.getLogger("BitBake").setLevel(logging.CRITICAL)

    ## Check for variables
    findings = []
    base_d = prep_clean_datasmart(d)
    ConfHandler.include_single_file(None, base_file, 1, base_d, None)
    whitelist_keys = ["_data", "_depends"]
    for a in appends:
        new_d = prep_clean_datasmart(base_d)
        BBHandler.handle(a, new_d, 1)
        for k,v in base_d.dict.items():
            if k not in whitelist_keys and new_d.getVar(k) and k[0].isupper() and any([re.match(x, k) for x in prot_keys]):
                old_var = base_d.getVar(k)
                new_var = new_d.getVar(k)
                if old_var.find(" ") != -1:
                    old_var = " ".join(sorted(list(set([x for x in old_var.split(" ") if x]))))
                if new_var.find(" ") != -1:
                    new_var = " ".join(sorted(list(set([x for x in new_var.split(" ") if x]))))
                if old_var != new_var:
                    findings.append("Value {} changed from '{}' to '{}' by one of the following appends {}".format(\
                                    k, old_var, new_var, sorted(appends)))
    logging.getLogger("BitBake").setLevel(lvl_bef)

    ## Check for files
    lookup_paths = [x for x in d.getVar("FILESEXTRAPATHS").split(":") if x]
    lookup_paths += [x for x in d.getVar("FILESPATH").split(":") if x]
    lookup_paths = list(set(sorted(lookup_paths)))
    for item in [x for x in d.getVar("LAYER_SANITY_PROT_FILES").split(" ") if x]:
        hit_count = 0
        for path in lookup_paths:
            if os.path.exists(os.path.join(path, item)):
                hit_count += 1
        if hit_count > 1:
            findings.append("File '{}' is overloaded by at least one of the following appends {}".format(item, sorted(appends)))
    
    ## Show results
    findings = list(set(findings))
    for item in findings:
        bb.error(item)
}

do_compile[prefuncs] += "do_layer_safety"