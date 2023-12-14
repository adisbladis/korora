{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  packages = [
    pkgs.nix-unit
    pkgs.nixdoc
  ];
}
