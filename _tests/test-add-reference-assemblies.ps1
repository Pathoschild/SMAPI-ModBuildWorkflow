<#
.SYNOPSIS
    Integration tests for the `add-reference-assemblies` action. These are run on each commit to this repo.

.PARAMETER Repository
    The repository name with owner, like `StardewModders/mod-reference-assemblies`.

.PARAMETER Ref
    The branch, tag, or SHA to checkout, like `main`.

.PARAMETER Path
    The absolute path to which the repo should have been cloned.
#>
param(
    [string] $Repository = 'StardewModders/mod-reference-assemblies',
    [string] $Ref = 'main',
    [string] $Path = "$($env:HOME)/.steam/steam/steamapps/common/Stardew Valley"
)


##########
## Set up
##########
# log params
Write-Host "Running tests for add-reference-assemblies:"
Write-Host "    Repository: '$Repository'"
Write-Host "    Ref:        '$Ref'"
Write-Host "    Path:       '$Path'"
Write-Host " "

# clone repo for comparison
Write-Host "Setting up..."

$tempRepoPath = "$([System.IO.Path]::GetTempPath())/mod-ref-assemblies-test"
if ($Ref -eq 'main') {
    git clone --depth 1 --branch main "https://github.com/$Repository.git" $tempRepoPath
}
else {
    git clone "https://github.com/$Repository.git" $tempRepoPath

    Push-Location $tempRepoPath
    git -c advice.detachedHead=false checkout $Ref
    Pop-Location
}

Write-Host " "


##########
## Test: target directory must exist
##########
# assert
if (!(Test-Path $Path)) {
    throw "[FAIL] Reference assemblies not found at path '$Path'."
}
Write-Host "[OK] Folder exists at '$Path'."
Write-Host " "


##########
## Test: directory contents must match fetched repo
##########
# arrange
function Get-DllMap($root) {
    Get-ChildItem -Recurse -Filter *.dll -File -Path $root | ForEach-Object {
        $relativePath = Resolve-Path -Path $_.FullName -Relative -RelativeBasePath $root
        @{
            Path = $relativePath
            Hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        }
    }
}

# act
$expectedDlls = @(Get-DllMap $tempRepoPath | Sort-Object Path)
$actualDlls = @(Get-DllMap $Path | Sort-Object Path)
$diff = Compare-Object $expectedDlls $actualDlls -Property Path, Hash

# assert
if (!$expectedDlls.Count) {
    throw "[INCONCLUSIVE] No DLLs found in fetched repo at '$tempRepoPath'"
}

if ($diff) {
    $missing = $diff | Where-Object { $_.SideIndicator -eq '<=' }
    $extra = $diff | Where-Object { $_.SideIndicator -eq '=>' }

    $errorMessage = "[FAIL] Differences detected between '$Path' and fetched repository.`n`n"

    if ($missing) {
        $errorMessage += "Missing files in target path:`n"
        $missing | ForEach-Object { $errorMessage += "    - $($_.Path) ($($_.Hash))`n" }
    }

    if ($extra) {
        $errorMessage += "Extra files in target path:`n"
        $extra | ForEach-Object { $errorMessage += "    - $($_.Path) ($($_.Hash))`n" }
    }

    throw $errorMessage
}

Write-Host "[OK] Folder contents match fetched repository."
$actualDlls | ForEach-Object { Write-Host "    - $($_.Path) ($($_.Hash))" }
Write-Host ""
