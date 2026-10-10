{
  lib,
  appimageTools,
  fetchzip,
  runCommand,
  writeShellScript,
  makeBinaryWrapper,
  bashInteractive,
  xdg-utils,
}:

let
  pname = "chromatic-firmware-updater";
  version = "1.7.5";

  src =
    (fetchzip {
      url = "https://s3.us-east-1.amazonaws.com/updates.modretro.com/apps/ChromaticFirmwareUpdater-linux-x86_64.zip";
      hash = "sha256-GyZ270V1xXG5DQh3e5pCyKORfqudFVw2Et4Bu1h40+M=";
    })
    + "/ChromaticFirmwareUpdater-x86_64.AppImage";

  contents = appimageTools.extractType2 { inherit pname version src; };

  # PyInstaller leaks its bundled libs (incl. a bash-breaking libreadline) to
  # child processes via LD_LIBRARY_PATH; these libc-only wrappers clear it.
  cleanEnvWrappers =
    runCommand "chromatic-clean-env-wrappers" { nativeBuildInputs = [ makeBinaryWrapper ]; }
      ''
        makeWrapper ${lib.getExe bashInteractive} $out/bin/bash --unset LD_LIBRARY_PATH
        makeWrapper ${bashInteractive}/bin/sh $out/bin/sh --unset LD_LIBRARY_PATH
        makeWrapper ${xdg-utils}/bin/xdg-open $out/bin/xdg-open --unset LD_LIBRARY_PATH
      '';
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [ pkgs.libusb1 ];

  # Replaces appimageTools' default runScript, whose appimage-exec.sh puts its
  # own bash/coreutils at the front of PATH, ahead of anything set here.
  # (/usr/bin/sh etc. are also overridden below for absolute-path callers.)
  runScript = writeShellScript "${pname}-run" ''
    export APPDIR=${contents}
    export PATH=${cleanEnvWrappers}/bin:$PATH
    exec ${contents}/AppRun "$@"
  '';

  extraBuildCommands = ''
    for bin in bash sh xdg-open; do
      ln -sf ${cleanEnvWrappers}/bin/$bin $out/usr/bin/$bin
    done
  '';

  extraBwrapArgs = [
    # The app checks for its rules file in /etc/udev/rules.d at startup, but
    # the FHS sandbox only passes through a fixed set of host /etc entries.
    "--ro-bind-try /etc/udev /etc/udev"
    # Device detection shells out to a bundled openFPGALoader AppImage, which
    # can't FUSE-mount itself inside the sandbox (no setuid fusermount).
    "--setenv APPIMAGE_EXTRACT_AND_RUN 1"
  ];

  extraInstallCommands = ''
    install -Dm444 ${./70-modretro-chromatic.rules} \
      $out/lib/udev/rules.d/70-modretro-chromatic.rules
    install -Dm444 ${./99-modretro.rules} \
      $out/lib/udev/rules.d/99-modretro.rules
    install -Dm444 ${contents}/ChromaticFirmwareUpdater.desktop \
      $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=ChromaticFirmwareUpdater' 'Exec=${pname}' \
      --replace-fail 'Icon=icon_256x256' 'Icon=${pname}' \
      --replace-fail 'Name=ChromaticFirmwareUpdater' 'Name=Chromatic Firmware Updater'
    install -Dm444 ${contents}/usr/share/icons/hicolor/scalable/apps/icon_256x256.png \
      $out/share/icons/hicolor/256x256/apps/${pname}.png
  '';

  meta = {
    description = "Firmware updater for the ModRetro Chromatic handheld";
    homepage = "https://modretro.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
