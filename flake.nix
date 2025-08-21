{
  description = "Scouter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/fc8835d44a356d64953cb31f1b086fab1e25bb5b";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      beamPkgs = pkgs.beam.packages.erlang_28;
    in
    {
      formatter.aarch64-darwin = pkgs.nixfmt;

      # nix develop
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/darwin/apple-sdk/frameworks.nix
      devShells.aarch64-darwin.default = pkgs.mkShell {
        buildInputs = with pkgs.darwin.apple_sdk.frameworks; [
          AppKit
          CoreServices
          Foundation
          beamPkgs.elixir_1_18
          pkgs.caddy
          pkgs.duckdb
          pkgs.hivemind
          pkgs.imgproxy
          pkgs.lima
          pkgs.minio
          pkgs.minio-client
          pkgs.sqlite
        ];
      };

      apps.aarch64-darwin.iex = {
        type = "app";
        program = "${beamPkgs.elixir_1_18}/bin/iex";
      };

      apps.aarch64-darwin.mix = {
        type = "app";
        program = "${beamPkgs.elixir_1_18}/bin/mix";
      };

      apps.aarch64-darwin.caddy = {
        type = "app";
        program = "${pkgs.caddy}/bin/caddy";
      };

      apps.aarch64-darwin.minio = {
        type = "app";
        program = "${pkgs.minio}/bin/minio";
      };

      apps.aarch64-darwin.mc = {
        type = "app";
        program = "${pkgs.minio-client}/bin/mc";
      };

      apps.aarch64-darwin.imgproxy = {
        type = "app";
        program = "${pkgs.imgproxy}/bin/imgproxy";
      };

      apps.aarch64-darwin.duckdb = {
        type = "app";
        program = "${pkgs.duckdb}/bin/duckdb";
      };

      packages.aarch64-darwin.default = beamPkgs.elixir_1_18;
      packages.aarch64-darwin.lima = pkgs.lima;
      packages.aarch64-darwin.fish = pkgs.fish;
    };
}
