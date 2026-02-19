@echo off
echo ========================================
echo  Pushing GestureCtrl to GitHub
echo ========================================
echo.

REM Remove old remote if exists
git remote remove origin 2>nul

REM Add your GitHub repo
echo Adding remote repository...
git remote add origin https://github.com/GovindUpadhyay13/Gesture-control.git

REM Check current branch
echo.
echo Checking current branch...
git branch

REM Stage all files
echo.
echo Staging all files...
git add .

REM Commit
echo.
echo Creating commit...
git commit -m "Complete GestureCtrl project with cursor control and ML training"

REM Push to main branch (force push to replace everything)
echo.
echo Pushing to GitHub...
echo WARNING: This will replace everything in the remote repository!
echo.
set /p confirm="Are you sure you want to continue? (y/n): "
if /i "%confirm%"=="y" (
    git branch -M main
    git push -f origin main
    echo.
    echo ========================================
    echo  SUCCESS! Project pushed to GitHub
    echo ========================================
    echo.
    echo View your repo at:
    echo https://github.com/GovindUpadhyay13/Gesture-control
) else (
    echo.
    echo Push cancelled.
)

echo.
pause
