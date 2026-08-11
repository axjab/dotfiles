check_fstab_entry() {
    local source="$1"
    local target="$2"
    local filesystem="$3"
    local options="$4"

    local record="$source $target $filesystem $options 0 0"

	if awk -v s="$source" \
	       -v t="$target" \
	       -v f="$filesystem" \
	       -v o="$options" '
	    /^[[:space:]]*#/ || NF == 0 { next }
	    $1 == s && $2 == t && $3 == f && $4 == o && $5 == 0 && $6 == 0 {
	        found = 1s
	        exit
	    }
	    END { exit !found }
	' /etc/fstab; then
	    # echo "fstab entry exists."
	    return 0
	fi

    error "Missing /etc/fstab entry."
    echo
    echo "Append the following record to /etc/fstab:"
    echo
    echo "$record"
    echo "$record" | $BIN/clip
    echo "[copied to clipboard]" 

    return 1
}
