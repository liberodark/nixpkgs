{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  xz,
  zlib,
  libarchive,
  openssl_3,
  sqlite,
  audit,
  systemd,
  curl,
  pcre2,
  cjson,
  bzip2,
  jemalloc,
  lua5_3,
  db,
  libffi,
  libyaml,
  popt,
  procps,
  rocksdb,
  python312,
}:

stdenv.mkDerivation rec {
  pname = "wazuh-manager";
  version = "4.10.1";

  src = fetchurl {
    url = "https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-manager/wazuh-manager_${version}-1_amd64.deb";
    hash = "sha256-RRzKH3eYrEAfo5fhIedybfYThJ4/c+jk+eSjn58Bygs=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    xz
    zlib
    libarchive
    openssl_3
    sqlite
    audit
    systemd
    curl
    pcre2
    cjson
    bzip2
    jemalloc
    lua5_3
    db
    libffi
    libyaml
    popt
    procps
    rocksdb

    # Python
    python312
    python312.pkgs.aiohttp
    python312.pkgs.cachetools
    python312.pkgs.chardet
    python312.pkgs.cryptography
    python312.pkgs.defusedxml
    python312.pkgs.fastapi
    python312.pkgs.future
    python312.pkgs.gunicorn
    python312.pkgs.httpx
    python312.pkgs.jsonschema
    python312.pkgs.more-itertools
    python312.pkgs.psutil
    python312.pkgs.pyjwt
    python312.pkgs.python-dateutil
    python312.pkgs.pytz
    python312.pkgs.rsa
    python312.pkgs.sqlalchemy
    python312.pkgs.uvicorn
    python312.pkgs.xmltodict
  ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r {etc,usr,var} $out/
    chmod -R u+w $out
    find $out -type f -exec \
      sed -i "s,/var/ossec,$out/var/ossec,g" {} +
    find $out -type f -name "*.py" -exec \
      sed -i "s,/var/ossec,$out/var/ossec,g" {} +
    runHook postInstall
  '';

  meta = {
    description = "Wazuh server - Security and compliance solution";
    homepage = "https://wazuh.com";
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ liberodark ];
    mainProgram = "wazuh-manager";
  };
}