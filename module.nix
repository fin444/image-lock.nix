{ config, lib, pkgs, ... }: {
	options.environment.image-lock = with lib; {
		lockFile = mkOption {
			type = types.path;
		};
		images = mkOption {
			type = types.submodule {
				freeformType = types.attrsOf types.str;
			};
		};
	};

	config.environment.image-lock.images = builtins.mapAttrs
		(name: value: "${name}@${value.digest}")
		(builtins.fromJSON (builtins.readFile config.environment.image-lock.lockFile));
}
