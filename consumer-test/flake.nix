{
  description = "Consumer test for Roary flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    roary.url = "path:..";
  };

  outputs = { self, nixpkgs, roary }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ roary.packages.${system}.roary ];
      };
    };
}
