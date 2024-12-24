{
  lib,
  stdenv,
  fetchFromGitHub,
  makeDesktopItem,
  pkg-config,
  gtk3,
  webkitgtk_4_1,
  rclone,
  rsync,
  nodejs_20,
  rustPlatform,
  openssl,
  glib,
  cairo,
  pango,
  atk,
  gdk-pixbuf,
  libsoup_2_4,
  copyDesktopItems,
  wrapGAppsHook,
  gnumake,
}:

rustPlatform.buildRustPackage rec {
  pname = "bewcloud-desktop";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "bewcloud";
    repo = "bewcloud-desktop";
    rev = "v${version}";
    sha256 = "sha256-fxKtTsVbxfn8uexosuoO5DHcC+M8KdsL+UdZ3JDo79o=";
  };

  cargoHash = lib.fakeHash;

  buildAndTestSubdir = "src-tauri";

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    nodejs_20
    wrapGAppsHook
    copyDesktopItems
    gnumake
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    openssl
    glib
    cairo
    pango
    atk
    gdk-pixbuf
    libsoup_2_4
  ];

  runtimeDependencies = [
    rclone
    rsync
  ];

  preBuild = ''
    export HOME=$(mktemp -d)
    export npm_config_cache=$(mktemp -d)
    cd src-tauri
    cargo generate-lockfile
    cd ..
    make install
    make build
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "bewcloud-desktop";
      exec = "bewcloud-desktop";
      icon = "com.bewcloud.sync";
      desktopName = "bewCloud Desktop Sync";
      genericName = "Cloud Sync Client";
      categories = [
        "Network"
        "FileTransfer"
        "Utility"
      ];
    })
  ];

  postInstall = ''
    install -Dm644 icons/32x32.png $out/share/icons/hicolor/32x32/apps/com.bewcloud.sync.png
    install -Dm644 icons/128x128.png $out/share/icons/hicolor/128x128/apps/com.bewcloud.sync.png
    install -Dm644 icons/128x128@2x.png $out/share/icons/hicolor/256x256/apps/com.bewcloud.sync.png
    install -Dm644 icons/icon.ico $out/share/icons/hicolor/48x48/apps/com.bewcloud.sync.png
  '';

  meta = {
    description = "Desktop Sync client for bewCloud, built with Tauri";
    homepage = "https://github.com/bewcloud/bewcloud-desktop";
    license = lib.licenses.agpl3Plus;
    maintainers = [ lib.maintainers.liberodark ];
    platforms = lib.platforms.linux;
    mainProgram = "bewcloud-desktop";
  };
}
