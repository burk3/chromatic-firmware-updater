# chromatic-firmware-updater

Nix flake packaging ModRetro's ChromaticFirmwareUpdater (the official
AppImage, unmodified) for NixOS / Nix on x86_64 Linux.

## NixOS (recommended)

The updater talks to the Chromatic over USB, so it needs udev rules. The
module installs both the app and the rules:

```nix
{
  inputs.chromatic-firmware-updater.url = "github:burk3/chromatic-firmware-updater";

  outputs = { nixpkgs, chromatic-firmware-updater, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        chromatic-firmware-updater.nixosModules.default
        { programs.chromatic-firmware-updater.enable = true; }
      ];
    };
  };
}
```

After `nixos-rebuild switch`, replug the Chromatic and launch
"Chromatic Firmware Updater" from your app menu.

The rules use `TAG+="uaccess"`, which grants access to the user logged in at
the local seat, rather than upstream's world-writable `MODE="0666"`.

## Just run it

```sh
nix run github:burk3/chromatic-firmware-updater
```

Without the udev rules the app starts but likely can't open the device. On a
non-NixOS distro, install the rules by hand:

```sh
sudo cp $(nix build --no-link --print-out-paths github:burk3/chromatic-firmware-updater)/lib/udev/rules.d/*.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

## Updating

ModRetro publishes the AppImage at an unversioned URL, so when they ship a
new release the fixed hash in `package.nix` stops matching. Bump `version`
and `hash` there (set `hash = lib.fakeHash;`, build, copy the `got:` hash).
