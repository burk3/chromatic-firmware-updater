self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.chromatic-firmware-updater;
in
{
  options.programs.chromatic-firmware-updater = {
    enable = lib.mkEnableOption "the ModRetro Chromatic firmware updater and its udev rules";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "chromatic-firmware-updater.packages.\${system}.default";
      description = "The chromatic-firmware-updater package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];
  };
}
