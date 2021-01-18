# newlayercheck

This script checks a layer if it will change or even corrupt an existing stack of layers.
It identifies bbappend, overwritten files and recipes with higher versions than the ones already used

## Usage

```shell
./newlayercheck <path to already used layer 1> [<path to already used layer2> ...] <path to layer>
```

## Output

All advise will be given to stdout

### Checks

By default all checks are performed. You can disable certain checks by passing `--disablecheck=<check>` via CLI.

| check    | summary                                                       |
| -------- | ------------------------------------------------------------- |
| version  | Check for recipes with version >= than the ones already known |
| bbappend | Check on bbappends                                            |
| files    | Check on files that overwrite existing files                  |
