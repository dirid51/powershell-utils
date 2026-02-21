<#
.SYNOPSIS
    Recursively searches a parent directory for local Git repositories
    and extracts the remote URL for the "origin".

.DESCRIPTION
    This script searches for all `.git` directories (including hidden)
    within a specified -ParentDirectory. For each repository found,
    it reads the `.git/config` file, parses it to find the
    `[remote "origin"]` section, and extracts the `url` value.

    It returns a list of custom objects, each containing the
    local path of the repository and its remote URL.

.PARAMETER ParentDirectory
    The absolute or relative path to the parent directory where you
    want to start the search. The search is recursive. This parameter
    is mandatory.

.EXAMPLE
    .\Get-RepoUrls.ps1 -ParentDirectory "C:\Projects" | Format-Table -AutoSize

    This command finds all repos and formats the output as a clean table.

.EXAMPLE
    .\Get-RepoUrls.ps1 -ParentDirectory "C:\Projects" | ConvertTo-Json | Out-File "C:\Temp\repos.json"

    This command finds all repos, converts the list to JSON,
    and saves it to a file.

.EXAMPLE
    .\Get-RepoUrls.ps1 -ParentDirectory "C:\Projects" | Export-Csv -Path "C:\Temp\repos.csv" -NoTypeInformation

    This command finds all repos and exports the list of paths
    and URLs to a CSV file.
#>
param (
    [Parameter(Mandatory = $true, HelpMessage = "The parent directory to search for Git repositories.")]
    [string]$ParentDirectory
)

# --- Script Body ---

$results = [System.Collections.Generic.List[PSObject]]::new()

# 1. Resolve the parent directory path to an absolute path
try {
    $SearchPath = (Resolve-Path -Path $ParentDirectory -ErrorAction Stop).Path
    Write-Host "Searching for Git repositories in: $SearchPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to resolve path '$ParentDirectory'. Error: $_"
    return
}

# 2. Find all ".git" directories recursively.
#    Use -Force to ensure hidden directories are included.
#    -ErrorAction SilentlyContinue is used to skip directories
#    we may not have permission to access (e.g., System Volume Information).
$gitDirectories = Get-ChildItem -Path $SearchPath -Recurse -Directory -Filter ".git" -Force -ErrorAction SilentlyContinue

if (-not $gitDirectories) {
    Write-Warning "No Git repositories found."
    return
}

# 3. Process each found repository
Write-Host "Found $($gitDirectories.Count) repositories. Processing..."
foreach ($gitDir in $gitDirectories) {
    $configPath = Join-Path -Path $gitDir.FullName -ChildPath "config"
    $repoPath = $gitDir.Parent.FullName # The actual root of the cloned repo
    $remoteUrl = $null

    if (Test-Path -Path $configPath) {
        try {
            # Read the entire config file as a single string (-Raw)
            $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop

            # 4. Use regex to find the URL under [remote "origin"]
            #    - (?s): Single-line mode. Makes '.' match newline characters.
            #    - \[remote "origin"\]: Matches the literal section header.
            #    - .*?: Non-greedily matches any character.
            #    - url\s*=\s*: Matches "url = " with any amount of whitespace.
            #    - ([^\s]+): Captures the URL (any character that is not whitespace)
            $regex = '(?s)\[remote "origin"\].*?url\s*=\s*([^\s]+)'
            
            if ($configContent -match $regex) {
                # The captured URL is in the $matches[1] automatic variable
                $remoteUrl = $matches[1]
            }
            else {
                $remoteUrl = "Origin remote or URL not found"
            }
        }
        catch {
            # Handle potential errors reading the config file
            $remoteUrl = "Error reading config: $($_.Exception.Message | Out-String)"
        }
    }
    else {
        $remoteUrl = "config file not found (repository may be corrupt)"
    }

    # 5. Add the finding to our results list
    $results.Add(
        [PSCustomObject]@{
            LocalPath = $repoPath
            RemoteUrl = $remoteUrl
        }
    )
}

# 6. Output the final results to the pipeline.
#    By writing the $results collection directly to the pipeline,
#    the user can decide how to format it (e.g., pipe to Format-Table,
#    ConvertTo-Json, Export-Csv, etc.)
if ($results.Count -gt 0) {
    Write-Host "Scan complete." -ForegroundColor Green
    # Write the raw objects to the success stream (pipeline)
    $results
}
else {
    Write-Warning "Processed repositories, but no results to display."
}

