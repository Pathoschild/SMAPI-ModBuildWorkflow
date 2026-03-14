<#
.SYNOPSIS
    Create a solution folder with representative sample project files.

    This creates three project files:
      - StableMod: version 1.0.0 with `<EnableModZip>true</EnableModZip>`;
      - BetaMod: version 1.2.3-beta.1 with `EnableModZip` omitted (default true);
      - NonZippedMod: version 1.0.0 with `<EnableModZip>false</EnableModZip>`

.PARAMETER SolutionPath
    The path to the solution folder to create, relative to the current working directory.
#>
param(
    [string] $SolutionPath
)

# create directory
$solutionPath = "$PWD/$SolutionPath"
New-Item -Path "$solutionPath" -ItemType Directory | Out-Null

# create projects
function Add-TestProject([string] $solutionRoot, [string] $name, [string] $version = '1.0.0', [System.Nullable[bool]] $enableModZip = $true) {
    # create project directory
    $projectDir = "$solutionRoot/$name"
    if (Test-Path $projectDir) {
        throw "Can't create test project '$name': directory already exists at '$projectDir'."
    }
    New-Item -ItemType Directory -Path $projectDir | Out-Null

    # create project file
    $projectFile = "$projectDir/$name.csproj"

    $content =
        "<Project Sdk=""Microsoft.NET.Sdk"">`n" +
        "  <PropertyGroup>`n" +
        "    <Name>$name</Name>`n" +
        "    <Version>$version</Version>`n";

    switch ($enableModZip) {
        $true {
            $content += "    <EnableModZip>true</EnableModZip>`n"
        }
        $false {
            $content += "    <EnableModZip>false</EnableModZip>`n"
        }
    }

    $content +=
        "  </PropertyGroup>`n" +
        "</Project>`n"

    $content | Out-File -FilePath $projectFile -Encoding utf8
}

Add-TestProject -SolutionRoot "$solutionPath" -name 'StableMod' -enableModZip $true
Add-TestProject -SolutionRoot "$solutionPath" -name 'BetaMod' -version '1.2.3-beta.1' -enableModZip $null
Add-TestProject -SolutionRoot "$solutionPath" -name 'NonZippedMod' -enableModZip $false
