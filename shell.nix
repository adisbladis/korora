let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = [
    pkgs.nix-unit
    pkgs.nixdoc
    pkgs.mdbook
  ];
}
