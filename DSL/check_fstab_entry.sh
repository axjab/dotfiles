check_fstab_entry() {
    local source="$1"
    local target="$2"
    local filesystem="$3"
    local options="$4"

    local record="$source $target $filesystem $options 0 0"

    if grep -qFx "$record" /etc/fstab; then
        echo "fstab entry exists."
        return 0
    fi

    error "Missing /etc/fstab entry."
    echo
    echo "Append the following record to /etc/fstab:"
    echo
    echo "$record"

    return 1
}
