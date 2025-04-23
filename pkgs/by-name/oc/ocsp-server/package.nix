{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  perl,
  libmysqlclient,
  mariadb,
  mbedtls,
  postgresql,
  sqlite,
  versionCheckHook,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ocsp-server";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "DorianCoding";
    repo = "OCSP-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kFism1EndRUX6FEh+qPD1QRNwy+zYOtXMpuLVJ9rlN4=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-YSiqpU9iewpioaB7J8BeIAFp0ebYD4NZVNWcuGIZudI=";

  nativeBuildInputs = [
    libmysqlclient
    pkg-config
    perl
    sqlite
  ];

  buildInputs = [
    openssl
    mariadb
    mbedtls
    postgresql
    sqlite
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "OCSP responder fetching certificate status from MySQL/MariaDB/PSQL database";
    homepage = "https://github.com/DorianCoding/OCSP-server";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ liberodark ];
    mainProgram = "ocsp-server";
  };
})
