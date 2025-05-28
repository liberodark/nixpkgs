{
  lib,
  stdenv,
  python3,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
  wrapGAppsHook,
  gobject-introspection,
  gtk3,
  libappindicator,
  libdrm,
  pkg-config,
}:

let
  tkinter-tooltip = python3Packages.buildPythonPackage rec {
    pname = "tkinter-tooltip";
    version = "3.1.2";
    format = "wheel";

    src = fetchPypi {
      pname = "tkinter_tooltip";
      inherit version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-W6108tR22eJBhZiyQ48G5LZY3WqJ7jmgu/67T7f9638=";
    };

    propagatedBuildInputs = [ ];
    doCheck = false;
  };

  gputil = python3Packages.buildPythonPackage rec {
    pname = "GPUtil";
    version = "1.4.0";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-CZ5Sxl5RLN+oyHY/ymf1pcKvtjRpYC1dy00pazZh77k=";
    };

    propagatedBuildInputs = with python3Packages; [ setuptools ];
    doCheck = false;
  };

  pyamdgpuinfo = python3Packages.buildPythonPackage rec {
    pname = "pyamdgpuinfo";
    version = "2.1.7";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-lbT1YYwycfle3vjhDdr4mhOg0e27A73QXY9KkwqhJbA=";
    };

    buildInputs = [ libdrm ];

    nativeBuildInputs = with python3Packages; [
      cython
      setuptools
      numpy
    ] ++ [ pkg-config ];

    propagatedBuildInputs = with python3Packages; [ numpy ];

    preBuild = ''
      export C_INCLUDE_PATH="${libdrm.dev}/include:${libdrm.dev}/include/libdrm:$C_INCLUDE_PATH"
      export CPLUS_INCLUDE_PATH="${libdrm.dev}/include:${libdrm.dev}/include/libdrm:$CPLUS_INCLUDE_PATH"
    '';

    doCheck = false;
  };

  pythonEnv = python3.withPackages (
    ps: with ps; [
      pyserial
      pyyaml
      psutil
      pystray
      babel
      ruamel-yaml
      uptime
      requests
      pillow
      numpy
      tkinter
      sv-ttk
      ping3
      tkinter-tooltip
      gputil
      pyamdgpuinfo
      distutils
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "turing-smart-screen";
  version = "3.9.3";

  src = fetchFromGitHub {
    owner = "mathoudebine";
    repo = "turing-smart-screen-python";
    tag = "${finalAttrs.version}";
    hash = "sha256-VbuJ6f3RUXVFjTZXcv/U8VdYLA2uppZP1yOl8jKWmaA=";
  };

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook
    gobject-introspection
  ];

  buildInputs = [
    gtk3
    libappindicator
    pythonEnv
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/turing-smart-screen,share/applications,share/pixmaps}

    cp -r . $out/share/turing-smart-screen/

    makeWrapper ${pythonEnv}/bin/python $out/bin/turing-smart-screen \
      --prefix PYTHONPATH : "$out/share/turing-smart-screen" \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
      --set TURING_SMART_SCREEN_ROOT "$out/share/turing-smart-screen" \
      --add-flags "$out/share/turing-smart-screen/main_wrapper.py"

    makeWrapper ${pythonEnv}/bin/python $out/bin/turing-smart-screen-configure \
      --prefix PYTHONPATH : "$out/share/turing-smart-screen" \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
      --set TURING_SMART_SCREEN_ROOT "$out/share/turing-smart-screen" \
      --add-flags "$out/share/turing-smart-screen/configure_wrapper.py"

    makeWrapper ${pythonEnv}/bin/python $out/bin/turing-smart-screen-theme-editor \
      --prefix PYTHONPATH : "$out/share/turing-smart-screen" \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH" \
      --set TURING_SMART_SCREEN_ROOT "$out/share/turing-smart-screen" \
      --add-flags "$out/share/turing-smart-screen/theme_editor_wrapper.py"

    makeWrapper ${pythonEnv}/bin/python $out/bin/turing-smart-screen-simple \
      --prefix PYTHONPATH : "$out/share/turing-smart-screen" \
      --set TURING_SMART_SCREEN_ROOT "$out/share/turing-smart-screen" \
      --add-flags "$out/share/turing-smart-screen/simple-program.py"

    cat > $out/share/turing-smart-screen/main_wrapper.py <<EOF
    #!/usr/bin/env python3
    import os
    import sys

    config_dir = os.path.expanduser("~/.config/turing-smart-screen")
    if not os.path.exists(config_dir):
        print("Initializing Turing Smart Screen configuration...")
        os.makedirs(config_dir, exist_ok=True)
        import shutil
        shutil.copy("$out/share/turing-smart-screen/config.yaml", config_dir)

    os.chdir(config_dir)
    sys.path.insert(0, "$out/share/turing-smart-screen")
    import nix_paths
    exec(open("$out/share/turing-smart-screen/main.py").read())
    EOF

    cat > $out/share/turing-smart-screen/configure_wrapper.py <<EOF
    #!/usr/bin/env python3
    import os
    import sys

    config_dir = os.path.expanduser("~/.config/turing-smart-screen")
    os.makedirs(config_dir, exist_ok=True)
    os.chdir(config_dir)
    sys.path.insert(0, "$out/share/turing-smart-screen")
    import nix_paths
    exec(open("$out/share/turing-smart-screen/configure.py").read())
    EOF

    cat > $out/share/turing-smart-screen/theme_editor_wrapper.py <<EOF
    #!/usr/bin/env python3
    import os
    import sys

    config_dir = os.path.expanduser("~/.config/turing-smart-screen")
    os.makedirs(config_dir, exist_ok=True)
    os.chdir(config_dir)
    sys.path.insert(0, "$out/share/turing-smart-screen")
    import nix_paths

    sys.argv = ["theme-editor.py"] + sys.argv[1:]
    exec(open("$out/share/turing-smart-screen/theme-editor.py").read())
    EOF

    cat > $out/share/turing-smart-screen/nix_paths.py <<EOF
    import os
    import sys

    MAIN_DIRECTORY = os.environ.get('TURING_SMART_SCREEN_ROOT', '$out/share/turing-smart-screen') + '/'

    from pathlib import Path
    _original_resolve = Path.resolve

    def patched_resolve(self):
        result = _original_resolve(self)
        if str(result).endswith(('.py', '__main__.py')):
            parent = str(result.parent)
            if 'turing-smart-screen' in parent:
                return Path(MAIN_DIRECTORY[:-1])
        return result

    Path.resolve = patched_resolve
    EOF

    for script in main.py configure.py theme-editor.py simple-program.py; do
      if [ -f "$out/share/turing-smart-screen/$script" ]; then
        if head -n1 "$out/share/turing-smart-screen/$script" | grep -q '^#!'; then
          sed -i '2i\import sys; sys.path.insert(0, "'"$out/share/turing-smart-screen"'"); import nix_paths' \
            "$out/share/turing-smart-screen/$script"
        else
          sed -i '1i\import sys; sys.path.insert(0, "'"$out/share/turing-smart-screen"'"); import nix_paths' \
            "$out/share/turing-smart-screen/$script"
        fi
      fi
    done

    find $out/share/turing-smart-screen -name "*.py" -exec sed -i \
      's|MAIN_DIRECTORY = str(Path(__file__).parent.resolve()) + "/"|from nix_paths import MAIN_DIRECTORY|g' \
      {} +

    cat > $out/share/applications/turing-smart-screen.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Turing Smart Screen
    Comment=System monitor for USB-C smart displays
    Exec=$out/bin/turing-smart-screen
    Icon=turing-smart-screen
    Categories=System;Monitor;
    Terminal=false
    EOF

    cat > $out/share/applications/turing-smart-screen-configure.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Turing Smart Screen Configuration
    Comment=Configure Turing Smart Screen Monitor
    Exec=$out/bin/turing-smart-screen-configure
    Icon=turing-smart-screen
    Categories=System;Settings;
    Terminal=false
    EOF

    cp $out/share/turing-smart-screen/res/icons/monitor-icon-17865/64.png \
       $out/share/pixmaps/turing-smart-screen.png

    runHook postInstall
  '';

  postInstall = lib.optionalString stdenv.isLinux ''
    mkdir -p $out/lib/udev/rules.d
    cat > $out/lib/udev/rules.d/70-turing-smart-screen.rules <<EOF
    # Turing Smart Screen USB devices
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6015", MODE="0666", GROUP="dialout"
    EOF
  '';

  meta = {
    description = "Python system monitor and library for USB-C displays like Turing Smart Screen";
    homepage = "https://github.com/mathoudebine/turing-smart-screen-python";
    changelog = "https://github.com/mathoudebine/turing-smart-screen-python/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ liberodark ];
    platforms = lib.platforms.unix;
    mainProgram = "turing-smart-screen";
  };
})
