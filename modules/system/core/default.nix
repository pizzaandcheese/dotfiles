{
  inputs,
  patchedPkgs,
}: {
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.jd.core;
in {
  options.jd.core = {
    enable = mkOption {
      description = "Enable core options";
      type = types.bool;
      default = true;
    };

    time = mkOption {
      description = "Time zone";
      type = types.enum ["west" "east"];
      default = "east";
    };
  };

  config = mkIf (cfg.enable) {
    i18n.defaultLocale = "en_US.UTF-8";
    time.timeZone =
      if (cfg.time == "east")
      then "US/Eastern"
      else "US/Pacific";

    hardware.enableRedistributableFirmware = lib.mkDefault true;

    # Nix search paths/registries from:
    # https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/166d6ebd9f0de03afc98060ac92cba9c71cfe550/lib/options.nix
    # Context thread: https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/166d6ebd9f0de03afc98060ac92cba9c71cfe550/lib/options.nix
    nix = let
      flakes =
        filterAttrs
        (name: value: value ? outputs)
        inputs;
      flakesWithPkgs =
        filterAttrs
        (name: value:
          value.outputs ? legacyPackages || value.outputs ? packages)
        flakes;
      nixRegistry = builtins.mapAttrs (name: v: {flake = v;}) flakes;
    in {
      registry = nixRegistry;
      nixPath =
        mapAttrsToList
        (name: _: "${name}=/etc/nix/inputs/${name}")
        flakesWithPkgs;
      package = pkgs.nixUnstable;
      gc = {
        persistent = true;
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
      # For nixpkgs-wayland: https://github.com/nix-community/nixpkgs-wayland#flake-usage
      binaryCachePublicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      ];
      binaryCaches = [
        "https://cache.nixos.org"
        "https://nixpkgs-wayland.cachix.org"
      ];
      extraOptions = ''
        keep-outputs = true
        keep-derivations = true
        experimental-features = nix-command flakes
      '';
      settings = {
        auto-optimise-store = true;
      };
    };

    environment = {
      sessionVariables = {
        EDITOR = "vim";
      };
      etc =
        mapAttrs'
        (name: value: {
          name = "nix/inputs/${name}";
          value = {
            source =
              if name == "nixpkgs"
              then patchedPkgs.outPath
              else value.outPath;
          };
        })
        inputs;

      shells = [pkgs.zsh pkgs.bash];
      # ZSH completions
      pathsToLink = ["/share/zsh"];
      systemPackages = with pkgs; [
        # Misc.
        neofetch
        bat

        # Shells
        zsh

        # Files
        exa
        unzip

        # Benchmarking
        hyperfine

        # Hardware
        inxi
        usbutils

        # Kernel
        systeroid
        strace

        # Network
        dnsutils
        gping

        # secrets
        rage
        agenix-cli

        # Processors
        jq
        htmlq
        ripgrep
        gawk
        gnused

        # Downloaders
        wget
        curl

        # system monitors
        bottom
        htop
        acpi
        pstree

        # version ocntrol
        git
        difftastic

        # Nix tools
        patchelf
        nix-index
        nix-tree
        nix-diff
        nix-prefetch
        deploy-rs
        manix
        comma

        # Text editor
        vim

        # Calculator
        bc
        bitwise

        # Scripts
        scripts.sysTools

        # docs
        tldr
        man-pages
        man-pages-posix
      ];
    };

    security.sudo.extraConfig = "Defaults env_reset,timestamp_timeout=5";
    security.sudo.execWheelOnly = true;

    documentation = {
      enable = true;
      dev.enable = true;
      man = {
        enable = true;
        generateCaches = true;
      };
      info.enable = true;
      nixos.enable = true;
    };
  };
}
