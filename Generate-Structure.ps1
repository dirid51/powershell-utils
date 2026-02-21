<#
.SYNOPSIS
    Generates a Markdown file structure tree for LLM context.
    Uses single quotes to safely handle markdown backticks.
#>

param (
    [string]$Path = (Get-Location),
    [string]$OutputPath = "file_structure.md"
)

# --- Configuration: Folders/Files to Ignore ---
$IgnoreList = @(
    ".git",
    ".vs",
    ".vscode",
    ".idea",
    "node_modules",
    "bin",
    "obj",
    "__pycache__",
    "vendor",
    "dist",
    "build",
    "coverage"
)

# Global list to hold the tree lines
$global:OutputLines = @()

function Get-Tree {
    param (
        [string]$CurrentPath,
        [string]$Indent = "",
        [bool]$Last = $true
    )

    $Name = Split-Path $CurrentPath -Leaf

    # Determine the visual marker
    $Marker = if ($Last) { "└── " } else { "├── " }
    
    # Add to global output
    $global:OutputLines += "$Indent$Marker$Name"

    # Process directories
    if (Test-Path $CurrentPath -PathType Container) {
        $NewIndent = $Indent + (($Last) ? "    " : "│   ")

        try {
            # Get content, filtering out ignored items
            $Items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue | 
            Where-Object { $IgnoreList -notcontains $_.Name }

            $Count = $Items.Count
            $i = 0

            foreach ($Item in $Items) {
                $i++
                $IsLastItem = ($i -eq $Count)
                Get-Tree -CurrentPath $Item.FullName -Indent $NewIndent -Last $IsLastItem
            }
        }
        catch {
            $global:OutputLines += "$NewIndent    (Access Denied)"
        }
    }
}

# --- Main Execution ---

$RootPath = Convert-Path $Path
$RootName = Split-Path $RootPath -Leaf

Write-Host "Generating structure for: $RootName" -ForegroundColor Cyan

# Clear previous output
$global:OutputLines = @()

# 1. Start the Markdown content
$MarkdownContent = @()
$MarkdownContent += "# File Structure: $RootName"
$MarkdownContent += ""

# 2. Add the opening triple backticks using Single Quotes to prevent escaping issues
$MarkdownContent += '```text'

# 3. Add the Root Directory Name manually at the top of the tree block
$MarkdownContent += $RootName

# 4. Generate the tree for the children of the root
$RootItems = Get-ChildItem -Path $RootPath -Force -ErrorAction SilentlyContinue | 
Where-Object { $IgnoreList -notcontains $_.Name }

$rCount = $RootItems.Count
$rIndex = 0

foreach ($Item in $RootItems) {
    $rIndex++
    Get-Tree -CurrentPath $Item.FullName -Indent "" -Last ($rIndex -eq $rCount)
}

# 5. Add the tree lines to the content
$MarkdownContent += $global:OutputLines

# 6. Add the closing triple backticks using Single Quotes
$MarkdownContent += '```'

# 7. Write to file
$MarkdownContent | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "Success! Structure saved to: $OutputPath" -ForegroundColor Green