{
  description = "optparse-applicative for Idris2 - Applicative CLI option parser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    idris2-withpkgs.url = "github:gvnkd/flake-idris2-withPackages";
  };

  outputs = { self, nixpkgs, flake-utils, idris2-withpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        idris2 = idris2-withpkgs.inputs.idris2-src.packages.${system}.idris2;

        # Select registry packages to use as dependencies.
        # Available packages: containers, algebra, array, json, json-simple,
        # async, bytestring, hedgehog, parser, and 150+ more.
        idrisLibraries = with idris2-withpkgs.packages.${system}; [
          # Add dependencies here as needed
          # json
          # containers
        ];

        # Wrapped idris2 with all selected packages available in devShell
        idris2Wrapped = idris2-withpkgs.lib.${system}.withPackages (p: [
          # Add dependencies here as needed
          # p.json
          # p.containers
        ]);

        # Docs packages for dependencies (add <name>-docs here)
        docsPkgs = with idris2-withpkgs.packages.${system}; [
          # Add dependency docs here as needed
          # json-docs
        ];

        # Combine all docs into a single tree: <combined>/share/doc/<pkg>/
        combinedDocs = pkgs.symlinkJoin {
          name = "combined-idris2-docs";
          paths = docsPkgs;
        };

        # Helper script: doc list | doc show <pkg> [<module>]
        docScript = pkgs.runCommand "doc" {} ''
          mkdir -p $out/bin
          cp ${pkgs.replaceVars ./scripts/doc {
            DOCS = "${combinedDocs}/share/doc";
          }} $out/bin/doc
          chmod +x $out/bin/doc
        '';

        pkg = pkgs.idris2Packages.buildIdris {
          src = ./.;
          ipkgName = "optparse-applicative";
          version = "0.1.0";
          inherit idrisLibraries;
        };
      in
      {
        packages = {
          default = pkg.executable;
          lib = pkg.library';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            idris2Wrapped
            pkgs.rlwrap
            idris2-withpkgs.packages.${system}.idris2-mkdoc-md
            docScript
          ];

          shellHook = ''
            export LD_LIBRARY_PATH="${idris2Wrapped}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export IDRIS2_LIBS="${idris2Wrapped}/lib''${IDRIS2_LIBS:+:$IDRIS2_LIBS}"

            # Symlink ./docs to combined docs for easy browsing
            if [ -L ./docs ]; then
              rm ./docs
            elif [ -e ./docs ]; then
              echo "Warning: ./docs exists and is not a symlink. Skipping."
            else
              ln -s "${combinedDocs}/share/doc" ./docs
            fi

            echo "optparse-applicative - Idris2 CLI parser library"
            echo ""
            echo "Build:"
            echo "  idris2 --build optparse-applicative.ipkg"
            echo "  ./build/exec/optparse-applicative"
            echo ""
            echo "Add dependencies:"
            echo "  1. Edit flake.nix, add to idrisLibraries and idris2Wrapped"
            echo "  2. Edit optparse-applicative.ipkg, add to depends:"
            echo "  3. Run: nix develop"
            echo ""
            echo "Generate docs:"
            echo "  idris2-mkdoc-md -o ./my-docs optparse-applicative.ipkg"
            echo ""
            echo "Browse dependency docs:"
            echo "  doc list                     # list available package docs"
            echo "  doc show json                # view json package index"
            echo "  doc show json Data.List      # view specific module docs"
            echo "  ls ./docs/                   # or browse the ./docs/ symlink"
            echo ""
            echo "REPL with packages:"
            echo "  rlwrap idris2"
          '';
        };
      }
    );
}
