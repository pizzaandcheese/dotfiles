{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.jd.graphical;
in {
  options.jd.graphical.applications = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable graphical applications";
    };
  };

  config = mkIf (cfg.applications.enable) {
    home.packages = with pkgs; [
      jdpkgs.dolphin # fixes dbus/firefox
      okular
      xorg.xinput

      thunderbird
      # jdpkgs.rstudioWrapper
      # jdpkgs.texstudioWrapper
      microsoft-edge

      flameshot
      libsixel

      # Password manager
      bitwarden
      authy

      # Messaging
      slack
      discord
      element-desktop

      # Reading
      calibre

      # Video conference
      zoom-us

      # Note taking
      xournalpp
      rnote

      # Sound
      pavucontrol
      pasystray

      # music
      cider

      # kdeconnect
    ];

    xdg.configFile = {
      "discord/settings.json" = {
        text = ''
          {
            "SKIP_HOST_UPDATE": true
          }
        '';
      };
    };
  };
}
