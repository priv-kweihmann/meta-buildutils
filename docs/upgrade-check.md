# upgrade-check

Automatically check if UPGRADE_STATUS check is working correctly

## Usage

Add

```bitbake
INHERIT += "upgrade-check"
```

to your local.conf

## Configuration

- UPGRADE_CHECK_IGNORE - Space separated regex for PN to skip check on recipe
