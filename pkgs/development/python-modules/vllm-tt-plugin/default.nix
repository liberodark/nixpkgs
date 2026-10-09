{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonAtLeast,
  setuptools,
  tblib,
  pytestCheckHook,
  vllm,
}:

let
  vllmVersion = lib.versions.majorMinor vllm.version;
in

buildPythonPackage {
  pname = "vllm-tt-plugin";
  version = "0.1.0-unstable-2026-10-09";
  pyproject = true;
  __structuredAttrs = true;

  disabled = pythonAtLeast "3.14";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "vllm-tt-plugin";
    rev = "c62035d8f16eb591b258a7d5f2b329495829a74c";
    hash = "sha256-Vq1RLb2+4XzxP9BGYrUaLlCo2JXH/RFL2DtNO1ndp18=";
  };

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
    export PYTHONPATH=$PWD/ci/host-stubs:$PYTHONPATH
  '';

  disabledTestPaths = [ "tests/tt" ];

  meta = {
    description = "Tenstorrent backend plugin for vLLM";
    homepage = "https://github.com/tenstorrent/vllm-tt-plugin";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ liberodark ];
    platforms = lib.platforms.linux;
    broken =
      !(lib.elem vllmVersion [
        "0.29"
      ]);
  };
}
