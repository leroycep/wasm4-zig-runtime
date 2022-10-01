{
  description = "Mach is a game engine & graphics toolkit for the future.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, zig-overlay, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;
    in {
      devShell.x86_64-linux = pkgs.mkShell {
        packages = [
          zig-overlay.packages.x86_64-linux.master
          pkgs.xorg.libX11
          pkgs.libxkbcommon
          pkgs.libGL
          pkgs.wayland
          pkgs.pkg-config
        ];
        LD_LIBRARY_PATH = "${lib.makeLibraryPath [
          pkgs.libGL
          pkgs.vulkan-loader
          pkgs.wayland
          pkgs.libxkbcommon
        ]}";
      };
    };
}
