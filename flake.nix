{
  description = "NixOS in MicroVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    microvm-4_1.url = "github:astro/microvm.nix?ref=v0.4.1";
    microvm-4_1.inputs.nixpkgs.follows = "nixpkgs";

    microvm-pre-notify_socket.url = "github:astro/microvm.nix?rev=9d3cc92a8e2f0a36c767042b484cc8b8c6f371d3";
    microvm-pre-notify_socket.inputs.nixpkgs.follows = "nixpkgs";

    microvm-post-notify_socket.url = "github:astro/microvm.nix?rev=ea4cab3cc6ad680a3020166fd18d615b1c15d8df";
    # microvm-post-notify_socket.url = "github:astro/microvm.nix?rev=d5283b0c83df3475ca967aa1ca9496d3e387084a";
    # microvm-post-notify_socket.url = "github:astro/microvm.nix?rev=a439229a1af9e0fae3b3b21619c1983901a41bf7";
    microvm-post-notify_socket.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ nixpkgs, disko, ... }:
    let
      lib = nixpkgs.lib;
      pkgs = import nixpkgs { inherit system; };

      system = "x86_64-linux";
      inherit (inputs) microvm;
      # microvm = inputs.microvm-4_1;
      # microvm = inputs.microvm-pre-notify_socket;
      # microvm = inputs.microvm-post-notify_socket;

      hypervisors = [
        # "qemu"
        "cloud-hypervisor"
      ];
      vmConfigs = {
        default = { };
        # noSocket = {
        #   config = {
        #     microvm.socket = null;
        #   };
        # };
        # storeMount = {
        #   config = {
        #     microvm.shares = [
        #       {
        #         tag = "ro-store";
        #         source = "/nix/store";
        #         mountPoint = "/nix/.ro-store";
        #         proto = "virtiofs";
        #       }
        #     ];
        #   };
        # };
      };

      vms = builtins.listToAttrs (
        lib.mapCartesianProduct
          (
            { hypervisor, vmConfig }:
            {
              name = "${hypervisor}-${vmConfig.name}";
              value = lib.recursiveUpdate {
                config = {
                  microvm.hypervisor = hypervisor;
                };
              } vmConfig.value;
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
                host.useNotifySockets = true;
                inherit vms;
              };
            }
            {
              # boot.kernelPackages = pkgs.linuxPackages_latest;
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

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };
}
