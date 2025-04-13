{
  description = "nicer-numbers.nvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.lua-language-server
          pkgs.stylua
          pkgs.selene
        ];

        DEV_SHELL_ACTIVE = "nicer-numbers.nvim";
      };
    };
}
