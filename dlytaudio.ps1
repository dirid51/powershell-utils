param(
    [string]$Url,
    [string]$File
)

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
Install-ScoopPackage "ffmpeg" "ffmpeg"
Install-ScoopPackage "yt-dlp" "yt-dlp"

# Update yt-dlp
yt-dlp -U

$downloadFolder = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

if ($File) {
    $urls = Get-Content -Path $File
}
elseif ($Url) {
    $urls = @($Url)
}
else {
    Write-Error "Please specify either -Url or -File."
    exit 1
}

foreach ($url in $urls) {
    yt-dlp `
        -x -f bestaudio --audio-format mp3 --audio-quality 0 `
        -o $downloadFolder'/ytm-dlp/%(artist)s - %(title)s.%(ext)s' `
        $url
}