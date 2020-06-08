# rootfs-chart

This class generates additonal dot-graphs for an image recipe, where this class is inherited to.

- **\$DEPLOY_DIR_IMAGE/\$PN-packages.dot** - will show a graph with all packages installed to the image and there dependencies, which are (obviously) also installed
- **\$DEPLOY_DIR_IMAGE/\$PN-recipes.dot** - will show all recipes involved in generating the image. This includes _native_ and _cross_ recipes as well.
Only the pure recipe-basename is shown
- **\$DEPLOY_DIR_IMAGE/\$PN-package-map.json** - will dump a key-value json mapping the packages to recipes

## Usage

Add e.g. to any image recipe

```bitbake
inherit rootfs-chart
```
