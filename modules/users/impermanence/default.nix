{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.jd.impermanence;
in
{
  options.jd.impermanence = {
    enable = mkEnableOption "impermanence";

    backupPool = mkOption {
      description = "Persisted pool that is backed up";
      type = types.str;
      default = "/backup/home/ryan";
    };

    persistPool = mkOption {
      description = "Persisted pool that is not backed up (eg cache)";
      type = types.str;
      default = "/persist/home/ryan";
    };
  };

  config = mkIf cfg.enable {
    home.persistence.${cfg.persistPool} = {
      directories = [
        xdg.cacheHome
        ".secrets"
        ".dotfiles"
      ];
    };

    home.persistence.${cfg.backupPool} = {
      directories =
        [
          xdg.dataHome
          xdg.stateHome
        ]
        // (filter isString (attrValues xdg.userDirs));
    };
  };
}
