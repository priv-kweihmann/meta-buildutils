# unused

The script tries to identify the recipes **not** used by any of the classes, append or recipes in the layer

## Usage

```shell
./unused <path to layer>
```

### Ignores

To exclude paths either specify them using the `--ignore` option (can be used multiple times) or add a file called `.unusedignore` to the layer dir - the content of the file is a json list containing the relative paths in the layer to ignore, e.g.

```json
[
    "foo/",
    "bar/baz/"
]
```
