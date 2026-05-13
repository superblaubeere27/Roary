{
  description = "Flake for building and running Roary (Bio-Roary)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      arrayUtils = pkgs.perlPackages.buildPerlPackage {
        pname = "Array-Utils";
        version = "0.5";
        src = pkgs.fetchurl {
          url = "https://cpan.metacpan.org/authors/id/Z/ZM/ZMIJ/Array/Array-Utils-0.5.tar.gz";
          sha256 = "89dd1b7fcd9b4379492a3a77496e39fe6cd379b773fd03a6b160dd26ede63770";
        };
        doCheck = false;
      };

      # Provide Perl with Roary runtime dependencies available in nixpkgs.
      perlWithDeps = pkgs.perl.withPackages (p: (with p; [
        Moose
        FileWhich
        GetoptLongDescriptive
        LogLog4perl
        BioPerl
        TextCSV
        DigestMD5File
        FileSlurper
        FileSlurp
        FileGrep
        ExceptionClass
        Graph
        ParallelForkManager
        IPCSystemSimple
        JSON
        TryTiny
        DataUUID
        SortNaturally
      ]) ++ [ arrayUtils ]);

      appCpanminus = pkgs.perlPackages.Appcpanminus;
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          perlWithDeps
          appCpanminus
          brotli
          gzip
          gnutar
          coreutils
        ];


        shellHook = ''
          export PERL5LIB="${toString ./lib}"
          echo "Entered Roary dev shell. Run: bin/roary --help"
        '';
      };

      packages.${system}.roary = pkgs.stdenv.mkDerivation {
        pname = "roary";
        version = "3.13.0";
        src = ./.;

        nativeBuildInputs = [ perlWithDeps appCpanminus ];

        buildInputs = [
          pkgs.brotli
          pkgs.gzip
          pkgs.mafft
          pkgs.bedtools
        ];

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib
          cp bin/roary $out/bin/roary
          cp -r lib/Bio $out/lib/
          chmod +x $out/bin/roary
        '';
      };
    };
}
