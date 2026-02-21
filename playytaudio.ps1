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
                Write-Error "Scoop is not installed. Please install Scoop from https://scoop.sh"
                exit 1
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
    else {
        Write-Host "[$Command] is already installed." -ForegroundColor Green
    }
}

# Install required tools
Install-ScoopPackage "yt-dlp" "yt-dlp"
Install-ScoopPackage "ffmpeg" "ffplay"

Write-Host 

# Define the YouTube video URL
$youtubeUrl = "https://www.youtube.com/watch?v=UyrADlMELyI"

# Extract the audio stream URL and duration using yt-dlp
$audioInfo = yt-dlp --print-json -f bestaudio $youtubeUrl | ConvertFrom-Json
$audioUrl = $audioInfo.url
$duration = [math]::Floor($audioInfo.duration) # Duration in seconds

# Play the audio using ffplay in the background
Start-Process -FilePath "ffplay" -ArgumentList "-nodisp -autoexit -hide_banner -loglevel error $audioUrl" -NoNewWindow

# Show the progress bar
$startTime = Get-Date
while (((Get-Date) - $startTime).TotalSeconds -lt $duration) {
    $elapsed = (Get-Date) - $startTime
    $percentComplete = ($elapsed.TotalSeconds / $duration) * 100
    Write-Progress -Activity "Playing Audio" -Status "Progress: $([math]::Floor($percentComplete))%" -PercentComplete $percentComplete
    Start-Sleep -Milliseconds 500
}