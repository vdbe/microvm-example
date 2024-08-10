{
  description = "NixOS in MicroVMs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.microvm.url = "github:astro/microvm.nix";
  inputs.microvm.inputs.nixpkgs.follows = "nixpkgs";

  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      disko,
    }:
    let
      lib = nixpkgs.lib;

      system = "x86_64-linux";
      hypervisors = [
        "qemu"
        "cloud-hypervisor"
      ];
      vmConfigs = {
        default = { };
        noSocket = {
          microvm.socket = null;
        };
        storeMount = {
          microvm.shares = [
            {
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              proto = "virtiofs";
            }
          ];
        };
      };

      vms = builtins.listToAttrs (
        lib.mapCartesianProduct
          (
            { hypervisor, vmConfig }:
            {
              name = "${hypervisor}-${vmConfig.name}";
              value = {
                config = lib.recursiveUpdate { microvm.hypervisor = hypervisor; } vmConfig.value;
              };
            }
          )
          {
            hypervisor = hypervisors;
            vmConfig = lib.mapAttrsToList lib.nameValuePair vmConfigs;
          }
      );
    in
    {
      inherit vms;
      nixosConfigurations = {
        microvm-host = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.host
            disko.nixosModules.disko
            {
              microvm = {
                inherit vms;
              };
            }
            {
              networking.hostName = "microvm-host";
              users.mutableUsers = false;
              users.users.root.password = "password";
              boot.loader.systemd-boot.enable = true;
              services.openssh = {
                enable = true;
                settings = {
                  PasswordAuthentication = true;
                  PermitRootLogin = "yes";
                };
              };
              disko.devices = {
                disk = {
                  main = {
                    device = "/dev/sda";
                    type = "disk";
                    content = {
                      type = "gpt";
                      partitions = {
                        ESP = {
                          type = "EF00";
                          size = "500M";
                          content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                          };
                        };
                        root = {
                          size = "100%";
                          content = {
                            type = "filesystem";
                            format = "ext4";
                            mountpoint = "/";
                          };
                        };
                      };
                    };
                  };
                };
              };
            }
          ];
        };
      };
    };
}
