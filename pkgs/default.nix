{ pkgs ? import ./nixpkgs
, system ? builtins.currentSystem
, fetchFromGitHub ? (pkgs {}).fetchFromGitHub
, fetchurl ? (pkgs {}).fetchurl
, rustOverlay ? fetchFromGitHub {
    owner  = "mozilla";
    repo   = "nixpkgs-mozilla";
    rev    = "7e54fb37cd177e6d83e4e2b7d3e3b03bd6de0e0f";
    sha256 = "1shz56l19kgk05p2xvhb7jg1whhfjix6njx1q4rvrc5p1lvyvizd";
  }
, racket2nix ? import ./racket2nix { inherit system; }
}:

pkgs {
  inherit system;
  overlays = [
    (import (builtins.toPath "${rustOverlay}/rust-overlay.nix"))
    (self: super: rec {
      rust = let
        fromManifestFixed = manifest: sha256: { stdenv, fetchurl, patchelf }:
          self.lib.rustLib.fromManifestFile
            (fetchurl { url = manifest; sha256 = sha256; })
            { inherit stdenv fetchurl patchelf; };
        rustChannelOfFixed = manifest_args: sha256: fromManifestFixed
          (self.lib.rustLib.manifest_v2_url manifest_args) sha256
          { inherit (self) stdenv fetchurl patchelf; };
        channel = rustChannelOfFixed
          { date = "2018-05-30"; channel = "nightly"; }
          "06w12izi2hfz82x3wy0br347hsjk43w9z9s5y6h4illwxgy8v0x8";
      in {
        rustc = channel.rust;
        inherit (channel) cargo;
      };
      inherit racket2nix;
      inherit (racket2nix) buildRacketPackage;
      rustPlatform = super.recurseIntoAttrs (super.makeRustPlatform rust);
      fractalide = (self.buildRacketPackage (builtins.path {
        name = "fractalide";
        path = ./..;
        filter = (path: type:
          let basePath = baseNameOf path; in
          (type != "symlink" || null == builtins.match "result.*" basePath) &&
          (null == builtins.match ".*[.]nix" basePath) &&
          (null == builtins.match "[.].*[.]swp" basePath) &&
          (null == builtins.match "[.][#].*" basePath) &&
          (null == builtins.match "[#].*[#]" basePath) &&
          (null == builtins.match ".*~" basePath)
        );
      })).overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs or [] ++ [ self.makeWrapper ];
        inherit (self) graphviz;
        postInstall = oldAttrs.postInstall or "" + ''
          wrapProgram $env/bin/hyperflow --prefix PATH ":" $graphviz/bin
        '';
      });

      # fractalide/racket2nix#78 workaround

      # This simple addition works because fractalide happens to depend on all of
      # compiler-lib's dependencies (because it happens to depend on compiler-lib).
      fractalide-rkt-tests = (fractalide.overrideRacketDerivation (oldAttrs: {
        extraSrcs = [(fetchurl {
          url = "https://download.racket-lang.org/releases/6.12/pkgs/compiler-lib.zip";
          sha1 = "8921c26c498e920aca398df7afb0ab486636430f";
        })];
        # Remove compiler-lib from its own dependencies.
        racketBuildInputs = builtins.filter (input: input.pname or "" != "compiler-lib") oldAttrs.racketBuildInputs;
      })).overrideAttrs (oldAttrs: { name = "fractalide-rkt-tests"; });

      rkt-tests = let

        # parallel cannot quite handle full inline bash, and destroys quoting, so we can't use bash -c
        racoTest = builtins.toFile "raco-test.sh" ''
          timeout 20 time -f '%e s' racket -l- raco test "$@" |&
            grep -v -e "warning: tool .* registered twice" -e "@[(]test-responsible"
          exit ''${PIPESTATUS[0]}
        '';
      in self.runCommand "rkt-tests" {
        buildInputs = [ fractalide-rkt-tests.env self.coreutils self.parallel self.time ];
        inherit racoTest;
      } ''
        # If we do raco test <directory> the discovery process will try to mkdir $HOME.
        # If we allow raco test to run on anything in agents/gui it will fail because
        # requiring (gui/...) fails on headless.

        find ${fractalide-rkt-tests.env}/share/racket/pkgs/*/modules/rkt/rkt-fbp/agents \
          '(' -name gui -prune ')' -o '(' -name '*.rkt' -print ')' |
          parallel -n 1 -j ''${NIX_BUILD_CORES:-1} bash $racoTest |
          tee $out
        exit ''${PIPESTATUS[1]}
      '';
    })
  ];
}
