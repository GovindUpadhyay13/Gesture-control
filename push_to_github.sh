#!/bin/bash

echo "========================================"
echo " Pushing GestureCtrl to GitHub"
echo "========================================"
echo ""

# Remove old remote if exists
git remote remove origin 2>/dev/null

# Add your GitHub repo
echo "Adding remote repository..."
git remote add origin https://github.com/GovindUpadhyay13/Gesture-control.git

# Check current branch
echo ""
echo "Checking current branch..."
git branch

# Stage all files
echo ""
echo "Staging all files..."
git add .

# Commit
echo ""
echo "Creating commit..."
git commit -m "Complete GestureCtrl project with cursor control and ML training"

# Push to main branch (force push to replace everything)
echo ""
echo "Pushing to GitHub..."
echo "WARNING: This will replace everything in the remote repository!"
echo ""
read -p "Are you sure you want to continue? (y/n): " confirm

if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    git branch -M main
    git push -f origin main
    echo ""
    echo "========================================"
    echo " SUCCESS! Project pushed to GitHub"
    echo "========================================"
    echo ""
    echo "View your repo at:"
    echo "https://github.com/GovindUpadhyay13/Gesture-control"
else
    echo ""
    echo "Push cancelled."
fi

echo ""
