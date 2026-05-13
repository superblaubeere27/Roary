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

          graphReadWrite = p.buildPerlPackage {
            pname = "Graph-ReadWrite";
            version = "2.10";
            src = pkgs.fetchurl {
              url = "https://cpan.metacpan.org/authors/id/N/NE/NEILB/Graph-ReadWrite-2.10.tar.gz";
              sha256 = "sha256-UWweqfrLmV28ONFzXViXSyOZhiVn5zG3KcjQvC7loUs=";
            };
            propagatedBuildInputs = [ p.Graph p.GraphViz ];
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
        FileFindRule
      ]) ++ [ arrayUtils bioProcedural graphReadWrite ]
      );

      # Provide Perl with Roary runtime dependencies available in nixpkgs.
      perlWithDeps = perl;

      appCpanminus = pkgs.perlPackages.Appcpanminus;

      mcl = pkgs.stdenv.mkDerivation {
        pname = "mcl";
        version = "14-137";
        src = pkgs.fetchurl {
          url = "https://micans.org/mcl/src/mcl-14-137.tar.gz";
          sha256 = "sha256-tXhol6ioyhGes1WlYwgGpNpy6oQkPbqFsZqG8UdXtJc=";
        };
        nativeBuildInputs = [ pkgs.gnumake ];
        configurePhase = ''
          ./configure --prefix=$out
        '';
        buildPhase = ''
          make CFLAGS="-fcommon"
        '';
        installPhase = ''
          make install

          # Upstream build no longer installs mcxdeblast in modern toolchains;
          # ship the script from source to preserve Roary compatibility.
          install -Dm755 src/alien/oxygen/src/mcxdeblast $out/bin/mcxdeblast
        '';
      };

      fasttree = pkgs.stdenv.mkDerivation {
        pname = "fasttree";
        version = "2.1.10";
        src = pkgs.fetchurl {
          url = "http://microbesonline.org/fasttree/FastTree-2.1.10.c";
          sha256 = "sha256-VMuJ/BcoqXSlnq56fuYwnN083dqaTFW3AKcSGfxukm0=";
        };
        dontUnpack = true;
        nativeBuildInputs = [ pkgs.gcc ];
        buildPhase = ''
          cp $src FastTree.c
          gcc -O3 -finline-functions -funroll-loops -o FastTree FastTree.c -lm
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp FastTree $out/bin/FastTree
          ln -s $out/bin/FastTree $out/bin/fasttree
        '';
      };
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
            pkgs.blast
            pkgs."cd-hit"
            pkgs.parallel
            fasttree
            mcl
          ];

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/lib
            cp -r bin/* $out/bin/
            cp -r lib/Bio $out/lib/
            chmod +x $out/bin/*

            # Ensure all entrypoints can find bundled scripts, perl libraries,
            # and external binaries required by the workflow.
            externalPath=${pkgs.lib.makeBinPath [
              pkgs.bedtools
              pkgs.blast
              pkgs."cd-hit"
              pkgs.parallel
              pkgs.mafft
              pkgs.brotli
              pkgs.gzip
              fasttree
              mcl
            ]}

            for exe in $out/bin/*; do
              if [ -f "$exe" ]; then
                wrapProgram "$exe" \
                  --prefix PATH : $out/bin:$externalPath:${perlWithDeps}/bin \
                  --prefix PERL5LIB : ${perlWithDeps}/${pkgs.perl.libPrefix}:$out/lib
              fi
            done
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
