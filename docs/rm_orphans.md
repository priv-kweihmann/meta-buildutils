# rm_orphans

This class can be included globally (meaning in the distro or local.conf) to remove the leftover log-files, which bitbake leaves for whatever reason in each recipe's TEMP-dir. After this process only files (run + log) from the last run will remain.
This should help mitigating the excessive disk spamming of bitbake

## Usage

Add e.g. to local.conf

```bitbake
INHERIT += "rm_orphans"
```
