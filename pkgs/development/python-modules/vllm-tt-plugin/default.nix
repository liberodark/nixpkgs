{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  gnugrep,
  python,
  pythonAtLeast,
  runCommand,
  setuptools,
  tblib,
  pytestCheckHook,
  vllm,
}:

let
  supportedVllmVersions = [ "0.32.0" ];
in

buildPythonPackage (finalAttrs: {
  pname = "vllm-tt-plugin";
  version = "0.1.0-unstable-2026-10-27";
  pyproject = true;
  __structuredAttrs = true;

  disabled = pythonAtLeast "3.14";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "vllm-tt-plugin";
    rev = "82322afc95c44d72b72b45760564c4391f1f08aa";
    hash = "sha256-ZHHUfkfLXiPIg2W57m0K7psi0f5PUBNNAP69x8l6YDo=";
  };

  # vLLM 0.31 (tenstorrent/vllm-tt-plugin#254) and 0.32
  patches = [ ./vllm-0.32.patch ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "setuptools>=77.0.3,<81.0.0" "setuptools"
  '';

  build-system = [ setuptools ];

  dependencies = [ tblib ];

  pythonImportsCheck = [ "vllm_tt_plugin" ];

  nativeCheckInputs = [
    pytestCheckHook
    vllm
  ];

  preCheck = ''
    export PYTHONPATH=$PWD/tests/host-stubs:$PYTHONPATH
  '';

  # Disable Hardware Tests
  disabledTestPaths = [ "tests/tt" ];

  passthru = {
    tests = {
      vllm-tt-plugin-can-be-loaded-by-vllm =
        runCommand "vllm-tt-plugin-can-be-loaded-by-vllm"
          {
            nativeBuildInputs = [
              gnugrep
              (python.withPackages (ps: [
                ps.vllm
                finalAttrs.finalPackage
              ]))
            ];
          }
          # Note that grepping vllm's output directly
          # would kill it prematurely when a match occurs,
          # hence redirect to a file, then grep.
          ''
            (
              set -x
              vllm --version >/tmp/vllm.log
              grep -qF -- '- tt -> vllm_tt_plugin.entrypoints:platform_plugin' /tmp/vllm.log
              touch $out
            )
          '';
    };
  };

  meta = {
    description = "Tenstorrent backend plugin for vLLM";
    homepage = "https://github.com/tenstorrent/vllm-tt-plugin";
    license = lib.licenses.asl20;
    teams = [ lib.teams.tenstorrent ];
    maintainers = with lib.maintainers; [ liberodark ];
    platforms = lib.platforms.linux;
    problems = lib.optionalAttrs (!lib.elem vllm.version supportedVllmVersions) {
      broken = {
        message = ''
          This version of vllm (${vllm.version}) is incompatible with vllm-tt-plugin.
          Supported versions: ${lib.concatStringsSep " " supportedVllmVersions}
        '';
      };
    };
  };
})
