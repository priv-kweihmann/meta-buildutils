# license-report

This class generates a single document export of all the license texts used in an image.

## Usage

Add e.g. to any image recipe

```bitbake
inherit license-report
```

don't forget to add `LICENSE_CREATE_PACKAGE = "1"` to your `local.conf` or `distro.conf`

## Additional exports

In case you want to export to other formats than `markdown`, you need to install `pandoc` and `pdflatex` to your host.
In addition you need to add them to your `local.conf` or `distro.conf` `HOSTTOOLS` list

```bitbake
HOSTTOOLS += "pandoc pdflatex"
```

## Configuration

you can fine tune the behavior of the class with the following parameters

- **LICENSE_REPORT_FILE_EXCEPTION** - files that should not be part of the report: __default__ `generic-*`
- **LICENSE_REPORT_FILENAME** - path and name of the report file: __default__ `${DEPLOY_DIR_IMAGE}/${IMAGE_BASENAME}-${MACHINE}.license-report`
- **LICENSE_REPORT_FORMATS** - export formats: __default__ `md`, __available__ `md, pdf, html`
- **LICENSE_REPORT_LIC_EXCEPTION** - licenses that should not be part of the report: __default__ `CLOSED`
- **LICENSE_REPORT_PREAMBLE** - Custom markdown text to add to the report
