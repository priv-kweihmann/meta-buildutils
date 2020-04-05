## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2019, Konrad Weihmann

def buildutils_find_in_layer(d, _file, _skipPath=""):
    import os
    import glob
    for _dir in [x for x in d.getVar("BBLAYERS").split(" ") if x]:
        files = [x for x in glob.glob("{}/**/{}".format(_dir, _file), recursive=True) if x != _skipPath]
        if any(files):
            return files[0]
    return None

def buildutils_get_files_by_shebang(d, path, pattern, excludes=[]):
    import os
    import re
    res = []
    pattern = r"^#!\s*{}".format(pattern)
    for root, dirs, files in os.walk(path, topdown=True):
        for item in files:
            _filename = os.path.join(root, item)
            if _filename in excludes:
                continue
            try:
                with open(_filename, "r") as f:
                    cnt = f.readlines()
                    if cnt:
                        cnt = cnt[0]
                        if re.match(pattern, cnt):
                            res.append(_filename)
            except:
                pass
    return [x for x in res if os.path.isfile(x)]

def buildutils_get_files_by_extension(d, path, pattern, excludes=[]):
    import os
    res = []
    if isinstance(pattern, str):
        pattern = pattern.split(" ")
    for root, dirs, files in os.walk(path, topdown=True):
        for item in files:
            _filepath = os.path.join(root, item)
            if _filepath in excludes:
                continue
            _filename, _file_extension = os.path.splitext(_filepath)
            if _file_extension in pattern:
                res.append(_filepath)
    return [x for x in res if os.path.isfile(x)]

def buildutils_get_files_by_extension_or_shebang(d, path, shebang, extensions, excludes=[]):
    return sorted(list(set(buildutils_get_files_by_shebang(d, path, shebang, excludes) + \
                           buildutils_get_files_by_extension(d, path, extensions, excludes))))
