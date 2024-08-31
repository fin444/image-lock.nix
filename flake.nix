{
	outputs = { self, nixpkgs, ... }: {
		nixosModules.image-lock = import ./module.nix;
		nixosModule = self.nixosModules.image-lock;

		packages = (nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed) (system: let pkgs = nixpkgs.legacyPackages.${system}; in {
			default = pkgs.writeShellApplication {
				name = "image-lock";
				runtimeInputs = with pkgs; [
					jq
					manifest-tool
					nix-prefetch-docker
				];
				text = builtins.readFile ./manage.sh;
			};
		});
	};
}
