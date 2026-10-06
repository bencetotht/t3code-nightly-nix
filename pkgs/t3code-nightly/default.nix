{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, dpkg,
  alsa-lib, at-spi2-atk, at-spi2-core, atk, cairo, cups, dbus, expat,
  glib, gtk3, libdrm, libgbm, libsecret, libx11, libxcb, libxcomposite,
  libxdamage, libxext, libxfixes, libxkbcommon, libxrandr, nspr, nss,
  pango, systemd, libGL, vulkan-loader,
}:
let
  pin = builtins.fromJSON (builtins.readFile ./sources.json);
  source = pin.sources.${stdenv.hostPlatform.system};
  cli = fetchurl source.cli;
in
stdenv.mkDerivation {
  pname = "t3code-nightly";
  inherit (pin) version;
  src = fetchurl source.desktop;

  nativeBuildInputs = [ autoPatchelfHook makeWrapper dpkg ];
  buildInputs = [
    stdenv.cc.cc.lib alsa-lib at-spi2-atk at-spi2-core atk cairo cups dbus
    expat glib gtk3 libdrm libgbm libsecret libx11 libxcb libxcomposite
    libxdamage libxext libxfixes libxkbcommon libxrandr nspr nss pango systemd
  ];
  # Electron loads these libraries dynamically rather than through DT_NEEDED.
  runtimeDependencies = [ (lib.getLib systemd) libGL vulkan-loader ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" desktop
    mkdir cli
    tar -xzf ${cli} -C cli --strip-components=1
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3code-desktop" "$out/lib/t3code-cli" "$out/bin" "$out/share"
    cp -a desktop/opt/*/. "$out/lib/t3code-desktop/"
    cp -a cli/. "$out/lib/t3code-cli/"
    cp -a desktop/usr/share/icons "$out/share/"
    mkdir -p "$out/share/applications"
    cp desktop/usr/share/applications/t3code.desktop "$out/share/applications/t3code-nightly.desktop"
    substituteInPlace "$out/share/applications/t3code-nightly.desktop" \
      --replace-fail 'Exec="/opt/T3 Code (Nightly)/t3code"' "Exec=$out/bin/t3code-desktop"

    # The release includes both libc variants; Node selects the GNU variant
    # on NixOS. Do not patch the unused musl binary against glibc.
    rm -rf "$out/lib/t3code-desktop/resources/app.asar.unpacked/node_modules/@yuuang/ffi-rs-linux-"*-musl

    makeWrapper "$out/lib/t3code-cli/t3" "$out/bin/t3" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib libsecret ]}"
    makeWrapper "$out/lib/t3code-desktop/t3code" "$out/bin/t3code-desktop" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib libsecret ]}"
    ln -s t3 "$out/bin/t3-nightly"
    ln -s t3code-desktop "$out/bin/t3code-nightly"
    runHook postInstall
  '';

  meta = {
    description = "T3 Code nightly desktop and standalone CLI";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
