# bitbake-listvars

List all defined variables

## Usage

From a setup OE/Yocto build

```shell
<path to checkout>/scripts/bitbake-listvars $(which bitbake)
```

to extract all the variables from the known recipes use

```shell
<path to checkout>/scripts/bitbake-listvars -a $(which bitbake)
```

**NOTE**: that will take significantly longer
