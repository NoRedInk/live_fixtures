{ ... }:
let
  sources = import ./nix/sources.nix { };
  nixpkgs = import sources.nixpkgs { };
  gems = nixpkgs.bundlerEnv {
    name = "live_fixtures";
    gemfile = ./nix/Gemfile;
    lockfile = ./nix/Gemfile.lock;
    ruby = nixpkgs.ruby_3_1;
    gemdir = ./nix;
  };
in with nixpkgs;
stdenv.mkDerivation {
  name = "live_fixtures";
  buildInputs = [ gems gems.wrappedRuby ];
}
