# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/DECRYPTNIXROOT";
    fsType = "ext4";
  };

  boot.initrd.luks.devices = {
    cryptkey = {
      device = "/dev/disk/by-label/NIXKEY";
    };

    cryptroot = {
      device = "/dev/disk/by-label/NIXROOT";
      keyFile = "/dev/mapper/cryptkey";
    };

    cryptswap = {
      device = "/dev/disk/by-label/NIXSWAP";
      keyFile = "/dev/mapper/cryptkey";
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  swapDevices = [
    { device = "/dev/disk/by-label/DECRYPTNIXSWAP"; }
  ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
