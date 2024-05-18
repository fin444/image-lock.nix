function help() {
	cat << EOM

Usage: nix run --no-write-lock-file github:fin444/image-lock.nix COMMAND [ARGUMENTS]

Commands:
  help      Show usage information.
  update    If no arguments given, update all images. Otherwise, update all images given in arguments.
  add       Add all images given in arguments, and update them to the latest version.
  rm        Remove all images given in arguments.
EOM
	exit
}

function isInLock() {
	[[ $(echo "$working" | jq ".\"$image\"") != "null" ]]
}

function update() {
	local digest
	digest=$(docker manifest inspect "$1" | jq -r '.manifests.[0].digest')
	if [[ $(echo "$working" | jq -r ".\"$1\".digest") != "$digest" ]]; then
		echo "$1 updated to $digest"
		working=$(echo "$working" | jq ".\"$1\".digest = \"$digest\"")
		changed=true
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
		for image in "$@"; do
			if isInLock "$image"; then
				echo "$image is already in images.lock"
			else
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
