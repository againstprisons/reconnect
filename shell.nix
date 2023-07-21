{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

with lib;

let
  neededLibraries = with pkgs; [
    curl
    libsodium
    libxml2
    libxslt
    postgresql
  ];

in
pkgs.mkShell {
  buildInputs = with pkgs; [
    ruby_2_7

    nodejs
    nodePackages.npm

    pkg-config
    shared-mime-info
    cacert

    imagemagick
    pngcrush
  ] ++ neededLibraries;

  "DYLD_LIBRARY_PATH" = makeLibraryPath neededLibraries;
  "LD_LIBRARY_PATH" = makeLibraryPath neededLibraries;
  "SSL_CERT_DIR" = "${pkgs.cacert}/etc/ssl/certs";
  "SSL_CERT_FILE" = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  "FREEDESKTOP_MIME_TYPES_PATH" = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";
}
