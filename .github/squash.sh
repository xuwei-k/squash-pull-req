#!/usr/bin/env bash

set -e

PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")
if [[ "$PR_NUMBER" == "null" ]]; then
  PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
fi
if [[ "$PR_NUMBER" == "null" ]]; then
  echo "Failed to determine PR Number."
  exit 1
fi

PR_TITLE=$(jq -r ".pull_request.title" "$GITHUB_EVENT_PATH")
if [[ "$PR_TITLE" == "null" ]]; then
  PR_TITLE=$(jq -r ".issue.title" "$GITHUB_EVENT_PATH")
fi
if [[ "$PR_TITLE" == "null" ]]; then
  echo "Failed to determine PR Title."
  exit 1
fi

echo "Collecting information about PR $PR_TITLE #$PR_NUMBER of $GITHUB_REPOSITORY..."

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
          "${URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

BASE_BRANCH=$(echo "$pr_resp" | jq -r .base.ref)

USER_LOGIN=$(jq -r ".comment.user.login" "$GITHUB_EVENT_PATH")

user_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
            "${URI}/users/${USER_LOGIN}")

USER_NAME=$(echo "$user_resp" | jq -r ".name")
if [[ "$USER_NAME" == "null" ]]; then
  USER_NAME=$USER_LOGIN
fi
USER_NAME="${USER_NAME} (Rebase PR Action)"

USER_EMAIL=$(echo "$user_resp" | jq -r ".email")
if [[ "$USER_EMAIL" == "null" ]]; then
  USER_EMAIL="$USER_LOGIN@users.noreply.github.com"
fi

if [[ -z "$BASE_BRANCH" ]]; then
  echo "Cannot get base branch information for PR #$PR_NUMBER!"
  exit 1
fi

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)

if [[ "$HEAD_BRANCH" == "master" || "$HEAD_BRANCH" == "develop" || "$HEAD_BRANCH" == "production_ready" ]]; then
  echo "${HEAD_BRANCH} はsquash禁止です"
  exit 1
fi

echo "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

USER_TOKEN=${USER_LOGIN//-/_}_TOKEN
UNTRIMMED_COMMITTER_TOKEN=${!USER_TOKEN:-$GITHUB_TOKEN}
COMMITTER_TOKEN="$(echo -e "${UNTRIMMED_COMMITTER_TOKEN}" | tr -d '[:space:]')"

git remote set-url origin "https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git"
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork "https://x-access-token:$COMMITTER_TOKEN@github.com/$HEAD_REPO.git"

set -o xtrace

git fetch origin "$BASE_BRANCH"
git fetch fork "$HEAD_BRANCH"
git checkout "$BASE_BRANCH"
git merge --squash "fork/$HEAD_BRANCH"
git commit --no-edit
COMMIT_MESSAGE="$PR_TITLE\n\n"
COMMIT_MESSAGE+=$(git log --pretty=format:%B HEAD...HEAD^)
git commit --amend -m "$COMMIT_MESSAGE" 

# push back
git push --force-with-lease fork "$BASE_BRANCH:$HEAD_BRANCH"
