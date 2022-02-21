{ pkgs ? import <nixpkgs> { } }:

with pkgs.ocamlPackages;

buildDunePackage {
  pname = "slack_bot";
  version = "dev";
  src = ./.;
  useDune2 = true;
  buildInputs = [ cohttp-lwt-unix irmin-unix lwt mirage-clock-unix mirage-time-unix ptime ppx_deriving_yojson yojson ];
  propagatedBuildInputs = [ pkgs.git ];
}
