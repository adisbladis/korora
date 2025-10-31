{
  pkgs ? import <nixpkgs> { },
}:

let
  inherit (pkgs) lib;
  mkReadme = pkgs.writeShellScriptBin "make-readme" ''
    ${lib.getExe' pkgs.nixdoc "nixdoc"} --category types --description "Kororā" --file types.nix | sed s/' {#.*'/""/ > README.md
  '';
in

pkgs.mkShell {
  packages = [
    pkgs.nix-unit
    pkgs.nixdoc
    mkReadme
  ];
}
