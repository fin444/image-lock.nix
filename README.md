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
nix run --no-write-lock-file github:fin444/image-lock.nix add postgres ghcr.io/paperless-ngx/paperless-ngx

# update images
nix run --no-write-lock-file github:fin444/image-lock.nix update

# see all commands
nix run --no-write-lock-file github:fin444/image-lock.nix help
```

Unfortunately, `--no-write-lock-file` is necessary to allow the flake to follow your local nixpkgs.

### Configuration

```nix
environment.image-lock = {
  lockFile = ./images.lock;
  containers = {
    paperless = "pghcr.io/paperless-ngx/paperless-ngx";
    postgresql = "postgres";
  };
};

virtualisation.oci-containers = {
  paperless = {
    # more container config
  };
  postgresql = {
    # more container config
  };
};
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

### Prefetching

There is also the option to include images in the nix store instead of pulling them from the repository at runtime.

To do this, run the add command with `--store`, and the image(s) will be set to this method.

Drawbacks:
- Adding/updating images will take longer, and require enough memory to hold the image (as it is being hashed for the store)
- Images will take up space twice: once in the store, and once in `/var/lib/docker`
- When no longer needed, images need to be garbage collected both in the store, and from Docker
