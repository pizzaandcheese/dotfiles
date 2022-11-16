{
  description = "System Config";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nur = {
      url = "github:nix-community/NUR";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm-nix = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
    };

    homeage = {
      url = "github:jordanisaacs/homeage";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jdpkgs = {
      url = "github:jordanisaacs/jdpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "git+ssh://git@github.com/jordanisaacs/secrets.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-flake.url = "github:jordanisaacs/neovim-flake";

    st-flake = {
      url = "github:jordanisaacs/st-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    dwm-flake.url = "github:jordanisaacs/dwm-flake";

    dwl-flake.url = "github:jordanisaacs/dwl-flake/updates";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-emoji,
    jdpkgs,
    impermanence,
    deploy-rs,
    agenix,
    microvm-nix,
    nixpkgs-wayland,
    secrets,
    home-manager,
    nur,
    neovim-flake,
    simple-nixos-mailserver,
    st-flake,
    dwm-flake,
    dwl-flake,
    homeage,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    util = import ./lib {
      inherit system nixpkgs pkgs home-manager lib overlays inputs patchedPkgs;
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
          homeage
          scripts
          jdpkgs
          dwl-flake
          impermanence
          deploy-rs
          agenix
          nixpkgs-wayland
          ;
      })
      overlays
      ;

    inherit (util) user;
    inherit (util) host;
    inherit (util) utils;

    system = "x86_64-linux";

    # How to patch nixpkgs, from https://github.com/NixOS/nix/issues/3920#issuecomment-681187597
    remoteNixpkgsPatches = [];
    localNixpkgsPatches = [
      # nix-index evaluates all of nixpkgs. Thus, it evaluates a package
      # that purposefully throws an error because mesos was removed.
      # Patch nixpkgs to remove the override.
      ./nixpkgs-patches/mesos.patch
    ];
    originPkgs = nixpkgs.legacyPackages.${system};
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
        intothevoid = let
          wgsecret = secrets.wireguard.intothevoid;
        in {
          wgAddrV4 = "10.55.1.1";
          publicKey = wgsecret.publicKey;

          tags = [{name = "net";}];
        };

        chairlift = let
          wgsecret = secrets.wireguard.chairlift;
        in {
          wgAddrV4 = "10.55.0.2";
          interfaceMask = 16;
          listenPort = 51820;

          privateKeyPath = "/etc/wireguard/private_key";
          privateKeyAge = wgsecret.secret.file;
          publicKey = wgsecret.publicKey;
          dns = "server";

          tags = [
            {
              name = "net";
              ipAddr = "5.161.103.90";
            }
          ];
        };

        framework = let
          wgsecret = secrets.wireguard.framework;
        in {
          wgAddrV4 = "10.55.1.2";
          interfaceMask = 16;
          listenPort = 51820;

          privateKeyPath = "/etc/wireguard/private_key";
          privateKeyAge = wgsecret.secret.file;
          publicKey = wgsecret.publicKey;
          dns = "client";

          tags = [
            {
              name = "home";
              ipAddr = "172.26.40.247";
            }
            {name = "net";}
          ];
        };

        desktop = let
          wgsecret = secrets.wireguard.desktop;
        in {
          wgAddrV4 = "10.55.0.1";
          interfaceMask = 16;
          listenPort = 51820;
          dns = "client";

          firewall = {
            allowedTCPPorts = [8080];
          };

          privateKeyPath = "/etc/wireguard/private_key";
          privateKeyAge = wgsecret.secret.file;
          publicKey = wgsecret.publicKey;

          tags = [
            {
              name = "home";
              ipAddr = "172.26.26.90";
            }
            {name = "net";}
          ];
        };
      };
    };

    defaultServerConfig = {
      core.enable = true;
      boot = {
        type = "zfs";
        hostId = "2d360981";
        swapPartuuid = "52c2b662-0b7b-430c-9a10-068acbe9d15d";
      };
      ssh = {
        enable = true;
        type = "server";
        authorizedKeys = [(builtins.toString authorizedKeys)];
        initrdKeys = [authorizedKeys];
      };
      networking = {
        firewall.enable = true;
      };
      impermanence.enable = true;
    };

    chairliftConfig = utils.recursiveMerge [
      defaultServerConfig
      {
        isQemuGuest = true;
        wireguard = wireguardConf;
        ssh.firewall = "wg";
        secrets.identityPaths = [secrets.age.system.chairlift.privateKeyPath];
        ssh.hostKeyAge = secrets.ssh.host.chairlift.secret.file;
        networking.interfaces = ["enp1s0"];
        miniflux = {
          enable = true;
          adminCredsFile = secrets.miniflux.adminCredentials.secret.file;
        };
        acme.email = secrets.acme.email;
        mailserver = with secrets.mailserver; {
          enable = true;
          inherit fqdn sendingFqdn domains;
          loginAccounts =
            builtins.mapAttrs (name: value: {
              hashedPasswordFile = value.hashedPassword.secret.file;
              aliases = value.aliases;
              sendOnly = lib.mkIf (value ? sendOnly) value.sendOnly;
            })
            loginAccounts;
        };
        taskserver = {
          enable = true;
          address = "10.55.0.2";
          fqdn = "chairlift.wg";
          firewall = "wg";
        };
        ankisyncd = {
          enable = true;
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
      core.enable = true;
      boot.type = "encrypted-efi";
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
        };
        networkmanager.enable = true;
      };
      graphical = {
        enable = true;
        xorg.enable = false;
        wayland = {
          enable = true;
          swaylockPam = true;
        };
      };
      ssh = {
        enable = true;
        type = "client";
      };
      extraContainer.enable = true;
    };

    desktopConfig = utils.recursiveMerge [
      defaultClientConfig
      {
        desktop.enable = true;
        greetd.enable = true;
        networking.interfaces = ["enp6s0" "wlp5s0"];
        wireguard = wireguardConf;
        secrets.identityPaths = [secrets.age.system.desktop.privateKeyPath];
        waydroid.enable = true;
      }
    ];

    laptopConfig = utils.recursiveMerge [
      defaultClientConfig
      {
        laptop.enable = true;
        secrets.identityPaths = [""];
        networking.interfaces = ["enp0s31f6" "wlp2s0"];
      }
    ];

    frameworkConfig = utils.recursiveMerge [
      defaultClientConfig
      {
        networking.interfaces = ["wlp170s0"];
        laptop.enable = true;
        core.time = "east";
        greetd.enable = true;
        framework = {
          enable = true;
          fprint = {
            enable = true;
          };
        };
        wireguard = wireguardConf;
        secrets.identityPaths = [secrets.age.system.framework.privateKeyPath];
        windows.enable = true;
      }
    ];

    defaultUser = {
      name = "jd";
      groups = ["wheel"];
      uid = 1000;
      shell = pkgs.zsh;
    };

    defaultUsers = [defaultUser];

    defaultDesktopUser =
      defaultUser
      // {
        groups = defaultUser.groups ++ ["networkmanager" "video" "libvirtd"];
      };
  in {
    installMedia = {
      kde = host.mkISO {
        name = "nixos";
        kernelPackage = pkgs.linuxPackages_latest;
        initrdMods = ["xhci_pci" "ahci" "usb_storage" "sd_mod" "nvme" "usbhid"];
        kernelMods = ["kvm-intel" "kvm-amd"];
        kernelParams = [];
        systemConfig = {};
      };
    };

    homeManagerConfigurations = {
      jd = user.mkHMUser {
        userConfig = {
          graphical = {
            theme = "arc-dark";
            applications = {
              enable = true;
              firefox.enable = true;
              libreoffice.enable = true;
              anki = {
                enable = true;
                sync = true;
              };
              kdeconnect.enable = false;
            };
            wayland = {
              enable = true;
              type = "sway";
              background.enable = true;
              statusbar.enable = true;
              screenlock.enable = true;
            };
            xorg = {
              enable = false;
              type = "dwm";
              screenlock.enable = true;
            };
          };
          applications = {
            enable = true;
            direnv.enable = true;
            taskwarrior = {
              enable = true;
              server = {
                enable = true;
                key = secrets.taskwarrior.client.key.secret.file;
                ca = secrets.taskwarrior.client.ca.secret.file;
                cert = secrets.taskwarrior.client.cert.secret.file;
                credentials = secrets.taskwarrior.credentials;
              };
            };
          };
          secrets.identityPaths = [secrets.age.user.jd.privateKeyPath];
          gpg.enable = true;
          git = {
            enable = true;
            allowedSignerFile = builtins.toString authorizedKeyFiles;
          };
          zsh.enable = true;
          ssh.enable = true;
          weechat.enable = true;
          office365 = {
            enable = true;
            onedriver.enable = true; # pkg currently broken
          };
          wine = {
            enable = false; # wine things currently broken
            office365 = false;
          };
          keybase.enable = false;
          pijul.enable = true;
        };
        username = "jd";
      };
    };

    nixosConfigurations = {
      laptop = host.mkHost {
        name = "laptop";
        kernelPackage = pkgs.linuxPackages;
        initrdMods = ["xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
        kernelMods = ["kvm-intel"];
        kernelParams = [];
        kernelPatches = [];
        systemConfig = laptopConfig;
        users = defaultUsers;
        cpuCores = 4;
        stateVersion = "21.05";
      };

      framework = host.mkHost {
        name = "framework";
        kernelPackage = pkgs.linuxPackages_latest;
        initrdMods = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
        kernelMods = ["kvm-intel"];
        kernelParams = [];
        kernelPatches = [];
        systemConfig = frameworkConfig;
        users = [defaultDesktopUser];
        cpuCores = 8;
        stateVersion = "21.11";
      };

      desktop = host.mkHost {
        name = "desktop";
        kernelPackage = pkgs.linuxPackages_latest;
        initrdMods = ["nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"];
        kernelMods = ["kvm-amd"];
        kernelParams = [];
        kernelPatches = [];
        systemConfig = desktopConfig;
        users = [defaultDesktopUser];
        cpuCores = 12;
        stateVersion = "21.11";
      };

      chairlift = host.mkHost {
        name = "chairlift";
        initrdMods = ["sd_mod" "sr_mod" "ahci" "xhci_pci"];
        kernelMods = [];
        # TODO: Switch to 5.19 when zfs gains support
        kernelPackage = pkgs.linuxPackages_5_15;
        kernelParams = ["nohibernate"];
        kernelPatches = [];
        systemConfig = chairliftConfig;
        users = [defaultUser];
        cpuCores = 2;
        stateVersion = "21.11";
      };
    };

    deploy.nodes.chairlift = {
      hostname = "10.55.0.2";
      sshOpts = ["-p" "23"];
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

    checks =
      builtins.mapAttrs
      (system: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;
  };
}
