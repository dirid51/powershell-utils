<#
.SYNOPSIS
    Converts a scanned image PDF to a text file using Poppler (pdftoppm) and Tesseract OCR.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$InputPdf,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "output.txt"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- 1. Dependency Check & Installation ---
function Install-ScoopPackage {
    param(
        [string]$Package,
        [string]$Command
    )
    
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[-] $Command not found." -ForegroundColor Yellow
        Write-Host "[*] Attempting to install $Package via Scoop..." -ForegroundColor Cyan
        
        try {
            # Check if Scoop is installed
            if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
                Write-Error "Scoop is not installed. Attempting to install Scoop..."
                # Set execution policy to allow scripts
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                # Install Scoop
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
                # Verify Scoop installation
                if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
                    Write-Error "Scoop installation failed. Please check your internet connection and try again."
                    exit 1
                }
                Write-Host "[+] Scoop successfully installed." -ForegroundColor Green
                # Refresh Path for the current session
                $env:PATH += ";$env:USERPROFILE\scoop\shims"
            }
            
            scoop install $Package
            
            # Refresh Path for the current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
                Write-Error "Failed to locate $Command even after installation. You may need to restart PowerShell."
                exit
            }
            Write-Host "[+] $Command successfully installed." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install $Package via Scoop: $_"
            exit
        }
    }
    else {
        Write-Host "[+] $Command is already installed." -ForegroundColor Green
    }
}

Install-ScoopPackage "tesseract" "tesseract"
Install-ScoopPackage "poppler" "pdftoppm"

# --- 2. Setup Temporary Workspace ---
$tempDir = New-Item -ItemType Directory -Path "$PSScriptRoot\temp_ocr_work" -Force
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputPdf)

try {
    Write-Host "[*] Step 1: Converting PDF pages to images..." -ForegroundColor Cyan
    # -r 300 sets DPI to 300 (ideal for OCR)
    & pdftoppm -png -r 300 $InputPdf "$tempDir\$baseName"

    $images = Get-ChildItem "$tempDir\*.png"
    Write-Host "[*] Step 2: Running OCR on $($images.Count) pages..." -ForegroundColor Cyan
    
    Clear-Content $OutputFile -ErrorAction SilentlyContinue

    foreach ($img in $images) {
        Write-Host "    Processing $($img.Name)..."
        # Added -Encoding utf8 to the pipe
        & tesseract $img.FullName stdout | Out-File -FilePath $OutputFile -Append -Encoding utf8
    }

    Write-Host "[+] Success! OCR text saved to: $OutputFile" -ForegroundColor Green

}
finally {
    # --- 3. Cleanup ---
    Remove-Item -Recurse -Force $tempDir
}