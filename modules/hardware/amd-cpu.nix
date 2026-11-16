{
  flake.modules.nixos.amd-cpu = {
    boot.kernelModules = [ "kvm-amd" ]; # hardware virtualization
    hardware.cpu.amd.updateMicrocode = true;
  };
}
