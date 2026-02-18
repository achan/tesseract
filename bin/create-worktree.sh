#!/bin/bash

# create-worktree.sh
# Creates a git worktree with environment setup for Rails development
#
# Usage: create-worktree.sh <name>
#
# Example: create-worktree.sh my-feature
#
# This will:
# - Create git worktree at ~/repos/slack-summary-worktrees/<name>
# - Symlink environment files from the main repo
# - Install dependencies (bundle)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✓ $1${NC}"
}

info() {
  echo -e "${BLUE}→ $1${NC}"
}

warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Parse arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <name>"
  echo ""
  echo "Example: $0 my-feature"
  echo ""
  echo "This will automatically:"
  echo "  - Create worktree at ~/repos/slack-summary-worktrees/<name>"
  echo "  - Set up environment and dependencies"
  exit 1
fi

NAME="$1"
MAIN_DIR="$PWD"
WORKTREE_DIR="$HOME/repos/slack-summary-worktrees/$NAME"

# Validate we're in a git repo
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  error "Not in a git repository"
fi

# Validate we're not inside .git directory
if [ "$(git rev-parse --is-inside-git-dir 2>/dev/null)" = "true" ]; then
  error "Cannot run from inside .git directory"
fi

# Check if we're already in a worktree
if git rev-parse --git-dir 2>/dev/null | grep -q '\.git/worktrees'; then
  error "Already in a worktree. Please run this from the main repository."
fi

info "Creating worktree: ${NAME}"
info "Main directory: ${MAIN_DIR}"
info "Worktree directory: ${WORKTREE_DIR}"
echo ""

# Create worktree parent directory if it doesn't exist
if [ ! -d "$HOME/repos/slack-summary-worktrees" ]; then
  info "Creating worktree parent directory: ~/repos/slack-summary-worktrees"
  mkdir -p "$HOME/repos/slack-summary-worktrees"
  success "Directory created"
fi

# Create worktree with branch
BRANCH="feature/$NAME"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  info "Branch '$BRANCH' already exists, checking out existing branch..."
  if ! git worktree add "$WORKTREE_DIR" "$BRANCH"; then
    error "Failed to create worktree with existing branch"
  fi
else
  info "Creating new branch '$BRANCH' from current branch ($CURRENT_BRANCH)..."
  if ! git worktree add -b "$BRANCH" "$WORKTREE_DIR" "$CURRENT_BRANCH"; then
    error "Failed to create worktree with new branch"
  fi
fi

success "Worktree created at: ${WORKTREE_DIR}"

# Change to worktree directory
cd "$WORKTREE_DIR"

# Symlink .env if it exists
if [ -f "${MAIN_DIR}/.env" ]; then
  info "Linking .env from main repo..."
  ln -s "${MAIN_DIR}/.env" .env
  success ".env symlinked"
fi

# Install dependencies
if [ -f "Gemfile" ]; then
  info "Installing dependencies with bundle..."
  if bundle install; then
    success "bundle install complete"
  else
    warning "bundle install had warnings (check output above)"
  fi
fi

# Final instructions
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Worktree Created Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Worktree Details:${NC}"
echo -e "  Name:      ${NAME}"
echo -e "  Location:  ${WORKTREE_DIR}"
echo -e "  Branch:    ${BRANCH}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Navigate to your worktree:"
echo -e "   ${GREEN}cd ${WORKTREE_DIR}${NC}"
echo ""
echo "2. Start your development server:"
echo -e "   ${GREEN}bin/rails server${NC}"
echo ""
echo "   Or use tmux:"
echo -e "   ${GREEN}bin/start-worktree.sh${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
