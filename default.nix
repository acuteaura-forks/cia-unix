{
  lib,
  crystal,
  fetchurl,
  makeWrapper,
  unzip,
  stdenv,
  autoPatchelfHook,
  openssl,
  pcre2,
  boehmgc,
}:

let
  # Linux x86_64 binaries
  ctrdecrypt = fetchurl {
    url = "https://github.com/shijimasoft/ctrdecrypt/releases/download/v1.1.0/ctrdecrypt-linux-x86_64.zip";
    sha256 = "sha256-i2mOb0DfoF2outXqmGs5Uvq3lv/I2oeAoFUhWfto5iM=";
  };

  ctrtool = fetchurl {
    url = "https://github.com/3DSGuy/Project_CTR/releases/download/ctrtool-v1.2.0/ctrtool-v1.2.0-ubuntu_x86_64.zip";
    sha256 = "sha256-1T9ZuvW61TOUNK8r/FvSqVR5eNaTPoDqxZAvWhG3OLE=";
  };

  makerom = fetchurl {
    url = "https://github.com/3DSGuy/Project_CTR/releases/download/makerom-v0.18.4/makerom-v0.18.4-ubuntu_x86_64.zip";
    sha256 = "sha256-3VloVHGMGVxuMikoa+SFsSKSFxVVWviuXPjppGXZ+XA=";
  };

  seeddb = fetchurl {
    url = "https://github.com/ihaveamac/3DS-rom-tools/raw/master/seeddb/seeddb.bin";
    sha256 = "sha256-zNzqXkRlGUFYc3RiQ27BCuSGad2WGQIoKsKGHiYNA8k=";
  };

in
stdenv.mkDerivation rec {
  pname = "cia-unix";
  version = "unstable-2024-11-19";

  src = ./.;

  nativeBuildInputs = [
    crystal
    makeWrapper
    unzip
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    openssl
    pcre2
    boehmgc
  ];

  postPatch = ''
    # Patch the Crystal source to use absolute paths from environment variables
    sed -i 's|File.new "cia-unix.log", "w"|File.new(ENV.fetch("HOME", ".") + "/cia-unix.log", "w")|g' cia-unix.cr
    sed -i 's|"./ctrtool"|ENV["CIA_UNIX_TOOLS"] + "/ctrtool"|g' cia-unix.cr
    sed -i 's|"./ctrdecrypt"|ENV["CIA_UNIX_TOOLS"] + "/ctrdecrypt"|g' cia-unix.cr
    sed -i 's|"./makerom"|ENV["CIA_UNIX_TOOLS"] + "/makerom"|g' cia-unix.cr
    sed -i 's|"seeddb.bin"|ENV["CIA_UNIX_TOOLS"] + "/seeddb.bin"|g' cia-unix.cr
    sed -i 's|%x\[which #{tool}\]|ENV["CIA_UNIX_TOOLS"] + tool|g' cia-unix.cr
    sed -i 's|process = Process.new("./#{name}"|process = Process.new(ENV["CIA_UNIX_TOOLS"] + "/#{name}"|g' cia-unix.cr

    # Remove the dependency check since tools are bundled with Nix
    sed -i '/# dependencies check/,/^end$/d' cia-unix.cr
    sed -i '/^def download_dep$/,/^end$/d' cia-unix.cr
  '';

  buildPhase = ''
    runHook preBuild

    # Build the Crystal application
    crystal build cia-unix.cr --release --no-debug -o cia-unix

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create directories
    mkdir -p $out/bin
    mkdir -p $out/libexec/cia-unix

    # Install the main binary
    install -Dm755 cia-unix $out/libexec/cia-unix/cia-unix

    # Extract and install dependencies
    unzip -q ${ctrdecrypt} -d ctrdecrypt-extracted
    unzip -q ${ctrtool} -d ctrtool-extracted
    unzip -q ${makerom} -d makerom-extracted

    # Find and install the binaries from extracted archives
    find ctrdecrypt-extracted -name 'ctrdecrypt' -type f -exec install -Dm755 {} $out/libexec/cia-unix/ctrdecrypt \;
    find ctrtool-extracted -name 'ctrtool' -type f -exec install -Dm755 {} $out/libexec/cia-unix/ctrtool \;
    find makerom-extracted -name 'makerom' -type f -exec install -Dm755 {} $out/libexec/cia-unix/makerom \;

    # Install seeddb
    install -Dm644 ${seeddb} $out/libexec/cia-unix/seeddb.bin

    # Create wrapper script that sets up the environment
    makeWrapper $out/libexec/cia-unix/cia-unix $out/bin/cia-unix \
      --prefix PATH : $out/libexec/cia-unix \
      --set CIA_UNIX_TOOLS $out/libexec/cia-unix

    runHook postInstall
  '';

  meta = with lib; {
    description = "Decrypt CIA and 3DS roms on Linux";
    homepage = "https://github.com/shijimasoft/cia-unix";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cia-unix";
  };
}
