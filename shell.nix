{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    ruby
    bundler
  ];

  buildInputs = with pkgs; [
    libsodium
    libxml2
    libxslt
    postgresql
    sqlite
  ];
}
