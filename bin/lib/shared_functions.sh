#!/usr/bin/env bash

# returns (as RHS) toplevel path for parent repo, empty if repo is submodule
# return code: 0 if repo is submodule, otherwise 1
function is_submodule() {

    local git_dir parent_git module_name path strip
    # Find the root of this git repo, then check if its parent dir is also a repo
    git_dir="$(git rev-parse --show-toplevel)"
    parent_git="$(cd "$git_dir/.." && git rev-parse --show-toplevel 2> /dev/null)"

    if [[ -n $parent_git ]]; then
        strip=$((${#parent_git} + 1))
        echo $strip
        module_name=${git_dir:$strip}
        # List all the submodule paths for the parent repo
        while read path
        do
            if [[ "$path" != "$module_name" ]]; then continue; fi
            if [[ -d "$parent_git/$path" ]]; then
                echo $parent_git
                return 0;
            fi
        done < <(cd $parent_git && git submodule --quiet foreach 'echo $path' 2> /dev/null)
    fi
    return 1
}


function parse_opt() {
 echo "parse_opt"
}