{ inputs, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { lib, ... }:
    {
      options.ciPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Packages for CI environment";
      };
    }
  );

  config.perSystem =
    { config, system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };

      purs-nix = inputs.purs-nix { inherit system; };

      ps = purs-nix.purs {
        dependencies = [
          "ursi.debug"
          "effect"
          "prelude"
        ];

        test-dependencies = [
          "test-unit"
        ];

        dir = ./..;
      };

    in
    {
      _module.args = {
        inherit
          pkgs
          ps
          purs-nix
          ;
        ps-tools = inputs.ps-tools.legacyPackages.${system};
      };

      ciPackages = with pkgs; [ nodejs_24 ];

      packages = with ps; {
        default = output { };
        ci = pkgs.buildEnv {
          name = "ci";
          paths = config.ciPackages;
        };
      };
    };
}
