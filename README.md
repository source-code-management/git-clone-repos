git-clone-repos
===========

Bash script that clone all repos, placing them inside group folders.

This file provide an istructions for all the variables inside the file ".git_parameters".

All the variables must be defined.

If we use GitLab, the only variables that can be left empty are:

> user="<your_username>"

> organization="<your_organization>"

```bash
# Variables Explanation
${user}           --> 'user with whom to authenticate to github' 
${organization}   --> 'if using github organizations, it must be defined to see repositories'
${token}          --> 'token generate from GitHub/GitLab for authentication'
${github_api}     --> 'there are two URLs, one for the repos list of the user and another for the repos list of the organization'
${gitlab_api}     --> 'this is for GitLab repos list'
${repo_year}      --> 'use this variable to filter the results by date. the date format is YYYY, eg. 2022. if you don`t want any filter you can put "date" as value'
${repo_month}     --> 'use this variable to filter the results by date. the date format is MM, eg. 07. if you don`t want any filter you can leave it blank'
${repo_date}      --> 'this variable combine the ${repo_year} and ${repo_month} to filter the results, starting from the date entered up to the most recent. if you want filter a specific date, you can insert it in the ${repo_year} variable, eg. repo_year="2022-07" or repo_year="2022-07-28"'
${excluded_group} --> 'use it to exclude one organization/group from the list. if you don`t want any filter you must put a random word as value (eg. "pippo")'
${base_dir}       --> 'specify where you want all the cloned repos'
${branch}         --> 'all these 3 variables must be defined. if you don`t know or don`t have a branch priority, you can put a random word as a value to be able to clone the default branch (eg. "pippo")'
```
