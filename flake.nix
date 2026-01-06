{
  description = "Scouter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/fc8835d44a356d64953cb31f1b086fab1e25bb5b";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPkgs = pkgs.beam.packages.erlang_28;
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        # nix develop
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/darwin/apple-sdk/frameworks.nix
        devShells.default = pkgs.mkShell {
          buildInputs = [
            beamPkgs.elixir_1_18
            pkgs.erofs-utils
            pkgs.caddy
            pkgs.duckdb
            pkgs.minio
            pkgs.minio-client
            pkgs.sqlite
          ];
        };

        apps.iex = {
          type = "app";
          program = "${beamPkgs.elixir_1_18}/bin/iex";
        };

        apps.mix = {
          type = "app";
          program = "${beamPkgs.elixir_1_18}/bin/mix";
        };

        apps.caddy = {
          type = "app";
          program = "${pkgs.caddy}/bin/caddy";
        };

        apps.minio = {
          type = "app";
          program = "${pkgs.minio}/bin/minio";
        };

        apps.mc = {
          type = "app";
          program = "${pkgs.minio-client}/bin/mc";
        };

        apps.duckdb = {
          type = "app";
          program = "${pkgs.duckdb}/bin/duckdb";
        };

        apps.hivemind = {
          type = "app";
          program = "${pkgs.hivemind}/bin/hivemind";
        };

        packages.default = beamPkgs.elixir_1_18;
      }
    );
}
