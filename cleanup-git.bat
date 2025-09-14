@echo off
echo === Git Cleanup Script ===
echo This script will remove .terraform directories and .gitignore files from git history
echo.

echo Removing files from git index...

REM Remove .terraform directories from git tracking
git rm -r --cached "Day 8/terraform/.terraform" 2>nul || echo .terraform directory not in git

REM Remove .gitignore from terraform directory if it was committed
git rm --cached "Day 8/terraform/.gitignore" 2>nul || echo terraform .gitignore not in git

REM Add the root .gitignore
git add .gitignore

REM Commit the changes
echo Committing cleanup changes...
git commit -m "Remove .terraform directory and terraform .gitignore, add root .gitignore"

REM Push changes
echo Pushing changes to remote...
git push origin main

echo.
echo === Cleanup Complete ===
echo The following files have been removed from git tracking:
echo - Day 8/terraform/.terraform/ (directory)
echo - Day 8/terraform/.gitignore (file)
echo.
echo Added:
echo - .gitignore (root level)
echo.
echo Future .terraform directories and sensitive files will be ignored automatically.

pause
