with (import <nixpkgs> {});
let
  ruby = pkgs.ruby;
  env = bundlerEnv {
    name = "bundler-env-hstasonis";
    inherit ruby;
    gemdir = ./.;
  };
in stdenv.mkDerivation {
  name = "blade3";
  buildInputs = [ env ruby libsodium ];
}
