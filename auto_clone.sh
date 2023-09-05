#!/bin/bash


###################################################################################################################
##
##  NAME
##  auto_clone.sh
##
##  SUMMARY
##  The purpose of this script is to contact the GitHub/GitLab API, authenticating with a previously created token,
##  to read the list of "organization/repository" on which the user has visibility.
##  In the case of GitLab, "organization/repository" corresponds to "group/project".
##
##  DETAILS
##  This script do a curl to the GitHub/GitLab API web url.
##  The result of the curl is filtered through a series of "sed", "awk" and "grep", returning a list of ssh strings
##  that will be used for cloning the various repositories.
##  In this curl stage, three parameters can be passed:
##    ${repo_date} -> filters all repos of a specific date YYYY-MM-DD (eg. all repo updated in 2022).
##    ${excluded_group} -> excludes a specific "organization" (or "group" for GitLab) from the list that will be cloned.
##    $1 -> passed when the script was launched (eg "auto_clone.sh my_org") allows you to clone only the repositories belonging to the chosen organization.
##  Once the list to be cloned has been obtained, the script takes the name of the various organizations (or groups) and the various repositories,
##  contained in the ssh string, creates folders that reflect the same path tree, starting from a directory decided by the variable ${base_dir}.
##  If the repository is not present at the chosen path, it will be cloned on a specific branch taken from a decreasing priority list,
##  in case there is no preferred branch lis, the repository will be cloned on the default branch.
##  If, on the other hand, the repo is present at the chosen path, the script will take the name of the current branch,
##  delete the synchronized repository and clone the repo on the branch that it was on before
##  (this assumes that the branch also exists remotely and not only locally ).
##  All the clone activity is done using a temporary support directory, called "fetching", which will be deleted at the end of the script.
##
###################################################################################################################
##
##  WORKLOG:
##  2022-04-01		Enrico C.					Initial draft
##  2022-05-01		Enrico C.					Added "if" condition for already sync repos
##  2022-06-01		Enrico C.					Refactoring and introducing variable
##  2022-08-19		Enrico C.					Refactoring $repo_date variable, sync from the given date to the most recent
##  2023-09-05		Enrico C.					Fix on time range for sync, based on $repo_date var.
##
###################################################################################################################


## Color Table.
Green='\033[0;32m'        # Green
Cyan='\033[0;36m'         # Cyan
# Reset
NC='\033[0m'              # Color Text Reset


####################################################################################################################


## Variables.
source ".git_parameters"
# set $repo_date
if [[ -z $repo_month ]]; then
  repo_date="${repo_year}";
elif (( ${repo_month} > 0 )) && (( ${repo_month} < 10 )); then
  last_num=${repo_month: -1};
  repo_date="${repo_year}-0[${last_num}-9]\|${repo_year}-1[0-2]";
elif (( ${repo_month} >= 10 )) && (( ${repo_month} <= 12 )); then
  last_num=${repo_month: -1};
  repo_date="${repo_year}-1[${last_num}-2]|$((1+$repo_year))-01";
else
  repo_date="${repo_year}";
fi


####################################################################################################################


## Take repos list (choose one from the list below and comment the others).
# GitHub
curl=$(curl --noproxy '*' "${github_api_string}" | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|updated' | grep -A 1 "${repo_date}" | grep 'git@' | awk -F \" '{print $4}' | grep -v "${excluded_group}" | grep "$1/" | sort);
# GitLab
# curl=$(curl --noproxy '*' "${gitlab_api_string}" "${gitlab_api_string}&page=2" | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|last' | grep -B 1 "${repo_date}" | grep 'git@' | awk -F \" '{print $4}' | grep -v ${excluded_group}" | grep "$1/" | sort);


####################################################################################################################


## Function.
# Set the function that will clone all repositories.
git-clone-repo-in-group-folder () {
    # Set the "if" the pick up the current repo and it's branch, delete the repo and reclone it.
    if [[  -d "$repo_group/$repo_name" ]]; then
        for branch_name in $(git -C "$repo_group/$repo_name" rev-parse --abbrev-ref HEAD); do
            echo -e "--- Checking and upgrading the ${Cyan}$repo_group/$repo_name${NC} directory ---";
            rm -rf "$repo_group/$repo_name";
            git clone --branch "$branch_name" "$repos" "$repo_group/$repo_name" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
            echo -e "switched ${Cyan}$repo_name${NC} to the branch: ${Cyan}$branch_name${NC}";
        done
    else
    # Set the "for" that will clone all the new or missing repositories.
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


####################################################################################################################

## Script.
# This "for loop" sync all the repo modified in according to the $repo_date variable.
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
