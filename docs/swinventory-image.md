# swinventory-image

In addition to [swinventory](#swinventory) you can create a image based swinventory.
This module requires [swinventory](#swinventory) module to be enabled globally.

## Usage

Add

```bitbake
INHERIT += "swinventory"
```

to your local.conf and

```bitbake
inherit swinventory-image
```

in every image you like.
It will create a file calles `${PN}-swinventory.json` at `tmp/deploy/images/<arch>/`
