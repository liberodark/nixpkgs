{
  lib,
  runCommand,
  ffmpeg,
  fetchzip,
  revision,
  system,
  throwSystem,
}:
let
  download =
    (import ./browser-downloads.nix {
      name = "ffmpeg";
      inherit revision;
    }).${system} or throwSystem;
in
if system == "riscv64-linux" then
  runCommand "playwright-ffmpeg" { } ''
    mkdir $out
    ln -s ${lib.getExe ffmpeg} $out/ffmpeg-linux
  ''
else
  fetchzip {
    inherit (download) url stripRoot;
    hash =
      {
        x86_64-linux = "sha256-AWTiui+ccKHxsIaQSgc5gWCJT5gYwIWzAEqSuKgVqZU=";
        aarch64-linux = "sha256-1mOKO2lcnlwLsC6ob//xKnKrCOp94pw8X14uBxCdj0Q=";
        aarch64-darwin = "sha256-ky10UQj+XPVGpaWAPvKd51C5brml0y9xQ6iKcrxAMRc=";
      }
      .${system} or throwSystem;
  }
