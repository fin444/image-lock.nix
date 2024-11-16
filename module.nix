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
		prune = mkEnableOption "";
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
				image = "${data."${value}".finalImageName}:${data."${value}".finalImageTag}";
				imageFile = pkgs.dockerTools.pullImage data."${value}";
			}
		) cfg.containers;

		# pruning
		systemd.services =
			let backend = config.virtualisation.oci-containers.backend;
		in lib.mkIf cfg.prune (lib.attrsets.mapAttrs' (name: value:
			lib.attrsets.nameValuePair "${backend}-${name}-prune" (let
				digest = if (lib.attrsets.hasAttr "digest" data."${value}") then data."${value}".digest else data."${value}".imageDigest;
			in {
				description = "Prune old images of ${value}";
				requiredBy = [ "${backend}-${name}.service" ];
				before = [ "${backend}-${name}.service" ];
				path = config.systemd.services."${backend}-${name}".path; # get ${backend} in the path
				serviceConfig = {
					ExecStart = "${pkgs.writeShellApplication {
						name = "${backend}-${name}-prune";
						runtimeInputs = with pkgs; [ gawk ];
						text = ''
							images="$(${backend} images --digests | { grep '^${value} ' || true; } | { grep -v '${digest}' || true; } | awk '{print $4}')"
							if [[ "$images" != "" ]]; then
								# shellcheck disable=SC2086
								${backend} rmi $images
							fi
						'';
					}}/bin/${backend}-${name}-prune";
					Type = "oneshot";
				};
			})
		) cfg.containers);
	};
}
