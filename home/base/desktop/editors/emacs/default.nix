# ==============================================
# Based on doomemacs's auther's config:
#   https://github.com/hlissner/dotfiles/blob/master/modules/editors/emacs.nix
#
# Emacs Tutorials:
#  1. Official: <https://www.gnu.org/software/emacs/tour/index.html>
#  2. Doom Emacs: <https://github.com/doomemacs/doomemacs/blob/master/docs/index.org>
#
{
  config,
  lib,
  pkgs,
  doomemacs,
  ...
}:
with lib; let
  cfg = config.modules.editors.emacs;
  envExtra = ''
    export PATH="${config.xdg.configHome}/emacs/bin:$PATH"
  '';
  shellAliases = {
    e = "emacsclient --create-frame --tty";
  };
  librime-dir = "${config.xdg.dataHome}/librime";
  parinfer-rust-lib-dir = "${config.xdg.dataHome}/parinfer-rust";
in {
  options.modules.editors.emacs = {
    enable = mkEnableOption "Emacs Editor";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = with pkgs; [
        ## Doom dependencies
        git
        (ripgrep.override {withPCRE2 = true;})
        gnutls # for TLS connectivity

        ## Optional dependencies
        fd # faster projectile indexing
        imagemagick # for image-dired
        zstd # for undo-fu-session/undo-tree compression

        ## Module dependencies
        # :checkers spell
        (aspellWithDicts (ds: with ds; [en en-computers en-science]))
        # :tools editorconfig
        editorconfig-core-c # per-project style config
        # :tools lookup & :lang org +roam
        sqlite
        # :lang latex & :lang org (latex previews)
        texlive.combined.scheme-medium
      ];

      programs.bash.bashrcExtra = envExtra;
      programs.zsh.envExtra = envExtra;
      home.shellAliases = shellAliases;
      programs.nushell.shellAliases = shellAliases;

      # allow fontconfig to discover fonts and configurations installed through `home.packages`
      fonts.fontconfig.enable = true;

      xdg.configFile."doom" = {
        source = ./doom;
        force = true;
      };

      home.activation.installDoomEmacs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 ${doomemacs}/ ${config.xdg.configHome}/emacs/

        # librime for emacs-rime
        ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 ${pkgs.librime}/ ${librime-dir}/

        # libparinfer_rust for emacs' parinfer-rust-mode
        mkdir -p ${parinfer-rust-lib-dir}
        ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744  ${pkgs.vimPlugins.parinfer-rust}/lib/libparinfer_rust.* ${parinfer-rust-lib-dir}/parinfer-rust.so
      '';
    }

    (mkIf pkgs.stdenv.isLinux (
      let
        # Do not use emacs-nox here, which makes the mouse wheel work abnormally in terminal mode.
        # pgtk (pure gtk) build add native support for wayland.
        # https://www.gnu.org/savannah-checkouts/gnu/emacs/emacs.html#Releases
        emacsPkg = pkgs.emacs29-pgtk;
      in {
        home.packages = [emacsPkg];
        services.emacs = {
          enable = true;
          package = emacsPkg;
          startWithUserSession = true;
        };
      }
    ))

    (mkIf pkgs.stdenv.isDarwin (
      let
        # macport adds some native features based on GNU Emacs 29
        # https://bitbucket.org/mituharu/emacs-mac/src/master/README-mac
        emacsPkg = pkgs.emacs29-macport;
      in {
        home.packages = [emacsPkg];
        launchd.enable = true;
        launchd.agents.emacs = {
          enable = true;
          config = {
            ProgramArguments = [
              "${pkgs.bash}/bin/bash"
              "-l"
              "-c"
              "${emacsPkg}/bin/emacs --fg-daemon"
            ];
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stderr.log";
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stdout.log";
            RunAtLoad = true;
            KeepAlive = true;
          };
        };
      }
    ))
  ]);
}
