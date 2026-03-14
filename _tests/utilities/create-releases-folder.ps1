<#
.SYNOPSIS
    Create a _releases folder with representative zip files.

    This creates two zip files matching what would be produced by the solution created by
    `_tests/utilities/create-solution.ps1`:
      - `StableMod 1.0.1-alpha.1.zip`;
      - `BetaMod 2.2.3-alpha.1.zip`.

.PARAMETER FolderName
    The name of the releases folder to create.
#>
param(
    [string] $FolderName = '_releases'
)

# create directory
New-Item -Path "$FolderName" -ItemType Directory | Out-Null

# create zips
function New-ZipFromContent([string] $zipPath, [string] $textContent) {
    if (Test-Path $zipPath) {
        throw "Can't create test file at path '$zipPath': file already exists"
    }

    Add-Type -AssemblyName System.IO.Compression

    $fileStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)

        $entry = $zip.CreateEntry('content.txt')
        $stream = $entry.Open()
        $writer = New-Object System.IO.StreamWriter($stream, $Encoding)

        try {
            $writer.Write($textContent)
        }
        finally {
            $writer.Dispose()
            $stream.Dispose()
        }
    }
    finally {
        $zip.Dispose()
        $fileStream.Dispose()
    }
}

New-ZipFromContent -zipPath "$FolderName/StableMod 1.0.1-alpha.1.zip" -textContent 'Example content A.'
New-ZipFromContent -zipPath "$FolderName/BetaMod 2.2.3-alpha.1.zip" -textContent 'Example content B.'
