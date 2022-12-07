{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.jd.graphical;
  systemCfg = config.machineData.systemConfig;
in {
  options.jd.graphical.theme = mkOption {
    type = with types; enum ["arc-dark" "materia-dark"];
    description = "Enable wayland";
    default = "arc-dark";
  };

  config = let
  in
    mkIf (cfg.xorg.enable == true || cfg.wayland.enable == true)
    {
      home = {
        sessionVariables = {
          QT_QPA_PLATFORMTHEME = "qt5ct";
        };

        packages = with pkgs;
          mkIf (systemCfg.connectivity.sound.enable) [
            # Cursor
            jdpkgs.volantes-cursors

            # qt
            libsForQt5.qtstyleplugin-kvantum
            qt5ct

            xdg-utils
          ];
      };

      gtk = {
        enable = true;
        theme = mkMerge [
          (mkIf (cfg.theme == "arc-dark") {
            package = with pkgs; arc-theme;
            name = "Arc-Dark";
          })
          (mkIf (cfg.theme == "materia-dark") {
            package = with pkgs; materia-theme;
            name = "Materia-dark";
          })
        ];

        iconTheme = {
          name = "la-capitaine-icon-theme";
        };

        gtk3.extraConfig = {
          gtk-cursor-theme-name = "volantes_cursors";
          gtk-application-prefer-dark-theme = true;
        };
      };

      # https://github.com/nix-community/home-manager/issues/2064
      systemd.user.targets.tray = {
        Unit = {
          Description = "Home manager system tray";
          Requires = ["graphical-session-pre.target"];
          After = ["xdg-desktop-portal-gtk.service"];
        };
      };

      systemd.user.sessionVariables = {
        # So graphical services are themed (eg trays)
        QT_QPA_PLATFORMTHEME = "qt5ct";
        PATH = builtins.concatStringsSep ":" [
          "${pkgs.libsForQt5.qtstyleplugin-kvantum}/bin"
          "${pkgs.qt5ct}/bin"
          "${pkgs.xdg-utils}/bin"
          "${pkgs.firefox}/bin"
        ];
      };

      systemd.user.services = {
        plasma-dolphin = {
          Unit = {
            Description = "Dolphin file manager";
            PartOf = "graphical-session.target";
          };

          Service = {
            ExecStart = "${pkgs.dolphin}/bin/dolphin --daemon";
            BusName = "org.freedesktop.FileManager1";
            Slice = "background.slice";
          };
        };
      };

      xdg = {
        systemDirs.data = [
          "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
          "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        ];

        configFile = {
          "qt5ct/qt5ct.conf" = {
            text = ''
              [Appearance]
              icon_theme=la-capitaine-icon-theme
              style=kvantum-dark
            '';
          };

          "Kvantum/kvantum.kvconfig" = mkMerge [
            (mkIf (cfg.theme == "arc-dark") {
              text = "theme=KvArcDark";
            })
            (mkIf (cfg.theme == "materia-dark") {
              text = "theme=MateriaDark";
            })
          ];

          "Kvantum/ArcDark" = {
            source = "${pkgs.arc-kde-theme}/share/Kvantum/ArcDark";
          };

          "Kvantum/MateriaDark" = {
            source = "${pkgs.materia-kde-theme}/share/Kvantum/MateriaDark";
          };

          "wallpapers" = {
            source = ./wallpapers;
          };

          "kdeglobals" = {
            text = ''
              [General]
              TerminalApplication=${pkgs.foot}/bin/foot
            '';
          };
        };

        dataFile = {
          "icons/default/index.theme" = {
            text = ''
              [icon theme]
              Inherits=volantes_cursors
            '';
          };

          "icons/volantes_cursors" = {
            source = "${pkgs.jdpkgs.volantes-cursors}/usr/share/icons/volantes_cursors";
          };

          "icons/la-capitaine-icon-theme" = {
            source = "${pkgs.jdpkgs.la-capitaine-icon-theme}/share/icons/la-capitaine-icon-theme";
          };

          "icons/breeze" = {
            source = "${pkgs.breeze-icons}/share/icons/breeze";
          };

          "icons/breeze-dark" = {
            source = "${pkgs.breeze-icons}/share/icons/breeze-dark";
          };

          "icons/elementary" = {
            source = "${pkgs.pantheon.elementary-icon-theme}/share/icons/elementary";
          };

          "icons/gnome" = {
            source = "${pkgs.gnome-icon-theme}/share/icons/gnome";
          };

          "icons/hicolor" = {
            source = "${pkgs.hicolor-icon-theme}/share/icons/hicolor";
          };

          # https://wiki.archlinux.org/title/XDG_MIME_Applications#New_MIME_types
          # https://specifications.freedesktop.org/shared-mime-info-spec/shared-mime-info-spec-latest.html#idm46292897757504
          # "mime/text/x-r-markdown.xml" = {
          #   text = ''
          #     <?xml version="1.0" encoding="UTF-8"?>
          #     <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
          #       <mime-type type="text/x-r-markdown">
          #         <comment>RMarkdown file</comment>
          #         <icon name="text-x-r-markdown"/>
          #         <glob pattern="*.Rmd"/>
          #         <glob pattern="*.Rmarkdown"/>
          #       </mime-type>
          #     </mime-info>
          #   '';
          # };
        };
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          cursor-theme = "volantes_cursors";
          icon-theme = "la-capitaine-icon-theme";
          # https://askubuntu.com/questions/1404764/how-to-use-hdystylemanagercolor-scheme
          color-scheme = "prefer-dark";
          text-scaling-factor = 1.25;
        };
      };

      services = {
        gnome-keyring.enable = true;
      };

      xdg = {
        enable = true;
        mime.enable = true;
        mimeApps = {
          enable = true;
          associations.added = {
            "x-scheme-handler/terminal" = "foot.desktop";
            "x-scheme-handler/file" = "org.kde.dolphin.desktop";
            "x-directory/normal" = "org.kde.dolphin.desktop";
          };
          defaultApplications = {
            "application/pdf" = "okularApplication_pdf.desktop";
            "application/x-shellscript" = "nvim.desktop";
            "application/x-perl" = "nvim.desktop";
            "application/json" = "nvim.desktop";
            "text/x-readme" = "nvim.desktop";
            "text/plain" = "nvim.desktop";
            "text/markdown" = "nvim.desktop";
            "text/x-csrc" = "nvim.desktop";
            "text/x-chdr" = "nvim.desktop";
            "text/x-python" = "nvim.desktop";
            "text/x-tex" = "texstudio.desktop";
            "text/x-makefile" = "nvim.desktop";
            "inode/directory" = "org.kde.dolphin.desktop";
            "x-directory/normal" = "org.kde.dolphin.desktop";
            "x-scheme-handler/file" = "org.kde.dolphin.desktop";
            "x-scheme-handler/terminal" = "foot.desktop";
          };
        };
      };
    };
}
