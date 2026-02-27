# Function to install Scoop packages
function Install-ScoopPackage {
    param(
        [string]$Package,
        [string]$Command
    )
    
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[$Command] not found. Attempting to install via Scoop..." -ForegroundColor Yellow
        try {
            # Check if Scoop is installed
            if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
                Write-Error "Scoop is not installed. Attempting to install Scoop..."
                # 1. Set execution policy to allow scripts
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

                # 2. Install Scoop
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

                # Verify Scoop installation
                if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
                    Write-Error "Scoop installation failed. Please check your internet connection and try again."
                    exit 1
                }
                Write-Host "Scoop successfully installed." -ForegroundColor Green

                # 3. Refresh the Path for the current session
                $env:PATH += ";$env:USERPROFILE\scoop\shims"
            }
            
            scoop install $Package
            
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
                Write-Error "Failed to locate $Command after installation. You may need to restart PowerShell."
                exit 1
            }
            Write-Host "[$Command] successfully installed." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install $Package via Scoop: $_"
            exit 1
        }
    }
}

# Ensure git is installed
Install-ScoopPackage "git" "git"

# 1. SET YOUR PARENT FOLDER HERE
$parentDirectory = "C:\Users\dirid\classes\2026\winter\cse210\a1"

Write-Host "Starting search in: $parentDirectory" -ForegroundColor Yellow

# Find all directories that contain a .git sub-directory
$repoPaths = Get-ChildItem -Path $parentDirectory -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -Path (Join-Path $_.FullName ".git")
}

if ($null -eq $repoPaths -or $repoPaths.Count -eq 0) {
    Write-Host "No Git repositories found." -ForegroundColor Red
    pause
    exit
}

$totalRepos = $repoPaths.Count
Write-Host "Found $totalRepos repositories. Starting pull..."

# --- Statistics Initialization ---
$successCount = 0
$resetCount = 0
$failCount = 0
$upToDateCount = 0 # New counter for up-to-date repos
# -------------------------------

# Loop through each repository path found
foreach ($repo in $repoPaths) {
    Write-Host ""
    Write-Host "--- Processing: $($repo.FullName) ---" -ForegroundColor Cyan
    
    try {
        # "Push" into the repo directory, saving the current location
        Push-Location -Path $repo.FullName
        
        Write-Host "Pulling in $(Get-Location)..."
        
        # Execute git pull and capture ALL output (stdout and stderr)
        # 2>&1 redirects the error stream (2) to the standard output stream (1)
        $pullOutput = git pull 2>&1
        
        # Check the exit code of the last command
        if ($LASTEXITCODE -eq 0) {
            # Check if the pull was successful *because* it was already up-to-date
            if ($pullOutput -match "Already up to date") {
                Write-Host "Already up to date." -ForegroundColor DarkGray
                $upToDateCount++
            }
            else {
                Write-Host "Pull successful on first attempt." -ForegroundColor Green
            }
            $successCount++ # It's still a success
        } 
        else {
            Write-Host "First pull failed." -ForegroundColor Yellow
            
            # Check if the failure was due to the specific "local changes" error
            if ($pullOutput -match "Your local changes to the following files would be overwritten") {
                Write-Host "Reason: Local changes detected. Resetting changes..." -ForegroundColor Yellow
                $resetCount++ # Increment reset counter
                
                # Discard all local changes and commits
                git reset --hard HEAD
                
                # Optional: Also remove untracked files and directories.
                # This is often needed to get a truly clean state.
                Write-Host "Cleaning untracked files..."
                git clean -fd
                
                Write-Host "Attempting pull again after reset..."
                
                # Try pulling again
                $secondPullOutput = git pull 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    # Check if the second pull was successful *because* it was already up-to-date
                    if ($secondPullOutput -match "Already up to date") {
                        Write-Host "Second pull successful (already up to date)." -ForegroundColor DarkGray
                        $upToDateCount++
                    }
                    else {
                        Write-Host "Second pull successful." -ForegroundColor Green
                    }
                    $successCount++ # It's now in a successful state
                }
                else {
                    Write-Host "!!! ERROR: Second pull also failed after reset." -ForegroundColor Red
                    Write-Host $secondPullOutput -ForegroundColor Red
                    $failCount++ # Failed even after reset
                }
            }
            else {
                # The failure was for a different reason (e.g., real merge conflict, network error)
                Write-Host "!!! ERROR: Pull failed for a reason other than local changes." -ForegroundColor Red
                Write-Host "Error details:" -ForegroundColor Red
                # Write the original output we captured
                Write-Host $pullOutput -ForegroundColor Red
                $failCount++ # Failed for other reasons
            }
        }
    }
    catch {
        # Catch any *scripting* errors (e.g., Push-Location fails)
        Write-Host "!!! SCRIPT ERROR processing $($repo.FullName): $_" -ForegroundColor Red
        $failCount++ # Count this as a failure
    }
    finally {
        # 'Pop' back to the original directory, whether the 'try' block
        # succeeded or failed. This ensures the script can continue.
        Pop-Location
    }
}

Write-Host ""
Write-Host "--- SCRIPT COMPLETE ---" -ForegroundColor Green
Write-Host "Total Repositories Found: $totalRepos"
Write-Host "Successfully Pulled: $successCount" -ForegroundColor Green
Write-Host "Already Up-to-Date: $upToDateCount" -ForegroundColor DarkGray
Write-Host "Required Reset: $resetCount" -ForegroundColor Yellow
Write-Host "Failed to Pull: $failCount" -ForegroundColor Red
Write-Host ""

Write-Host "Returning to original directory."
Write-Host "Current directory is: $(Get-Location)"
# Keep the window open to see the results
Read-Host "Press Enter to exit..."
