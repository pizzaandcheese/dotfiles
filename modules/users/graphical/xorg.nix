{ pkgs, config, lib, ... }:
with lib;

let
  cfg = config.jd.graphical.xorg;
  systemCfg = config.machineData.systemConfig;
in
{
  options.jd.graphical.xorg = {
    enable = mkOption {
      description = "Enable xorg";
      type = types.bool;
      default = false;
    };

    type = mkOption {
      description = ''What desktop/wm to use. Options: "dwm"'';
      type = types.enum [ "dwm" ];
      default = null;
    };

    screenlock = {
      enable = mkOption {
        description = "Enable screen locking (xss-lock). Only used with dwm";
        type = types.bool;
        default = false;
      };

      timeout = {
        script = mkOption {
          description = "Script to run on timeout. Default null";
          type = with types; nullOr package;
          default = null;
        };

        time = mkOption {
          description = "Time in seconds until run timeout script. Default 180.";
          type = types.int;
          default = 180;
        };
      };

      lock = {
        command = mkOption {
          description = "Lock command. Default xsecurelock";
          type = types.str;
          default = "${pkgs.xsecurelock}/bin/xsecurelock";
        };

        time = mkOption {
          description = "Time in seconds after timeout until lock. Default 180.";
          type = types.int;
          default = 180;
        };
      };
    };
  };

  config = mkIf (cfg.enable) (
    let
      xStartCommand = "${pkgs.dwmJD}/bin/dwm";
    in
    {
      assertions = [
        {
          assertion = systemCfg.graphical.xorg.enable;
          message = "To enable xorg for user, it must be enabled for system";
        }
      ];

      home.packages = mkIf (cfg.type == "dwm") (with pkgs; [
        dwmJD
        stJD
        dmenu
        xbindkeys
        xwallpaper
      ]);

      xdg.enable = true;

      home.file = {
        ".xinitrc" = {
          executable = true;
          text = ''
            # .xinitrc autogenerated. Do not edit

            # firefox xserver variable
            export MOZ_USE_XINPUT2=1;

            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

            if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
              eval $(dbus-launch --exit-with-session --sh-syntax)
            fi
            
            # Need to import XDG_SESSION_ID & PATH for xss-lock and xsecurelock respectively
            systemctl --user import-environment DISPLAY XAUTHORITY XDG_SESSION_ID PATH XDG_CONFIG_HOME
            
            # https://bbs.archlinux.org/viewtopic.php?id=224652
            # Requires --systemd becuase of gnome-keyring error. Unsure how differs from systemctl --user import-environment
            if command -v dbus-update-activation-environment >/dev/null 2>&1; then
              dbus-update-activation-environment --systemd DISPLAY XAUTHORITY
            fi

            systemctl --user start dwm-session.target

            ${if config.machineData.name == "framework" then "xrandr --output eDP-1 --scale 1.5x1.5" else ""}
            xset s ${toString cfg.screenlock.timeout.time} ${toString cfg.screenlock.lock.time}
            ${pkgs.xbindkeys}/bin/xbindkeys
            ${pkgs.xwallpaper}/bin/xwallpaper --zoom ${config.xdg.configHome}/wallpapers/peacefulmtn.jpg
            ${xStartCommand}

            systemctl --user stop dwm-session.target
            systemctl --user stop graphical-session.target
            systemctl --user stop graphical-session-pre.target

            # Wait until the units actually stop.
            while [ -n "$(systemctl --user --no-legend --state=deactivating list-units)" ]; do
              sleep 0.5
            done
          '';
        };


      };

      home.file.".xbindkeysrc" = mkIf (cfg.type == "dwm" && systemCfg.connectivity.sound.enable) {
        text = ''
          # Mute volume
          "${pkgs.scripts.soundTools}/bin/stools vol toggle"
            XF86AudioMute
          # Raise volume
          "${pkgs.scripts.soundTools}/bin/stools vol up"
            XF86AudioRaiseVolume
          # Lower volume
          "${pkgs.scripts.soundTools}/bin/stools vol down"
            XF86AudioLowerVolume
          # Mute microphone
          "${pkgs.scripts.soundTools}/bin/stools mic toggle"
            XF86AudioMicMute
        '';
      };

      systemd = mkIf (cfg.type == "dwm" && cfg.screenlock.enable) {
        user.services = {
          xss-lock = {
            Install = {
              WantedBy = [ "dwm-session.target" ];
            };

            Unit = {
              Description = "XSS Lock Daemon";
              PartOf = [ "dwm-session.target" ];
              After = [ "graphical-session.target" ];
            };

            Service = {
              ExecStart = "${pkgs.xss-lock}/bin/xss-lock -s \${XDG_SESSION_ID} ${if cfg.screenlock.timeout.script == null then "" else "-n ${cfg.screenlock.timeout.script}"} -l -- ${cfg.screenlock.lock.command}";
            };
          };
        };

        user.targets.dwm-session = {
          Unit = {
            Description = "dwm compositor session";
            Documentation = [ "man:systemd.special(7)" ];
            BindsTo = [ "graphical-session.target" ];
            Wants = [ "graphical-session-pre.target" ];
            After = [ "graphical-session-pre.target" ];
          };
        };

        user.services.picom =
          let
            configFile = pkgs.writeText "picom.conf" ''
              backend = "glx";
            '';
          in
          {
            Unit = {
              Description = "Picom X11 compositor";
              After = [ "graphical-session-pre.target" ];
              PartOf = [ "dwm-session.target" ];
            };

            Install = {
              WantedBy = [ "dwm-session.target" ];
            };

            Service = {
              ExecStart = "${pkgs.picom}/bin/picom --config ${configFile} --experimental-backends";
              Restart = "always";
              RestartSec = 3;
              Environment = [ "allow_rgb10=configs=false" ];
            };
          };
      };
    }
  );
}