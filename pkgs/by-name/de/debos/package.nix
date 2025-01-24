{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  glib,
  ostree,
  qemu,
  versionCheckHook,
  nix-update-script,
}:

buildGoModule rec {
  pname = "debos";
  version = "1.1.4";

  src = fetchFromGitHub {
    owner = "liberodark";
    repo = "debos";
    rev = "946c161201332376d919c665ceba191a7ce7fc9f";
    hash = "sha256-GC1Z/9Hf0k8+mg2C5EhQ1indpny8AXFKyo3y3Azq42g=";
  };

  vendorHash = "sha256-UTXkkjgfi0oI+p1MS2vCnfEHWSW6maLA9xi7p2mroU8=";

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    glib
    ostree
    qemu
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Tool to create Debian OS images";
    homepage = "https://github.com/go-debos/debos";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ liberodark ];
    mainProgram = "debos";
  };
}
