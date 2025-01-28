{ lib, stdenv, fetchFromGitHub, erlang, cl, libGL, libGLU, runtimeShell, git, eigen, libigl }:

stdenv.mkDerivation rec {
  pname = "wings";
  version = "2.4.1";

  src = fetchFromGitHub {
    owner = "dgud";
    repo = "wings";
    tag = "v${version}";
    hash = "sha256-3ulWbAOtYujaymN50u7buvnBdtYMEAe8Ji3arvPUH/s=";
  };

  nativeBuildInputs = [ git ];
  buildInputs = [ erlang cl libGL libGLU eigen libigl ];

  preBuildPhases = [ "setupDepsPhase" ];
  setupDepsPhase = ''
    mkdir -p _deps/eigen _deps/libigl
    ln -s ${eigen}/include/eigen3/* _deps/eigen/
    ln -s ${libigl}/include/* _deps/libigl/
  '';

  postPatch = ''
    find . -type f -name "Makefile" -exec sed -i 's,-Werror ,,' {} \;
    sed -i 's,../../wings/,../,' icons/Makefile
    find plugins_src -mindepth 2 -type f -name "*.[eh]rl" -exec sed -i 's,wings/src/,../../src/,' {} \;
    find plugins_src -mindepth 2 -type f -name "*.[eh]rl" -exec sed -i 's,wings/e3d/,../../e3d/,' {} \;
    find plugins_src -mindepth 2 -type f -name "*.[eh]rl" -exec sed -i 's,wings/intl_tools/,../../intl_tools/,' {} \;
    find . -type f -name "*.[eh]rl" -exec sed -i 's,wings/src/,../src/,' {} \;
    find . -type f -name "*.[eh]rl" -exec sed -i 's,wings/e3d/,../e3d/,' {} \;
    find . -type f -name "*.[eh]rl" -exec sed -i 's,wings/intl_tools/,../intl_tools/,' {} \;
  '';

  ERL_LIBS = "${cl}/lib/erlang/lib";

  # I did not test the *cl* part. I added the -pa just by imitation.
  installPhase = ''
    mkdir -p $out/bin $out/lib/wings-${version}/ebin
    cp ebin/* $out/lib/wings-${version}/ebin
    cp -R textures shaders plugins $out/lib/wings-${version}
    cat << EOF > $out/bin/wings
    #!${runtimeShell}
    ${erlang}/bin/erl \
    -pa $out/lib/wings-${version}/ebin -run wings_start start_halt "$@"
    EOF
    chmod +x $out/bin/wings
  '';

  meta = {
    homepage = "https://www.wings3d.com/";
    description = "Subdivision modeler inspired by Nendo and Mirai from Izware";
    license = lib.licenses.tcltk;
    maintainers = with lib.maintainers; [ liberodark ];
    platforms = lib.platforms.linux;
    mainProgram = "wings";
  };
}
