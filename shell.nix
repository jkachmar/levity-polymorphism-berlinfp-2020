{ pkgs ? import <nixpkgs> {} }:

let
  texlive = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      # Basic "scheme" of LaTeX packages
      scheme-small
      pgfopts
      # Citations and bibliographies
      bibtex
      # Presentations and themeing
      beamer
      beamertheme-metropolis;
  };

  fonts = pkgs.makeFontsConf {
    fontDirectories = [
      pkgs.fira
      pkgs.fira-code

      pkgs.inconsolata
      pkgs.open-sans
    ];
  };
in
  pkgs.mkShell {
    buildInputs = [
      # LaTeX package set
      texlive
      # Markdown -> LaTeX -> PDF conversion
      pkgs.pandoc
      # File watching and rebuilding
      pkgs.watchexec
      # Font configuration and management
      pkgs.fontconfig
    ];
    shellHook = ''
      export FONTCONFIG_FILE=${fonts}
    '';
  }
