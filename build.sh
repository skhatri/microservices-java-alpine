#!/usr/bin/env bash

set -eo pipefail

current_hash=$(git log --pretty=format:'%h' --max-count=1)
current_branch=$(git branch --show-current|sed 's#/#_#')

version=""
: "${push:=${1:-yes}}"

platforms="linux/amd64,linux/arm64"

create_tag() {
    if [[ ${current_branch} == "main" ]]; 
    then
        git fetch --tags --force
        current_version_at_head=$(git tag --points-at HEAD)
        if [[ -z ${current_version_at_head} ]] || [[ ! "${current_version_at_head}" =~ ^v+ ]] || [[ "${push}" == "no" ]];
        then 
            commit_hash=$(git rev-list --tags --topo-order --max-count=1)
            latest_version=""
            if [[ "${commit_hash}" != "" ]]; then            
              latest_version=$(git describe --tags ${commit_hash} 2>/dev/null)
            fi;
            if [[ ${latest_version} =~ ^v+ ]];
            then 
                read a b c <<< $(echo $latest_version|sed 's/\./ /g')
                version="$a.$b.$((c+1))"
            else
                version="v1.0.0"
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
  # setup for docker creating multi-platform images
  docker run --privileged --rm tonistiigi/binfmt --install all
  docker buildx create --use --name builder
  docker buildx inspect --bootstrap builder

  source project.properties
  for t in "17" "21"
  do
    for u in "-u10k" ""
    do
      project="microservices-java${t}-alpine${u}"
      image_version_tag="${owner}/${project}:${version}"
      image_latest_tag="${owner}/${project}:latest"
      echo building ${image_version_tag}
      pkg=zulu${t}
      usrid="1000"
      dockerfile="Dockerfile"
      if [[ "$u" == "-u10k" ]];
      then 
        usrid="10000"
        dockerfile="Dockerfile.u10k"
	echo "IMAGE_${t}_u10k=${image_version_tag}" >> $GITHUB_ENV
      else
        echo "IMAGE_${t}=${image_version_tag}" >> $GITHUB_ENV
      fi;
      image_push=""
      if [[ "${push}" == "yes" ]]; then
        image_push="--push"
      fi;
      
      docker buildx build --platform "$platforms" --no-cache -t "${image_version_tag}" -t "${image_latest_tag}" . --build-arg ZULU_PKG=${pkg} --build-arg UID=${usrid} --build-arg JAVA_VERSION=${t} "${image_push}" -f $dockerfile
    done;
  done;

  now=$(date '+%Y-%m-%dT%H:%M:%S%z')


  git config --global user.email "${email}"
  git config --global user.name "${name}"
  if [[ "${push}" == "yes" ]]; then
    git tag -m "{\"author\":\"ci\", \"branch\":\"$current_branch\", \"hash\": \"${current_hash}\", \"version\":\"${version}\",  \"build_date\":\"${now}\"}"  ${version}
    git push --tags
  fi;
fi;

