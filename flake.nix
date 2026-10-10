{
  description = "ModRetro Chromatic firmware updater, packaged for Nix/NixOS";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

  outputs =
    { self, ... }@inputs:
    let
      inherit (inputs.nixpkgs) lib;

      # Upstream only ships an x86_64 Linux AppImage.
      supportedSystems = [ "x86_64-linux" ];

      forEachSupportedSystem =
        f:
        lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
        );
    in
    {
      packages = forEachSupportedSystem (
        { pkgs, ... }:
        rec {
          chromatic-firmware-updater = pkgs.callPackage ./package.nix { };
          default = chromatic-firmware-updater;
        }
      );

      apps = forEachSupportedSystem (
        { system, ... }:
        {
          default = {
            type = "app";
            program = lib.getExe self.packages.${system}.default;
          };
        }
      );

      nixosModules.default = import ./module.nix self;

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShellNoCC {
            packages = [ self.formatter.${system} ];
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}
