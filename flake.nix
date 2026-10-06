{
  description = "Nix flake for the official T3 Code nightly builds (desktop + CLI)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: _prev: {
        t3code-nightly = final.callPackage ./pkgs/t3code-nightly { };
      };

      packages = forAllSystems (pkgs: rec {
        t3code-nightly = pkgs.callPackage ./pkgs/t3code-nightly { };
        default = t3code-nightly;
        update = pkgs.writeShellApplication {
          name = "update-t3code-nightly";
          runtimeInputs = [ pkgs.python3 ];
          text = ''
            exec python3 ${./pkgs/t3code-nightly/update.py} "$@"
          '';
        };
      });

      apps = forAllSystems (pkgs:
        let p = self.packages.${pkgs.stdenv.hostPlatform.system}; in {
          default = { type = "app"; program = lib.getExe' p.t3code-nightly "t3code-desktop"; meta.description = "T3 Code nightly desktop"; };
          t3 = { type = "app"; program = lib.getExe' p.t3code-nightly "t3"; meta.description = "T3 Code nightly CLI"; };
          update = { type = "app"; program = lib.getExe p.update; meta.description = "Pin the newest upstream nightly"; };
        });

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) t3code-nightly;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
