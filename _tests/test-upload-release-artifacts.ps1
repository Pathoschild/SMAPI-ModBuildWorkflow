<#
.SYNOPSIS
    Integration tests for the `upload-release-artifacts` action. These are run on each commit to this repo.

    This assumes that the script was run on the releases structure created by `_tests/utilities/create-releases-folder.ps1`.

.PARAMETER FolderName
    The path to the folder containing release zips that were uploaded. Default '_releases'.

.PARAMETER CreateCombinedZip
    The name of a combined zip file to create containing all the mod zips, or omit to disable.

.PARAMETER AttestationId
    The expected value of the `attestation-id` output variable.

.PARAMETER AttestationUrl
    The expected value of the `attestation-url` output variable.

.PARAMETER AttestationBundlePath
    The expected value of the `attestation-bundle-path` output variable.
#>
param(
    [string] $FolderName = '_releases',
    [string] $CreateCombinedZip = '',
    [string] $AttestationId = '',
    [string] $AttestationUrl = '',
    [string] $AttestationBundlePath = ''
)


##########
## Set up
##########
Write-Host "Running tests for upload-release-artifacts:"
Write-Host "    FolderName:            '$FolderName'"
Write-Host "    CreateCombinedZip:     '$CreateCombinedZip'"
Write-Host "    AttestationId:         '$AttestationId'"
Write-Host "    AttestationUrl:        '$AttestationUrl'"
Write-Host "    AttestationBundlePath: '$AttestationBundlePath'"
Write-Host " "


##########
## Test: test folder was created
##########
if (!(Test-Path -Path $FolderName -PathType Container)) {
    throw @"
        [FAIL] Expected folder '$FolderName' not found.

        Root contents:
        $(Get-ChildItem | ForEach-Object { "`n    - $($_.Name)" })
"@
}

foreach ($fileName in @('StableMod 1.0.1-alpha.1.zip', 'BetaMod 2.2.3-alpha.1.zip')) {
    $filePath = "$FolderName/$fileName"
    if (!(Test-Path -Path $filePath -PathType Leaf)) {
        throw @"
            [FAIL] Expected file '$filePath' not found.

            Folder contents:
            $(Get-ChildItem $FolderName | ForEach-Object { "`n    - $($_.Name)" })
"@
    }
}


##########
## Test: output variables were set
##########
$outputs = @{
    'attestation-id'          = $AttestationId
    'attestation-url'         = $AttestationUrl
    'attestation-bundle-path' = $AttestationBundlePath
}

foreach ($outputName in $outputs.Keys) {
    $value = $outputs[$outputName]

    if ($value) {
        Write-Host "[OK] Output field '$outputName' is set to '$value'."
    }
    else {
        throw "[FAIL] Expected output '$outputName' not set."
    }
}


##########
## Test: files were uploaded
##########
Write-Warning "[INCONCLUSIVE] Checking uploaded artifacts isn't supported."
