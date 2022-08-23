# license-check

Automatically check if LIC_FILES_CHKSUM contains **all** license files

## Usage

Add

```bitbake
INHERIT += "license-check"
```

to your local.conf

## Configuration

- LICENSE_CHECK_EXCLUDES - List of files to exclude from the check (takes also glob style settings)
