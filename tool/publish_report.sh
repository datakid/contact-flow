#!/usr/bin/env bash
set -u
name="${GITHUB_REF_NAME//\//-}"
rm -rf /tmp/pub
mkdir /tmp/pub
cd /tmp/pub
git init -q
git remote add origin "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
cp -r /tmp/rep/. .
git add -A
git -c user.name=ci -c user.email=ci@users.noreply.github.com commit -q -m "report for ${GITHUB_SHA}"
git push -q -f origin "HEAD:refs/heads/ci-report-${name}"
