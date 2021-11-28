# The default upstream user, release branch, and develop branch
# These are used to prepare the repo for developers
# but are not relevant for "production" checkouts
GIT_UPSTREAM_USER=${GIT_UPSTREAM_USER:-MiczFlor}
GIT_BRANCH_RELEASE=${GIT_BRANCH_RELEASE:-future3/main}
GIT_BRANCH_DEVELOP=${GIT_BRANCH_DEVELOP:-future3/develop}

convert_tardir_git_repo() {
  echo "****************************************************"
  echo "*** Converting tar-ball download into git repository"
  echo "****************************************************"

  # Just in case, the git version is not new enough, we split up git init -b "${GIT_BRANCH}" into:
  git init
  git checkout -b "${GIT_BRANCH}"
  git config pull.rebase false

  # We always add origin as the selected (possible) user repository
  # and, if relevant, MiczFlor's repository as upstream
  # This means for developers everything is fully set up.
  # For users there is no difference there is only origin = MiczFlor
  # We need to get the branch with larger depth, as we do not know
  # how many commits happened between download and git repo init
  # We simply get everything from the beginning of future 3 development but excluding Version 2.X
  if [[ $GIT_USE_SSH == true ]]; then
    git remote add origin "git@github.com:${GIT_USER}/${GIT_REPO_NAME}.git"
    if [[ "$GIT_USER" != "$GIT_UPSTREAM_USER" ]]; then
      git remote add upstream "git@github.com:${GIT_UPSTREAM_USER}/${GIT_REPO_NAME}.git"
    fi
    if [[ $(git fetch origin "${GIT_BRANCH}" --set-upstream --shallow-since=2021-04-21) -ne 0 ]]; then
      echo "*** Git fetch *************************************"
      echo "Error in getting Git Repository using SSH!"
      echo "Did you forget to upload the ssh key for this machine to GitHub?"
      echo "Defaulting to HTTPS protocol. You can change back to SSH later with"
      echo "git remote set-url origin git@github.com:${GIT_USER}/${GIT_REPO_NAME}.git"
      echo "git remote set-url upstream git@github.com:${GIT_UPSTREAM_USER}/${GIT_REPO_NAME}.git"
      echo "*** Git remotes ***********************************"
      GIT_USE_SSH=false
    fi
  fi

  if [[ $GIT_USE_SSH == false ]]; then
    git remote add origin "https://github.com/${GIT_USER}/${GIT_REPO_NAME}.git"
    if [[ "$GIT_USER" != "$GIT_UPSTREAM_USER" ]]; then
      git remote add upstream "https://github.com/${GIT_UPSTREAM_USER}/${GIT_REPO_NAME}.git"
    fi
    git fetch origin --set-upstream --shallow-since=2021-04-21 "${GIT_BRANCH}"
  fi
  HASH_BRANCH=$(git rev-parse FETCH_HEAD)
  echo "*** FETCH_HEAD ($GIT_BRANCH) = $HASH_BRANCH"

  git add .
  # Checkout the exact hash that we have downloaded as tarball
  git -c advice.detachedHead=false checkout "$GIT_HASH"
  HASH_HEAD=$(git rev-parse HEAD)
  echo "*** REQUESTED COMMIT = $HASH_HEAD"

  # Let's move onto the relevant branch, WITHOUT touching the current checked-out commit
  # Since we have fetched with --set-upstream above this initializes the tracking branch
  git checkout -b "$GIT_BRANCH"

  # Done! Directory is all set up as git repository now!

  # In case we get a non-develop or non-main branch, we speculatively
  # try to get these branches, so they can be checkout out with
  # git checkout ${GIT_BRANCH_DEVELOP}
  # without the need to set up the remote tracking information
  # However, in a user repository, these may not be present, so we suppress output in these cases
  if [[ $GIT_BRANCH != "${GIT_BRANCH_RELEASE}" ]]; then
    OUTPUT=$(git fetch origin --shallow-since=2021-04-21 "${GIT_BRANCH_RELEASE}" 2>&1)
    if [[ $? -ne 128 ]]; then
      echo "*** Preparing ${GIT_BRANCH_RELEASE} in background"
      echo -e "$OUTPUT"
    fi
  fi
  if [[ $GIT_BRANCH != "${GIT_BRANCH_DEVELOP}" ]]; then
    OUTPUT=$(git fetch origin --shallow-since=2021-04-21 "${GIT_BRANCH_DEVELOP}" 2>&1)
    if [[ $? -ne 128 ]]; then
      echo "*** Preparing ${GIT_BRANCH_DEVELOP} in background"
      echo -e "$OUTPUT"
    fi
  fi

  # Provide some status outputs to the user
  if [[ "${HASH_BRANCH}" != "${HASH_HEAD}" ]]; then
    echo "*** IMPORTANT NOTICE *******************************"
    echo "* Your requested branch has moved on while you were installing."
    echo "* Don't worry! We will stay within the the exact download version!"
    echo "* But we set up the git repo to be ready for updating."
    echo "* To start updating (observe updating guidelines!), do:"
    echo "* $ git pull origin $GIT_BRANCH"
  fi

  echo "*** Git remotes ************************************"
  git remote -v
  echo "*** Git status *************************************"
  git status -sb
  echo "*** Git log ****************************************"
  git log --oneline "HEAD^..origin/$GIT_BRANCH"
  echo "****************************************************"

  cp -f .githooks/* .git/hooks

  unset HASH_HEAD
  unset HASH_BRANCH
  unset OUTPUT
}

update_git_repo() {
  echo "Update Git repository: Branch='${GIT_BRANCH}'"
  cd ${INSTALLATION_PATH}
  TIMESTAMP=$(date +%s)

  # Git Repo has local changes
  if [[ $(git status --porcelain) ]]; then
    echo "  Found local changes in git repository.
  Moving them to backup branch 'local-backup-${TIMESTAMP}' and git stash"
    git fetch origin --depth 1
    git checkout -b local-backup-${TIMESTAMP}
    git stash
    git checkout ${GIT_BRANCH}
    git reset --hard origin/${GIT_BRANCH}
  else
    echo "  Updating version"
    git pull origin $(git rev-parse --abbrev-ref HEAD)
  fi
}
