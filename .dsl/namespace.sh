
namespace() {
    local name="$1"

    case "$name" in
        data|etc|exe|repo|log|net|svc|cron)
            create_dir "/$name"
            ;;
        *)
            error "Unknown namespace: $name"
            return 1
            ;;
    esac
}
