{ config, lib, pkgs, ... }: {
	options.environment.image-lock = with lib; {
		lockFile = mkOption {
			type = types.path;
		};
		containers = mkOption {
			type = types.submodule {
				freeformType = types.attrsOf types.str;
			};
		};
	};

	config = let
		data = (builtins.fromJSON (builtins.readFile cfg.lockFile));
		cfg = config.environment.image-lock;
	in {
		# if there are no containers defined, it'll throw an error without this
		environment.image-lock.containers = {};

		# define images for all containers
		virtualisation.oci-containers.containers = builtins.mapAttrs (name: value:
			if (lib.attrsets.hasAttr "digest" data."${value}") then {
				image = "${value}@${data."${value}".digest}";
			} else {
				image = data."${value}".finalImageName;
				imageFile = pkgs.dockerTools.pullImage data."${value}";
			}
		) cfg.containers;
	};
}
