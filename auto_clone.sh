#!/bin/bash

## Color Table
# Reset
NC='\033[0m'              # Color Text Reset
# Regular Colors
Green='\033[0;32m'        # Green
Cyan='\033[0;36m'         # Cyan


## Variables
source ".git_parameters"


## Take repos list
curl=$(curl --noproxy '*' "${gitlab_api_string}" "${gitlab_api_string}&page=2" | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|last' | grep -B 1 ${repo_date} | grep 'git@' | awk -F \" '{print $4}' | grep -vE "${excluded_group}" | grep "$1/" | sort);


## Function
# Set the function that will clone all repositories
git-clone-repo-in-group-folder () {
    # Set the "if" the pick up the current repo and it's branch, delete the repo and reclone it 
    if [[  -d "$repo_group/$repo_name" ]]; then
        for branch_name in $(git -C "$repo_group/$repo_name" rev-parse --abbrev-ref HEAD); do
            echo -e "--- Checking and upgrading the ${Cyan}$repo_group/$repo_name${NC} directory ---";
            rm -rf "$repo_group/$repo_name";
            git clone --branch "$branch_name" "$repos" "$repo_group/$repo_name" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
            echo -e "switched ${Cyan}$repo_name${NC} to the branch: ${Cyan}$branch_name${NC}";
        done
    else
    # Set the "for" that will clone all the new or missing repositories
        for r in $repo_name; do
            echo "";
            echo -e "--- Cloning the new ${Cyan}$repo_group/$repo_name${NC} ---";
            git init fetching &>/dev/null ;
            git -C fetching fetch --tags --force --progress --depth=1 -- "$repos" +refs/heads/*:refs/remotes/origin/* &>/dev/null;
            mkdir -p "$repo_group";
            branch_list="$(git -C fetching/ rev-parse --abbrev-ref $(git -C fetching/ branch -r) | awk -F "/" '{$1=""; print $0}')"
            if [[ $( (echo $branch_list) | tr ' ' '\n' | grep -E "^${branch1}$") == "${branch1}" ]]; then
                git clone "$repos" "$repo_group/$repo_name" --branch "${branch1}" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$repo_name${NC} to the branch: ${Cyan}${branch1}${NC}";
            elif [[ $( (echo $branch_list) | tr ' ' '\n' | grep -E "^${branch2}$") == "${branch2}" ]]; then
                git clone "$repos" "$repo_group/$repo_name" --branch "${branch2}" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$repo_name${NC} to the branch: ${Cyan}${branch2}${NC}";
            elif [[ $( (echo $branch_list) | tr ' ' '\n' | grep -E "^${branch3}$") == "${branch3}" ]]; then
                git clone "$repos" "$repo_group/$repo_name" --branch "${branch3}" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$repo_name${NC} to the branch: ${Cyan}${branch3}${NC}";
            else
                git clone "$repos" "$repo_group/$repo_name" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$repo_name${NC} to the default branch";
            fi;
            rm -rf fetching ;
        done ;
    fi;
    echo "";
}


## This "for loop" sync all the repo modified in according to the $repo_date variable
for repos in $curl
do
    without_suffix=${repos%.git};
    without_suffix_and_base_url=${without_suffix#*:};
    repo_group=${without_suffix_and_base_url%%\/*};
    repo_name=${without_suffix_and_base_url##*\/};
    
    echo ""
    echo -e " ${Green}Ispecting the $repo_group group${NC} "
    echo ""
    cd $base_dir/
    git-clone-repo-in-group-folder
done
