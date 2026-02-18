#!/bin/bash

# remove-worktree.sh
# Removes a git worktree and cleans up associated resources
#
# Usage: remove-worktree.sh <name>
#
# Example: remove-worktree.sh my-feature
#
# This will:
# - Remove the git worktree at ~/repos/slack-summary-worktrees/<name>
# - Clean up git metadata

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
  echo "This will remove the worktree and clean up associated resources."
  exit 1
fi

NAME="$1"
WORKTREE_DIR="$HOME/repos/slack-summary-worktrees/$NAME"

# Validate we're in a git repo
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  error "Not in a git repository"
fi

# Check if worktree exists
if [ ! -d "$WORKTREE_DIR" ]; then
  warning "Worktree directory not found: $WORKTREE_DIR"
  info "Checking for orphaned git metadata..."

  # Try to prune anyway in case directory was manually deleted
  if git worktree prune --dry-run 2>&1 | grep -q "$NAME"; then
    info "Found orphaned worktree metadata, cleaning up..."
    git worktree prune
    success "Cleaned up orphaned metadata"
  else
    error "No worktree found with name: $NAME"
  fi

  exit 0
fi

info "Removing worktree: ${NAME}"
info "Location: ${WORKTREE_DIR}"
echo ""

# Check if there are uncommitted changes
cd "$WORKTREE_DIR"
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  warning "Worktree has uncommitted changes!"
  echo ""
  git status --short
  echo ""
  read -p "Do you want to force removal? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Removal cancelled"
    exit 0
  fi
  FORCE_FLAG="--force"
else
  FORCE_FLAG=""
fi

# Return to main repo directory
cd - > /dev/null

# Remove the worktree
info "Removing git worktree..."
if git worktree remove $FORCE_FLAG "$WORKTREE_DIR"; then
  success "Worktree removed"
else
  error "Failed to remove worktree"
fi

# Final cleanup
info "Running git worktree prune..."
git worktree prune
success "Cleanup complete"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Worktree Removed Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Removed:${NC}"
echo -e "  Name:      ${NAME}"
echo -e "  Location:  ${WORKTREE_DIR}"
echo ""
echo -e "${BLUE}To see remaining worktrees:${NC}"
echo -e "  ${GREEN}git worktree list${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
