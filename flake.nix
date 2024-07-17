{
	outputs = { self, nixpkgs, ... }: {
		nixosModules.image-lock = import ./module.nix;
		nixosModule = self.nixosModules.image-lock;

		packages = (nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed) (system: let pkgs = nixpkgs.legacyPackages.${system}; in {
			default = pkgs.writeShellApplication {
				name = "manage-image-lock.sh";
				runtimeInputs = with pkgs; [ jq manifest-tool ];
				text = builtins.readFile ./manage.sh;
			};
		});
	};
}
