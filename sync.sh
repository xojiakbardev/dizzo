#!/usr/bin/env bash
set -e

# ==============================================================
# Dizzo Monorepo Sync Helper
# ==============================================================

ACTION="${1:-status}"
MSG="${2:-Update from monorepo}"

case "$ACTION" in
  push)
    echo "🚀 Staging and pushing all changes to monorepo (xojiakbardev/dizzo)..."
    git add -A
    if git diff --staged --quiet; then
      echo "ℹ️ No changes to commit."
    else
      git commit -m "$MSG"
    fi
    git push origin main
    echo "✅ Pushed to monorepo! GitHub Actions will now sync changes to dizzo-org standalone repos automatically."
    ;;

  pull)
    echo "🔄 Pulling latest changes from monorepo (xojiakbardev/dizzo)..."
    git pull --rebase origin main
    echo "✅ Monorepo is up to date!"
    ;;

  status)
    echo "📊 Monorepo Git Status:"
    git status
    ;;

  *)
    echo "Usage: ./sync.sh [push|pull|status] [commit message]"
    echo ""
    echo "Examples:"
    echo "  ./sync.sh push \"feat: added new payment integration\""
    echo "  ./sync.sh pull"
    echo "  ./sync.sh status"
    exit 1
    ;;
esac
