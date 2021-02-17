# sms-z80

A playground for Sega Master System development using Z80 assembly.

## Usage

### Prerequirements

* [WLA-DX](https://github.com/vhelin/wla-dx) assembler

### Build

To build the ROM using `make`:

```sh
make
```

To build the ROM using [alexw88/sms-toolchain](https://github.com/aw88/sms-toolchain):

```sh
docker run --rm -v $(pwd):/app alexw88/sms-toolchain make
```

Acknowledgements:

* [Emulicious](https://emulicious.net/) Master System emulator
* [devkitSMS](https://github.com/sverx/devkitSMS)
* [Zoria Tileset](https://opengameart.org/content/zoria-tileset) by [DragonDePlatino](https://opengameart.org/users/dragondeplatino)
