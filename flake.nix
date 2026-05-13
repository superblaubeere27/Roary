{
  description = "Flake for building and running Roary (Bio-Roary)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      perl = pkgs.perl.withPackages (p:
        let
          arrayUtils = p.buildPerlPackage {
            pname = "Array-Utils";
            version = "0.5";
            src = pkgs.fetchurl {
              url = "https://cpan.metacpan.org/authors/id/Z/ZM/ZMIJ/Array/Array-Utils-0.5.tar.gz";
              sha256 = "89dd1b7fcd9b4379492a3a77496e39fe6cd379b773fd03a6b160dd26ede63770";
            };
            doCheck = false;
          };

          bioProcedural = p.buildPerlPackage {
            pname = "Bio-Procedural";
            version = "1.7.4";
            src = pkgs.fetchurl {
              url = "https://cpan.metacpan.org/authors/id/C/CJ/CJFIELDS/Bio-Procedural-1.7.4.tar.gz";
              sha256 = "sha256-0r2c+7CR7uLYDtbPgSrDgTscihqsogZxA39fIl0x0do=";
            };
            propagatedBuildInputs = [ p.BioPerl ];
            doCheck = false;
          };
        in
        (with p; [
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
      ]) ++ [ arrayUtils bioProcedural ]
      );

      # Provide Perl with Roary runtime dependencies available in nixpkgs.
      perlWithDeps = perl;

      appCpanminus = pkgs.perlPackages.Appcpanminus;
    in {
      packages.${system} = rec {
        roary = pkgs.stdenv.mkDerivation {
          pname = "roary";
          version = "3.13.0";
          src = ./.;

          nativeBuildInputs = [ perlWithDeps appCpanminus pkgs.makeWrapper ];

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
            wrapProgram $out/bin/roary \
              --prefix PATH : ${perlWithDeps}/bin \
              --prefix PERL5LIB : ${perlWithDeps}/${pkgs.perl.libPrefix}:$out/lib
          '';
        };

        default = roary;
      };

      apps.${system} = rec {
        roary = {
          type = "app";
          program = "${self.packages.${system}.roary}/bin/roary";
        };
        default = roary;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          self.packages.${system}.roary
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

    };
}
