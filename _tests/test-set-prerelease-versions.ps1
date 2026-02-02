<#
.SYNOPSIS
    Integration tests for the `set-prerelease-versions` action. These are run on each commit to this repo.

    This assumes that the script was run on the solution structure created by `_tests/utilities/create-solution.ps1`.

.PARAMETER SolutionPath
    The path to the solution folder containing the projects to test, relative to the current working directory.

.PARAMETER OnlyZipped
    Whether to only change projects which create a mod release zip. Default true.

.PARAMETER TimestampFormat
    The format string for the timestamp in the pre-release tag. Default 'yyyyMMddHHmm'.

.PARAMETER TagFormat
    The pre-release tag to set, including the leading hyphen. Default '-alpha.{{timestamp}}'.
#>
param(
    [string] $SolutionPath,
    [string] $OnlyZipped = 'true',
    [string] $TimestampFormat = 'yyyyMMddHHmm',
    [string] $TagFormat = '-alpha.{{timestamp}}'
)


##########
## Set up
##########
Write-Host "Running tests for set-prerelease-versions:"
Write-Host "    SolutionPath:    '$SolutionPath'"
Write-Host "    OnlyZipped:      '$OnlyZipped'"
Write-Host "    TimestampFormat: '$TimestampFormat'"
Write-Host "    TagFormat:       '$TagFormat'"
Write-Host " "

$expectedTag = $TagFormat -replace '{{timestamp}}', (Get-Date -Format $TimestampFormat)

$projectNames = @('StableMod', 'BetaMod', 'NonZippedMod')
$projectRelativePaths = $projectNames | ForEach-Object { "$SolutionPath/$_/$_.csproj" }


##########
## Test: expected solution structure exists
##########
if (!(Test-Path -Path $SolutionPath -PathType Container)) {
    throw @"
        [FAIL] Expected solution folder '$SolutionPath' not found.

        Root contents:
        $(Get-ChildItem | ForEach-Object { "`n    - $($_.Name)" })
"@
}

foreach ($relativePath in $projectRelativePaths) {
    if (!(Test-Path -Path $relativePath -PathType Leaf)) {
        throw @"
            [FAIL] Expected project file '$relativePath' not found.

            Folder contents:
            $(Get-ChildItem $SolutionPath | ForEach-Object { "`n    - $($_.Name)" })
"@
    }
}


##########
## Test: correct edit was applied
##########
function Test-ExpectedProjectContent([string] $projectName, [string] $expectedVersion, [System.Nullable[bool]] $expectEnableModZip) {
    [xml] $actualContent = Get-Content -Path "$SolutionPath/$projectName/$projectName.csproj" -Raw

    $expectedContent =
        "<Project Sdk=""Microsoft.NET.Sdk"">`n" +
        "  <PropertyGroup>`n" +
        "    <Name>$projectName</Name>`n" +
        "    <Version>$expectedVersion</Version>`n";
        switch ($expectEnableModZip) {
            $true {
                $expectedContent += "    <EnableModZip>true</EnableModZip>`n"
            }
            $false {
                $expectedContent += "    <EnableModZip>false</EnableModZip>`n"
            }
        }
        $expectedContent +=
            "  </PropertyGroup>`n" +
            "</Project>`n"

    $expectedContent = [xml] $expectedContent

    if ($actualContent.OuterXml -ne $expectedContent.OuterXml) {
        throw @"
            [FAIL] Project file '$projectName' doesn't match the expected content.

            Expected content:
            -----------------
            $($expectedContent.OuterXml)

            Actual content:
            ---------------
            $($actualContent.OuterXml)
"@
    }
    else {
        Write-Host "[OK] Project file '$projectName' has expected content."
    }
}

Test-ExpectedProjectContent -projectName 'StableMod' -expectedVersion "1.0.1$expectedTag" -expectEnableModZip $true
Test-ExpectedProjectContent -projectName 'BetaMod' -expectedVersion "1.2.3$expectedTag" -expectEnableModZip $null

if ($OnlyZipped -eq 'true') {
    Test-ExpectedProjectContent -projectName 'NonZippedMod' -expectedVersion "1.0.0" -expectEnableModZip $false
}
else {
    Test-ExpectedProjectContent -projectName 'NonZippedMod' -expectedVersion "1.0.1$expectedTag" -expectEnableModZip $false
}
