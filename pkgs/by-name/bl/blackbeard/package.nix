{
  lib,
  buildGoModule,
  fetchFromGitHub,
  curl-impersonate,
  pkg-config,
  curl,
  makeWrapper,
}:

buildGoModule rec {
  pname = "blackbeard";
  version = "unstable-2024.03.24";

  src = fetchFromGitHub {
    owner = "matheusfillipe";
    repo = "blackbeard";
    rev = "788be485df436bf009e716c9918c395bda8d86f4";
    hash = "sha256-2i7r3asDBEBSUVOR+n3C+DH2HLeE2sbVJp95jfE/UpQ=";
  };

  vendorHash = "sha256-4cUoI8OcBCUT3uqvmIduCj0My8LCVUoDvvAS21DR2Mo=";

  buildInputs = [
    curl-impersonate
    curl
  ];

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  doCheck = false;
  excludedPackages = [ "tests" ];

  env = {
    CGO_ENABLED = "1";
  };

  tags = [ "netgo" ];
  ldflags = [
    "-linkmode=external"
    "-extldflags=-Wl,-rpath,${
      lib.makeLibraryPath [
        curl-impersonate
        curl
      ]
    }"
  ];

  postInstall = ''
    wrapProgram $out/bin/blackbeard \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          curl-impersonate
          curl
        ]
      }" \
      --set LD_PRELOAD "${curl-impersonate}/lib/libcurl-impersonate-chrome.so"
  '';

  meta = with lib; {
    description = "CLI and API that scrapes content from video providers";
    longDescription = ''
      Blackbeard is a tool that provides both a CLI and API for scraping content
      from various video providers. It features an interactive fuzzy interface
      and supports parallel downloads.
    '';
    homepage = "https://github.com/matheusfillipe/blackbeard";
    license = licenses.mit;
    maintainers = [ liberodark ];
    mainProgram = "blackbeard";
    platforms = platforms.unix;
  };
}
