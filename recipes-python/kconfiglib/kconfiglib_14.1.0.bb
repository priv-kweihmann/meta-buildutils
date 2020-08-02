SUMMARY = "kconfiglib"
DESCRIPTION = "A flexible Python 2/3 Kconfig implementation and library"
HOMEPAGE = "https://github.com/ulfalizer/Kconfiglib"
LICENSE = "ISC"
LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=712177a72a3937909543eda3ad1bfb7c"

SRC_URI[md5sum] = "4ad68618824d4bad1d1de1d7eb838bba"
SRC_URI[sha256sum] = "bed2cc2216f538eca4255a83a4588d8823563cdd50114f86cf1a2674e602c93c"

DEPENDS += "python3-native"

PYPI_PACKAGE = "kconfiglib"

inherit setuptools3
inherit pypi

FILES_${PN} += "${datadir}/kconfiglib"

BBCLASSEXTEND = "native nativesdk"
