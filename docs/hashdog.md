# hashdog

The class identifies variables used in a task, which cause sstate corruptions, as they either point to a
local path or are known to be build host specific

## Usage

Add

```bitbake
INHERIT += "hashdog"
```

to your local.conf

## Configuration

- HASHDOG_CULP - sets variables, which are known to be build host specific
- HASHDOG_EXCL - sets the variables which are not taken into account for calculating the task hash
