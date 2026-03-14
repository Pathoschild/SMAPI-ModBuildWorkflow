<#
.SYNOPSIS
    Integration tests for the `add-build-environment` action. These are run on each commit to this repo.
#>
param(
    [int] $DotNetMajorVersion = 6,
    [int] $DotNetMinorVersion = 0,
    [string] $ForceBuildWithDotNetVersion = 'false'
)

##########
## Set up
##########
Write-Host "Running tests for add-build-environment."
Write-Host "    DotNetMajorVersion:          '$DotNetMajorVersion'"
Write-Host "    DotNetMinorVersion:          '$DotNetMinorVersion'"
Write-Host "    ForceBuildWithDotNetVersion: '$ForceBuildWithDotNetVersion'"
Write-Host " "


##########
## Test: .NET version is installed
##########
# act
try {
    $dotnetVersion = & dotnet --version
    $major = ($dotnetVersion.Split('.'))[0] -as [int]
    $minor = ($dotnetVersion.Split('.'))[1] -as [int]
}
catch {
    throw "[FAIL] Can't get installed .NET version: $_"
}

# assert
if ($major -eq $DotNetMajorVersion -and $minor -eq $DotNetMinorVersion) {
    # active version matches, so always OK
    Write-Host "[OK] .NET $dotnetVersion is active."
}
elseif ($ForceBuildWithDotNetVersion -eq 'false') {
    # if we don't force the build to use the selected version, it only needs to be installed.

    try {
        $sdks = & dotnet --list-sdks
    }
    catch {
        throw "[FAIL] Can't list installed .NET SDKs: $_"
    }

    $matchingSdk = $sdks | Where-Object { $_ -like "$DotNetMajorVersion.$DotNetMinorVersion.*" }

    if ($matchingSdk) {
        Write-Host "[OK] .NET $DotNetMajorVersion.$DotNetMinorVersion.x is installed (but will be built using $major.$minor.x)."
    }
    else {
        throw "[FAIL] Expected .NET $DotNetMajorVersion.$DotNetMinorVersion.x to be installed, but it was not found. Installed SDKs:`n$sdks"
    }

}
else {
    throw "[FAIL] Expected .NET $DotNetMajorVersion.$DotNetMinorVersion.x to be active, but found version '$dotnetVersion'."
}

Write-Host " "


##########
## Test: reference assemblies are correct
##########
& "$PSScriptRoot/test-add-reference-assemblies.ps1"
