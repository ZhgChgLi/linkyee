#!/usr/bin/env bash
# ref: https://github.com/jekyll/jekyll

set -eu  # Exit on error or unset variable

PAGES_BRANCH="gh-pages"

init() {
  # Check if the script is running in a GitHub Actions environment
  if [[ -z ${GITHUB_ACTION+x} ]]; then
    echo "ERROR: Not allowed to deploy outside of the GitHub Action environment."
    exit 1
  fi
}

build() {
  # Run the Ruby script to generate the output
  bundle exec ruby "./scaffold.rb"

  # Move all generated files to the root directory
  mv ./_output/* ./
}

setup_gh() {
  # Delete the branch if it exists, and create a new one
  if git show-ref --verify --quiet "refs/heads/$PAGES_BRANCH"; then
    echo "Branch '$PAGES_BRANCH' exists. Deleting it..."
    git branch -D "$PAGES_BRANCH"  # Delete the local branch
  else
    echo "Branch '$PAGES_BRANCH' does not exist locally. Skipping deletion."
  fi

  # Create and switch to the new branch
  git checkout -b "$PAGES_BRANCH"
}

deploy() {
  # Configure Git user for the commit
  git config --global user.name "ZhgChgLiBot"
  git config --global user.email "no-reply@zhgchg.li"

  # Reset the current HEAD to prepare for new commits
  git update-ref -d HEAD
  git add -A
  git commit -m "[Automation] Site update No.${GITHUB_RUN_NUMBER}"

  # Push the new branch to the remote repository
  git push -u origin "$PAGES_BRANCH" --force
}

main() {
  init     # Initialize and validate environment
  build    # Build the site
  setup_gh # Set up the gh-pages branch
  deploy   # Deploy the site
}

# Execute the main function
main