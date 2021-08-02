#!/usr/bin/env bash

set -xe

current_hash=$(git log --pretty=format:'%h' --max-count=1)
current_branch=$(git branch --show-current|sed 's#/#_#')

version=""

create_tag() {
    if [[ ${current_branch} == "main" ]]; 
    then
        #git fetch --tags --force
        current_version_at_head=$(git tag --points-at HEAD)
        if [[ -z ${current_version_at_head} ]] || [[ ! "${current_version_at_head}" =~ ^v+ ]];
        then 
            commit_hash=$(git rev-list --tags --topo-order --max-count=1)
            latest_version=$(git describe --tags ${commit_hash})
            if [[ ${latest_version} =~ ^v+ ]];
            then 
                version="v1.0.0"
            else
                read a b c <<< $(echo $latest_version|sed 's/\./ /g')
                version="$a.$b.$((c+1))"
            fi;
	    echo "version: ${version}"
        else
            echo nothing to build
        fi;
    fi;
}

create_tag

if [[ ! -z ${version} ]];
then
  source project.properties
  image_tag="${owner}/${project}:${version}"
  echo building ${image_tag}
  docker build --no-cache -t ${image_tag} .
  docker push ${image_tag}
  now=$(date '+%Y-%m-%dT%H:%M:%S%z')
  git tag -m "{\"author\":\"ci\", \"branch\":\"$current_branch\", \"hash\": \"${current_hash}\", \"version\":\"${version}\",  \"build_date\":\"${now}\"}"  ${version}
  git push --tags
fi;

