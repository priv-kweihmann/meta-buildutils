## SPDX-License-Identifier: BSD-2-Clause
## Copyright (c) 2019, Konrad Weihmann
##
## This class does help to identify the needed python-packages
## to be put into RDEPENDS_${PN}
## It works on a package basis
## 
## This class is for python 2 only
## For python 3 please use python-package-ident.bbclass

inherit pythonnative
inherit buildutils-helper

PYTHON_MODULE_MANIFEST = "python-manifest.json"
inherit python-package-ident-core