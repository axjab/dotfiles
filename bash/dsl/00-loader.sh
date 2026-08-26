# =============================================================================
# Bash DSL — loader
# =============================================================================

__bashrc_dsl_dir=$HOME/.bash/dsl

if [[ -d $__bashrc_dsl_dir ]]; then
    for __bashrc_dsl_file in "$__bashrc_dsl_dir"/*.sh; do
        [[ -f $__bashrc_dsl_file ]] || continue
        [[ $__bashrc_dsl_file == "$__bashrc_dsl_dir/00-loader.sh" ]] && continue

        source "$__bashrc_dsl_file" || return
    done
fi

unset __bashrc_dsl_dir __bashrc_dsl_file
