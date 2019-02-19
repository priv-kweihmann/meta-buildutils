SUMMARY = "kconfiglib"
DESCRIPTION = "A flexible Python 2/3 Kconfig implementation and library"
HOMEPAGE = "https://github.com/ulfalizer/Kconfiglib"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=712177a72a3937909543eda3ad1bfb7c"

PV = "10.37.0"

SRC_URI[md5sum] = "294b7c256da427dc116a5518b2ea1051"
SRC_URI[sha256sum] = "7207ca85be9fe622d26c97fb520066b022562940687bdfac375e20f26e17965a"

DEPENDS += "python3-native"

PYPI_PACKAGE = "kconfiglib"

inherit setuptools3
inherit pypi

FILES_${PN} += "${datadir}/kconfiglib"

BBCLASSEXTEND = "native nativesdk"
