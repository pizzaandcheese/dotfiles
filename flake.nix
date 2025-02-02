{
  description = "System Config";
  inputs = {
    # Package repositories
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-22.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";

    nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
    nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs";

    jdpkgs.url = "github:jordanisaacs/jdpkgs";
    jdpkgs.inputs.nixpkgs.follows = "nixpkgs";

    # Extra nix/nixos modules
    impermanence.url = "github:nix-community/impermanence";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";
    simple-nixos-mailserver.inputs.utils.follows = "flake-utils";

    flake-utils.url = "github:numtide/flake-utils";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";

    # Secrets
    secrets.url = "git+ssh://git@github.com/jordanisaacs/secrets.git?ref=main";
    secrets.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    homeage.url = "github:jordanisaacs/homeage";
    homeage.inputs.nixpkgs.follows = "nixpkgs";

    microvm-nix = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # Programs
    neovim-flake.url = "github:jordanisaacs/neovim-flake";

    st-flake.url = "github:jordanisaacs/st-flake";
    st-flake.inputs.nixpkgs.follows = "nixpkgs";
    st-flake.inputs.flake-utils.follows = "flake-utils";

    dwm-flake.url = "github:jordanisaacs/dwm-flake";

    dwl-flake.url = "github:jordanisaacs/dwl-flake";
    dwl-flake.inputs.nixpkgs.follows = "nixpkgs";

    efi-power.url = "github:jordanisaacs/efi-power";
    efi-power.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-stable
    , jdpkgs
    , impermanence
    , deploy-rs
    , agenix
    , nixpkgs-wayland
    , secrets
    , home-manager
    , nur
    , neovim-flake
    , efi-power
    , st-flake
    , dwm-flake
    , dwl-flake
    , homeage
    , ...
    } @ inputs:
    let
      inherit (nixpkgs) lib;

      util = import ./lib {
        inherit system nixpkgs pkgs home-manager lib overlays patchedPkgs inputs;
      };

      scripts = import ./scripts {
        inherit pkgs lib;
      };

      inherit
        (import ./overlays {
          inherit
            system
            pkgs
            lib
            nur
            neovim-flake
            st-flake
            dwm-flake
            efi-power
            homeage
            scripts
            jdpkgs
            dwl-flake
            impermanence
            deploy-rs
            agenix
            nixpkgs-wayland
            nixpkgs-stable
            secrets
            ;
        })
        overlays
        ;

      inherit (util) user;
      inherit (util) host;
      inherit (util) utils;

      system = "x86_64-linux";

      # How to patch nixpkgs, from https://github.com/NixOS/nix/issues/3920#issuecomment-681187597
      # remoteNixpkgsPatches = [ ];
      # localNixpkgsPatches = [
      #   # nix-index evaluates all of nixpkgs. Thus, it evaluates a package
      #   # that purposefully throws an error because mesos was removed.
      #   # Patch nixpkgs to remove the override.
      #   ./nixpkgs-patches/mesos.patch
      # ];
      # originPkgs = nixpkgs.legacyPackages.${system};
      patchedPkgs = nixpkgs;
      # patchedPkgs = originPkgs.applyPatches {
      #   name = "nixpkgs-patched";
      #   src = nixpkgs;
      #   patches = map originPkgs.fetchpatch remoteNixpkgsPatches ++ localNixpkgsPatches;
      #   postPatch = ''
      #     patch=$(printf '%s\n' ${builtins.concatStringsSep " "
      #       (map (p: p.sha256) remoteNixpkgsPatches ++ localNixpkgsPatches)} |
      #       sort | sha256sum | cut -c -7)
      #     echo "+patch-$patch" >.version-suffix
      #   '';
      # };
      pkgs = import patchedPkgs {
        inherit system overlays;
        config = {
          permittedInsecurePackages = [
            "electron-9.4.4"
          ];
          allowUnfree = true;
        };
      };

      authorizedKeys = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKIspidvrzy1NFoUXMEs1A2Wpx3E8nxzCKGZfBXyezV mail@jdisaacs.com
      '';

      authorizedKeyFiles = pkgs.writeTextFile {
        name = "authorizedKeys";
        text = authorizedKeys;
      };

      wireguardConf = {
        enable = true;
        interface = "thevoid";
        peers = {
          intothevoid =
            let
              wgsecret = secrets.wireguard.intothevoid;
            in
            {
              wgAddrV4 = "10.55.1.1";
              inherit (wgsecret) publicKey;

              tags = [{ name = "net"; }];
            };

          chairlift =
            let
              wgsecret = secrets.wireguard.chairlift;
            in
            {
              wgAddrV4 = "10.55.0.2";
              interfaceMask = 16;
              listenPort = 51820;

              privateKeyPath = "/etc/wireguard/private_key";
              privateKeyAge = wgsecret.secret.file;
              inherit (wgsecret) publicKey;
              dns = "server";

              tags = [
                {
                  name = "net";
                  ipAddr = "5.161.103.90";
                }
              ];
            };

          framework =
            let
              wgsecret = secrets.wireguard.framework;
            in
            {
              wgAddrV4 = "10.55.1.2";
              interfaceMask = 16;
              listenPort = 51820;

              privateKeyPath = "/etc/wireguard/private_key";
              privateKeyAge = wgsecret.secret.file;
              inherit (wgsecret) publicKey;
              dns = "client";

              tags = [
                {
                  name = "home";
                  ipAddr = "172.26.40.247";
                }
                { name = "net"; }
              ];
            };

          desktop =
            let
              wgsecret = secrets.wireguard.desktop;
            in
            {
              wgAddrV4 = "10.55.0.1";
              interfaceMask = 16;
              listenPort = 51820;
              dns = "client";

              firewall = {
                allowedTCPPorts = [ 8080 ];
              };

              privateKeyPath = "/etc/wireguard/private_key";
              privateKeyAge = wgsecret.secret.file;
              inherit (wgsecret) publicKey;

              tags = [
                {
                  name = "home";
                  ipAddr = "172.26.26.90";
                }
                { name = "net"; }
              ];
            };
        };
      };

      defaultUser = {
        name = "jd";
        groups = [ "wheel" ];
        uid = 1000;
        # Fixes assertion issue: https://github.com/NixOS/nixpkgs/pull/211603
        shell = pkgs.bashInteractive;
      };

      defaultDesktopUser =
        defaultUser
        // {
          groups = defaultUser.groups ++ [ "video" "libvirtd" ];
        };

      defaultServerConfig = {
        core.enable = true;
        boot.type = "bios";
        fs.type = "zfs";
        users.mutableUsers = false;
        ssh = {
          enable = true;
          type = "server";
          authorizedKeys = [ (builtins.toString authorizedKeys) ];
          initrdKeys = [ authorizedKeys ];
        };
        networking = {
          firewall.enable = true;
        };
        impermanence.enable = true;
      };

      gondolaConfig = utils.recursiveMerge [
        defaultServerConfig
        {
          users.rootPassword = secrets.passwords.gondola;
          isQemuGuest = true;
          boot.grubDevice = "/dev/vda";
          kernel.initrdMods = [ "sr_mod" "ata_piix" "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net" ];

          fs.hostId = "fe120267";

          secrets.identityPaths = [ secrets.age.gondola.privateKeyPath ];
          networking = {
            static = {
              enable = true;
              interface = "ens3";
              ipv6.addr = "2001:550:5a00:550b::1/64";
              ipv4.addr = "38.45.64.210/32";
              ipv4.gateway = "38.45.64.1";
            };
          };
          ssh = {
            firewall = "world";
            hostKeyAge = secrets.ssh.host.gondola.secret.file;
          };
        }
      ];

      chairliftConfig = utils.recursiveMerge [
        defaultServerConfig
        {
          users.rootPassword = secrets.passwords.chairlift;
          isQemuGuest = true;
          boot.grubDevice = "/dev/sda";
          kernel.initrd = [ "sd_mod" "sr_mod" "ahci" "xhci_pci" ];
          fs = {
            hostId = "2d360981";
            zfs.swap = {
              swapPartuuid = "52c2b662-0b7b-430c-9a10-068acbe9d15d";
              enable = true;
            };
          };
          secrets.identityPaths = [ secrets.age.chairlift.privateKeyPath ];
          wireguard = wireguardConf;
          networking = {
            static = {
              enable = true;
              interface = "enp1s0";
              ipv6.addr = "2a01:4ff:f0:865b::1/64";
              ipv4 = {
                addr = "5.161.103.90/32";
                gateway = "172.31.1.1";
                onlink = true;
              };
            };
          };
          ssh = {
            firewall = "wg";
            hostKeyAge = secrets.ssh.host.chairlift.secret.file;
          };
          acme.email = secrets.acme.email;
          monitoring.enable = false;
          microbin.enable = true;
          calibre.web.enable = true;
          syncthing = {
            relay.enable = false;
            discovery.enable = false;
          };
          languagetool.enable = false;
          mailserver = with secrets.mailserver; {
            enable = true;
            inherit fqdn sendingFqdn domains;
            loginAccounts =
              builtins.mapAttrs
                # deadnix: skip
                (name: value: {
                  hashedPasswordFile = value.hashedPassword.secret.file;
                  inherit (value) aliases;
                  sendOnly = lib.mkIf (value ? sendOnly) value.sendOnly;
                })
                loginAccounts;
          };
          miniflux = {
            enable = true;
            adminCredsFile = secrets.miniflux.adminCredentials.secret.file;
          };
          taskserver = {
            enable = true;
            address = "10.55.0.2";
            fqdn = "chairlift.wg";
            firewall = "wg";
          };
          ankisyncd = {
            # build is broken
            enable = false;
            address = "10.55.0.2";
            firewall = "wg";
          };
          proxy = {
            enable = true;
            firewall = "wg";
            address = "10.55.0.2";
          };
          unbound = {
            enable = true;
            access = "wg";
            enableWGDomain = true;
          };
        }
      ];

      defaultClientConfig = {
        core = {
          enable = true;
          ccache = true;
        };
        users.users = [ defaultDesktopUser ];
        gnome = {
          enable = true;
          keyring = {
            enable = true;
          };
        };
        connectivity = {
          bluetooth.enable = true;
          sound.enable = true;
          printing.enable = true;
        };
        networking = {
          firewall = {
            enable = true;
            allowKdeconnect = false;
            allowDefaultSyncthing = true;
          };
          wifi.enable = true;
          tailscale.enable = true;
        };
        kernel.watchdog = false;
        graphical = {
          enable = true;
          xorg.enable = false;
          wayland = {
            enable = true;
            waylockPam = true;
          };
          flatpak.enable = true;
        };
        ssh = {
          enable = true;
          type = "client";
        };
        extraContainer.enable = false;
      };

      desktopConfig = utils.recursiveMerge [
        defaultClientConfig
        {
          boot.type = "uefi";
          kernel.initrdMods = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
          kernel.mods = [ "kvm-amd" ];
          fs = {
            type = "zfs-v2";
            hostId = "f5db52d8";
          };

          core.time = "east";
          users.mutableUsers = false;

          desktop.enable = true;
          impermanence.enable = true;
          greetd.enable = true;
          wireguard = wireguardConf;
          waydroid.enable = true;
          secrets.identityPaths = [ secrets.age.desktop.system.privateKeyPath ];
        }
      ];

      laptopConfig = utils.recursiveMerge [
        defaultClientConfig
        {
          boot.type = "uefi";
          fs.type = "encrypted-efi";
          laptop.enable = true;
          secrets.identityPaths = [ "" ];
          networking.interfaces = [ "enp0s31f6" ];
          kernel.initrd = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
          kernel.mods = [ "kvm-intel" ];
        }
      ];

      frameworkConfig = utils.recursiveMerge [
        defaultClientConfig
        {
          boot.type = "uefi";
          fs.type = "encrypted-efi";
          initrd.plymouth = {
            enable = true;
            theme = "hexa_retro";
          };
          kernel = {
            initrdMods = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
            mods = [ "kvm-intel" ];
          };
          laptop.enable = true;
          core.time = null;
          networking.wifi.ipTime = true;
          greetd.enable = true;
          framework = {
            enable = true;
            fprint = {
              enable = true;
            };
          };
          # wireguard = wireguardConf;
          secrets.identityPaths = [ secrets.age.framework.system.privateKeyPath ];
          firefly-iii = {
            enable = true;
            appKeyFile = "/var/lib/firefly-iii/firefly-iii-appkey";
          };
        }
      ];
    in
    {
      installMedia = {
        kde = host.mkISO {
          name = "nixos";
          kernelPackage = pkgs.linuxPackages_latest;
          initrdMods = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "nvme" "usbhid" ];
          kernelMods = [ "kvm-intel" "kvm-amd" ];
          kernelParams = [ ];
          systemConfig = { };
        };
      };

      homeManagerConfigurations = {
        jd = user.mkHMUser {
          userConfig = {
            graphical = {
              theme = "arc-dark";
              applications = {
                enable = true;
                anki.enable = true;
                dolphin.enable = true;
                firefox.enable = true;
                libreoffice.enable = true;
                multimedia.enable = true;
                gaming.enable = true;
                kdeconnect.enable = false;
                gnome-keyring.enable = true;
              };
              wayland = {
                enable = true;
                type = "dwl";
                background.enable = true;
                statusbar.enable = true;
                screenlock.enable = true;
                screen.gamma = {
                  enable = true;
                  loc = "seattle";
                };
              };
              xorg = {
                enable = false;
                type = "dwm";
                screenlock.enable = true;
              };
            };
            applications = {
              enable = true;
              bat.enable = true;
              direnv.enable = true;
              tldr.enable = true;
              syncthing.enable = true;
              neomutt.enable = true;
              neovim.enable = true;
            };
            shell = "bash";
            secrets.identityPaths = [ secrets.age.framework.jd.privateKeyPath ];
            gpg.enable = true;
            git = {
              enable = true;
              allowedSignerFile = builtins.toString authorizedKeyFiles;
            };
            ssh.enable = true;
            weechat.enable = true;
            office365 = {
              enable = false;
              onedriver.enable = true; # pkg currently broken
            };
            wine = {
              enable = false; # wine things currently broken
              office365 = false;
            };
            keybase.enable = false;
            pijul.enable = true;
            kernel.enable = true;
          };
          username = "jd";
        };
      };

      nixosConfigurations = {
        laptop = host.mkHost {
          name = "laptop";
          systemConfig = laptopConfig;
          cpuCores = 4;
          stateVersion = "21.05";
        };

        framework = host.mkHost {
          name = "framework";
          systemConfig = frameworkConfig;
          cpuCores = 8;
          stateVersion = "21.11";
        };

        desktop = host.mkHost {
          name = "desktop";
          systemConfig = desktopConfig;
          cpuCores = 12;
          stateVersion = "21.11";
        };

        chairlift = host.mkHost {
          name = "chairlift";
          systemConfig = chairliftConfig;
          cpuCores = 2;
          stateVersion = "21.11";
        };

        gondola = host.mkHost {
          name = "gondola";
          systemConfig = gondolaConfig;
          cpuCores = 8;
          stateVersion = "21.11";
        };
      };

      deploy.nodes.chairlift = {
        hostname = "10.55.0.2";
        sshOpts = [ "-p" "23" ];
        autoRollback = true;
        magicRollback = true;
        profiles = {
          system = {
            sshUser = "root";
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.chairlift;
          };
        };
      };

      deploy.nodes.gondola = {
        hostname = "38.45.64.210";
        sshOpts = [ "-p" "23" ];
        autoRollback = true;
        magicRollback = true;
        profiles = {
          system = {
            sshUser = "root";
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.gondola;
          };
        };
      };

      checks =
        builtins.mapAttrs
          # deadnix: skip
          (system: deployLib: deployLib.deployChecks self.deploy)
          deploy-rs.lib;
    };
}
