{ pkgs ? import <nixpkgs> { } }:

with pkgs.ocamlPackages;

buildDunePackage {
  pname = "slack_bot";
  version = "dev";
  # Ignore some files, otherwise it'll need to be rebuilt everytime.
  src = builtins.filterSource
    (p: t: !(builtins.elem (baseNameOf p) [ ".git" "result" ])) ./.;
  useDune2 = true;
  buildInputs = [
    cohttp-lwt-unix
    irmin-unix
    lwt
    mirage-clock-unix
    mirage-time-unix
    ptime
    ppx_deriving_yojson
    yojson
  ];
  propagatedBuildInputs = [ pkgs.git ];
}
