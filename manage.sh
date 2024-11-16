set -eo pipefail

function help() {
	cat << EOM

Usage: nix run --no-write-lock-file github:fin444/image-lock.nix COMMAND [ARGUMENTS]

Commands:
  help      Show usage information.
  update    If no arguments given, update all images. Otherwise, update all images given in arguments.
  add       Add all images given in arguments, and update them to the latest version.
              If you include a tag, it will always pull the latest image with that tag.
              Use --store to add the image to the nix store instead of having it pulled at runtime.
  rm        Remove all images given in arguments.
EOM
	exit
}

function isInLock() {
	[[ $(echo "$working" | jq ".\"$image\"") != "null" ]]
}

function update() {
	local tag
	tag=$(echo "$working" | jq -r ".\"$1\".finalImageTag")
	local digest
	digest=$(manifest-tool inspect --raw "$1:$tag" | jq -r '.digest')
	if [[ $(echo "$working" | jq -r ".\"$1\".imageDigest") = "null" ]]; then
		if [[ $(echo "$working" | jq -r ".\"$1\".digest") != "$digest" ]]; then
			working=$(echo "$working" | jq ".\"$1\".digest = \"$digest\"")
			echo "$1 updated to $digest"
			changed=true
		fi
	else
		if [[ $(echo "$working" | jq -r ".\"$1\".imageDigest") != "$digest" ]]; then
			local prefetch
			echo "Prefetching $1, this may take a minute..."
			prefetch=$(nix-prefetch-docker "$1" "$tag" --json --quiet)
			working=$(echo "$working" | jq ".\"$1\" = $prefetch")
			echo "$1 updated to $digest"
			changed=true
		fi
	fi
}

if [[ -f images.lock ]]; then
	working=$(cat images.lock)
else
	working="{}"
fi

changed=false

if [[ "$#" = "0" ]]; then
	help
fi

case "$1" in
	"update")
		if [[ "$#" = "1" ]]; then
			for image in $(echo "$working" | jq -r 'keys.[]'); do
				update "$image"
			done
		else
			shift
			for image in "$@"; do
				if isInLock "$image"; then
					update "$image"
				else
					echo "$image not in images.lock"
				fi
			done
		fi
	;;
	"add")
		shift
		# check whether to place images into store
		store=false
		for arg in "$@"; do
			if [[ "$arg" = "--store" ]]; then
				store=true
			fi
		done
		# loop images
		for image in "$@"; do
			# separate tag and image
			tag=""
			if echo "$image" | grep -q ':'; then
				# shellcheck disable=SC2001
				tag=$(echo "$image" | sed 's/.*://')
				# shellcheck disable=SC2001
				image=$(echo "$image" | sed 's/:.*//')
			fi
			# add image
			if isInLock "$image"; then
				echo "$image is already in images.lock"
			elif [[ "${image::1}" != "-" ]]; then
				# set up prefetch
				if [[ $store = true ]]; then
					working=$(echo "$working" | jq ".\"$image\".imageDigest = \"\"")
				fi
				# set up tag
				if [[ "$tag" != "" ]]; then
					working=$(echo "$working" | jq ".\"$image\".finalImageTag = \"$tag\"")
				else
					working=$(echo "$working" | jq ".\"$image\".finalImageTag = \"latest\"")
				fi
				# fetch info
				update "$image"
			fi
		done
	;;
	"rm")
		shift
		for image in "$@"; do
			if isInLock "$image"; then
				echo "removed $image"
				working=$(echo "$working" | jq "del(.\"$image\")")
				changed=true
			else
				echo "$image is not in images.lock"
			fi
		done
	;;
	*)
		help
	;;
esac

if [[ $changed = true ]]; then
	echo "writing to images.lock"
	echo "$working" > images.lock
else
	echo "no changes"
fi
