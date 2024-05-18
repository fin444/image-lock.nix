# image-lock.nix

A Nix flake to simplify updating Docker containers.

Updating your whole setup is as easy as:

```
nix flake update
nix run --no-write-lock-file github:fin444/image-lock.nix update
nixos-rebuild switch
```

## Usage

### CLI

All data is stored in `images.lock` in your working directory.

```
# add new images
nix run --no-write-lock-file github:fin444/image-lock.nix add postgres pghcr.io/paperless-ngx/paperless-ngx

# update images
nix run --no-write-lock-file github:fin444/image-lock.nix update

# see all commands
nix run --no-write-lock-file github:fin444/image-lock.nix help
```

Unfortunately, `--no-write-lock-file` is necessary to allow the flake to follow your local nixpkgs.

### Use in Configuration

```nix
environment.image-lock.lockFile = ./images.lock;

virtualisation.oci-containers.paperless.image =
  config.environment.image-lock.images."pghcr.io/paperless-ngx/paperless-ngx";
```

### Flake Input

```nix
{
  inputs.image-lock = {
    url = "github:fin444/image-lock.nix update";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, image-lock, ... }@inputs: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        image-lock.nixosModules.image-lock
      ];
    };
  };
}
```
