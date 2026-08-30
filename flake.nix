{
  description = "A reproducible Rust development environment with modern tooling.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Granular builder helper for consumer flakes (Way A)
      mkRustShell =
        {
          pkgs,
          enableWasm ? false,
          extraPackages ? [ ],
          env ? { },
          shellHook ? "",
        }:
        let
          baseShell = pkgs.mkShell {
            packages =
              [
                pkgs.cargo
                pkgs.rustc
                pkgs.rustfmt
                pkgs.clippy
                pkgs.rust-analyzer
                pkgs.cargo-edit
                pkgs.cargo-watch
              ]
              ++ (if enableWasm then [ pkgs.wasm-pack pkgs.wasm-bindgen-cli ] else [ ])
              ++ extraPackages;
            RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
            shellHook = ''
              echo "Entering Rust development environment..."
              echo "Available tools: cargo, rustc, rustfmt, clippy, rust-analyzer, cargo-edit, cargo-watch"
            '';
          };
        in
        baseShell.overrideAttrs (oldAttrs: {
          env = oldAttrs.env or { } // env;
          shellHook = (oldAttrs.shellHook or "") + "\n" + shellHook;
        });
    in
    {
      # Granular Library helper functions for consumer flakes
      lib = {
        inherit mkRustShell;
      };

      # Scaffolding templates for 'nix flake init' (Way B)
      templates = {
        default = {
          path = ./.;
          description = "A reproducible Rust development environment with modern tooling";
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        defaultShell = mkRustShell { inherit pkgs; };
        wasmShell = mkRustShell {
          inherit pkgs;
          enableWasm = true;
        };
      in
      {
        devShells = {
          default = defaultShell;
          wasm = wasmShell;
        };

        checks = {
          default = defaultShell;
          wasm = wasmShell;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "rust-env-info" ''
              echo "=== Rust Nix Development Environment ==="
              ${pkgs.rustc}/bin/rustc --version
              ${pkgs.cargo}/bin/cargo --version
            '';
          };
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
