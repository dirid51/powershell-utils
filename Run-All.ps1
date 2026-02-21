# --- SCRIPT PARAMETERS ---
param (
    # The relative path from the repo root to the assignment
    # e.g., "prove\Develop02", "prove\Develop03", etc.
    [Parameter(Mandatory = $true)]
    [string]$assignmentPath
)

# --- CONFIGURE THIS 1 VARIABLE ---

# 1. The path to the folder containing all your student repo clones
#    (e.g., "C:\Users\Professor\Documents\CSE210-Grading")
$basePath = "C:\Users\dirid\classes\2025\fall\cse210\a1"

# --- SCRIPT ---
# You shouldn't need to edit below this line.

# --- NEW: Initialize tracking lists ---
$crashedPrograms = @{}
$defaultTemplateStudents = [System.Collections.Generic.List[string]]::new()

# Check if the base path is valid
if (-not (Test-Path $basePath)) {
    Write-Error "Error: The base path '$basePath' was not found."
    Write-Error "Please edit the script and set the `$basePath` variable."
    exit
}

# Get the short name of the assignment (e.g., "Develop02")
$assignmentName = Split-Path $assignmentPath -Leaf
if (-not $assignmentName) {
    Write-Error "Error: Invalid assignmentPath. Could not determine assignment name."
    exit
}

# --- NEW: Define the exact default template ---
# We use a 'here-string' (@") for a multi-line literal string.
$defaultTemplate = @"
using System;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("Hello $assignmentName World!");
    }
}
"@

$studentFolders = Get-ChildItem -Path $basePath -Directory | Sort-Object Name

Write-Host "Starting batch run for $assignmentPath..." -ForegroundColor Yellow
Write-Host "Base student folder: $basePath"
Write-Host "============================================="

foreach ($studentRepo in $studentFolders) {
    
    $projectName = $studentRepo.Name
    
    Write-Host "($projectName) Searching for .git repo in '$($studentRepo.FullName)'..." -ForegroundColor Gray
    
    $gitDir = Get-ChildItem -Path $studentRepo.FullName -Filter ".git" -Directory -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1
    
    if ($null -eq $gitDir) {
        Write-Warning "SKIPPING ${projectName}: No .git directory found inside."
        Write-Host "---------------------------------------------"
        continue
    }
    
    $repoRootPath = $gitDir.Parent.FullName
    $projectPath = Join-Path $repoRootPath $assignmentPath
    $programCsPath = Join-Path $projectPath "Program.cs"
    
    Write-Host "($projectName) Found repo at: $repoRootPath" -ForegroundColor DarkGray

    # --- NEW: Static analysis of Program.cs ---
    if (-not (Test-Path $programCsPath)) {
        Write-Warning "SKIPPING ${projectName}: Program.cs not found at '$programCsPath'"
        Write-Host "---------------------------------------------"
        continue
    }

    # Read the file content. -Raw reads it as one string.
    $fileContent = Get-Content $programCsPath -Raw
    
    # Normalize line endings (CRLF vs LF) and trim whitespace for a reliable comparison
    $normalizedTemplate = $defaultTemplate.Replace("`r`n", "`n").Trim()
    $normalizedFile = $fileContent.Replace("`r`n", "`n").Trim()

    if ($normalizedTemplate -eq $normalizedFile) {
        Write-Host "SKIPPING ${projectName}: Found default 'Hello World' template." -ForegroundColor Yellow
        $defaultTemplateStudents.Add($projectName)
        Write-Host "---------------------------------------------"
        continue # Skip to the next student
    }
    # --- END NEW: Static analysis ---

    # --- REGULAR SCRIPT: For non-template programs ---
    
    # Pause for user
    Write-Host "Press ENTER to run project for: $projectName" -ForegroundColor Cyan
    Read-Host 
    
    Clear-Host

    # Check if the assignment directory exists
    if (-not (Test-Path $projectPath)) {
        Write-Warning "SKIPPING ${projectName}: Assignment path not found at:"
        Write-Warning "$projectPath"
        Write-Host "---------------------------------------------"
        continue
    }

    Write-Host "--- Now running: $projectName ---" -ForegroundColor Green
    Write-Host "Running from: $projectPath"
    Write-Host ""
    
    # Run the program, now with error tracking
    try {
        dotnet run --project $projectPath -ErrorAction Stop
    }
    catch {
        Write-Error "CRITICAL FAILURE: Program for $projectName crashed or failed to build."
        
        $errorMessage = $_.Exception.Message.Trim()
        
        if (-not $crashedPrograms.ContainsKey($errorMessage)) {
            $crashedPrograms[$errorMessage] = [System.Collections.Generic.List[string]]::new()
        }
        
        $crashedPrograms[$errorMessage].Add($projectName)
    }

    Write-Host ""
    Write-Host "--- Finished: $projectName ---" -ForegroundColor Green
    Write-Host "---------------------------------------------"
}

# --- FINAL SUMMARY REPORT ---

Write-Host "============================================="
Write-Host "Batch run complete. Summary of issues:" -ForegroundColor Yellow
Write-Host "============================================="

if ($crashedPrograms.Keys.Count -eq 0 -and $defaultTemplateStudents.Count -eq 0) {
    Write-Host "No issues found! All programs ran without crashing and were not default templates." -ForegroundColor Green
}

# --- Report on Crashed/Failed Programs ---
if ($crashedPrograms.Keys.Count -gt 0) {
    Write-Host ""
    Write-Host "--- CRASHED OR FAILED TO BUILD ---" -ForegroundColor Red
    
    foreach ($reason in $crashedPrograms.Keys) {
        Write-Host ""
        Write-Host "REASON: $reason" -ForegroundColor Yellow
        
        $students = $crashedPrograms[$reason]
        foreach ($studentName in $students) {
            Write-Host "    - $studentName"
        }
    }
}

# --- Report on Default Template ---
if ($defaultTemplateStudents.Count -gt 0) {
    Write-Host ""
    Write-Host "--- FOUND DEFAULT 'HELLO WORLD' TEMPLATE ---" -ForegroundColor Yellow
    Write-Host "REASON: Program.cs was unchanged from the default."
    foreach ($studentName in $defaultTemplateStudents) {
        Write-Host "    - $studentName"
    }
}