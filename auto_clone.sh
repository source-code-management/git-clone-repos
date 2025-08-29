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
##  2024-05-14		Enrico C.					Implement subfolder logic to split repos by pourpose.
##
###################################################################################################################


## Color Table.
Green='\033[0;32m'        # Green
Cyan='\033[0;36m'         # Cyan
# Reset
NC='\033[0m'              # Color Text Reset


####################################################################################################################


## Variables.
source "../.git_parameters"
source "../.github_parameters"
# source "../.gitlab_parameters"

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
# curl=$(curl ${github_api_string} | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|updated' | grep -A 1 "${repo_date}" | grep 'git@' | awk -F \" '{print $4}' | grep -v "${excluded_group}" | grep "$1/" | sort);

# GitHub multiple organizations
if [[ -z $organizations ]]; then
    repositories=$(curl ${github_api_string} | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|updated' | grep -A 1 "${repo_date}" | grep 'git@' | awk -F \" '{print $4}' | grep -v "${excluded_group}" | grep "$1/" | sort);
else
    for org in $organizations;
    do
        github_api="https://api.github.com/orgs/${org}/repos"
        github_api_string="-u ${user}:${token} ${github_api}?per_page=100 ${github_api}?per_page=100&page=2"
        repositories+=' '$(curl ${github_api_string} | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep 'ssh\|updated' | grep -A 1 "${repo_date}" | grep 'git@' | awk -F \" '{print $4}' | grep -v "${excluded_group}" | grep "$1/" | sort);
    done
fi

####################################################################################################################


## Function.
# Set the function that will clone all repositories.
git-clone-repo-in-group-folder () {
    # Set the "if" the pick up the current repo and it's branch, delete the repo and reclone it.
    if [[  -d "$organization/$repo_group/$repo_name" ]]; then
        for branch_name in $(git -C "$organization/$repo_group/$repo_name" rev-parse --abbrev-ref HEAD); do
            echo -e "--- Checking and upgrading the ${Cyan}$organization/$repo_group/$repo_name${NC} directory ---";
            rm -rf "$organization/$repo_group/$repo_name";
            git clone --branch "$branch_name" "$repository" "$organization/$repo_group/$repo_name" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
            echo -e "switched ${Cyan}$project${NC} to the branch: ${Cyan}$branch_name${NC}";
        done
    else
    # Set the "for" that will clone all the new or missing repositories.
        for repo in $repository; do
            echo "";
            echo -e "--- Cloning the new ${Cyan}$organization/$repo_group/$repo_name${NC} ---";
            git init fetching &>/dev/null ;
            git -C fetching fetch --tags --force --progress --depth=1 -- "$repository" +refs/heads/*:refs/remotes/origin/* &>/dev/null;
            mkdir -p "$organization";
            touch $organization/.team_folder && chmod 111 $organization/.team_folder;
            branch_list="$(git -C fetching/ rev-parse --abbrev-ref $(git -C fetching/ branch -r) | awk -F "/" '{$1=""; print $0}')"
            if [[ $( (echo $branch_list) | tr ' ' '\n' | grep -E "^${branch1}$") == "${branch1}" ]]; then
                git clone "$repository" "$organization/$repo_group/$repo_name" --branch "${branch1}" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$project${NC} to the branch: ${Cyan}${branch1}${NC}";
            elif [[ $( (echo $branch_list) | tr ' ' '\n' | grep -E "^${branch2}$") == "${branch2}" ]]; then
                git clone "$repository" "$organization/$repo_group/$repo_name" --branch "${branch2}" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$project${NC} to the branch: ${Cyan}${branch2}${NC}";
            else
                git clone "$repository" "$organization/$repo_group/$repo_name" 2>&1 | grep --color=auto -vE "^fatal: destination path .+? already exists and is not an empty directory.$" || true;
                echo -e "switched ${Cyan}$project${NC} to the default branch";
            fi;
            rm -rf fetching ;
        done ;
    fi;
    echo "";
}


####################################################################################################################

## Script.
# This "for loop" sync all the repo modified in according to the $repo_date variable.
for repository in $repositories
do
    repo_without_suffix=${repository%.git};
    repo_without_suffix_and_base_url=${repo_without_suffix#*:};
    organization=${repo_without_suffix_and_base_url%%\/*};
    project=${repo_without_suffix_and_base_url##*\/};
    repo_group=${project%%_*};
    repo_name=${project#*_};
    
    echo ""
    echo -e " ${Green}Ispecting the $organization/$repo_group group${NC} "
    echo ""
    cd $base_dir/
    git-clone-repo-in-group-folder
done
