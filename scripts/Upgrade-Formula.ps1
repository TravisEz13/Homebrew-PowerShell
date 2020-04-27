# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
param(
    [Parameter(Mandatory)]
    [string]
    $FormulaPath,
    [ValidateSet('Stable', 'Preview', 'Lts', 'Daily')]
    [string]
    $Channel = 'Stable'
)

$retryCount = 3
$retryIntervalSec = 15

Switch ($Channel) {
    'Stable' {
        $metadata = Invoke-RestMethod 'https://aka.ms/pwsh-buildinfo-stable' -MaximumRetryCount $retryCount -RetryIntervalSec $retryIntervalSec
    }
    'Lts' {
        $metadata = Invoke-RestMethod 'https://aka.ms/pwsh-buildinfo-lts' -MaximumRetryCount $retryCount -RetryIntervalSec $retryIntervalSec
    }
    'Preview' {
        $metadata = Invoke-RestMethod 'https://aka.ms/pwsh-buildinfo-preview' -MaximumRetryCount $retryCount -RetryIntervalSec $retryIntervalSec
    }
    'Daily' {
        $metadata = Invoke-RestMethod 'https://aka.ms/pwsh-buildinfo-preview' -MaximumRetryCount $retryCount -RetryIntervalSec $retryIntervalSec
    }
    default {
        throw "Invalid channel: $Channel"
    }
}

$expectedVersion = $metadata.ReleaseTag -replace '^v'
Write-Verbose "Expected version: $expectedVersion" -verbose

$ErrorActionPreference = "stop"
$urlTemplate = 'https://github.com/PowerShell/PowerShell/releases/download/v{0}/powershell-{0}-osx-x64.tar.gz'

$formulaString = Get-Content -Path $FormulaPath
#'  version_scheme "7.0.0-preview.1"'
$versionSchemePattern = '^.\s*version_scheme\s*"([^"]*)"$'
$versionString = $formulaString | Select-String -Raw -Pattern $versionSchemePattern

Write-Verbose $versionString -verbose
if (! ($versionString -match '"(\d*\.\d*\.\d*(-\w*(\.\d*)?)?)"')) {
    throw "version not found"
}

$version = $Matches.1

$versionMatch = $version -eq $expectedVersion
Write-Verbose "version Match: $versionMatch" -Verbose
if ($versionMatch) {
    return
}

Write-Host "::set-env name=NEW_FORMULA_VERSION::$expectedVersion"

$url = $urlTemplate -f $expectedVersion
Write-Verbose "new url: $url" -Verbose

$urlPattern = '^.\s*url\s*"([^"]*)"$'
$urlString = $formulaString | Select-String -Raw -Pattern $urlPattern
Write-Verbose $urlString -Verbose

$newUrlString = $urlString -replace '"([^"]*)"', ('"{0}"' -f $url)
Write-Verbose $newUrlString -Verbose

$newVersionSchemeString = $versionString -replace '"([^"]*)"', ('"{0}"' -f $expectedVersion)
Write-Verbose $newVersionSchemeString -Verbose

$sha256Pattern = '^.\s*sha256\s*"([^"]*)"$'
$sha256String = $formulaString | Select-String -Raw -Pattern $sha256Pattern
Write-Verbose $sha256String -Verbose
Invoke-WebRequest -Uri $url -OutFile ./FileToHash.file

$hash = (Get-FileHash -Path ./FileToHash.file -Algorithm SHA256).Hash.ToLower()
Remove-Item ./FileToHash.file
Write-Verbose "hash: $hash"

$newSha256String = $sha256String -replace '"([^"]*)"', ('"{0}"' -f $hash)
Write-Verbose $newSha256String -Verbose

$newFormula = [System.Text.StringBuilder]::new($formulaString -join [System.Environment]::NewLine)

$null = $newFormula.Replace($versionString,$newVersionSchemeString)
$null = $newFormula.Replace($urlString,$newUrlString)
$null = $newFormula.Replace($sha256String,$newSha256String)

$newFormula.ToString() | Out-File -Encoding utf8NoBOM -FilePath $FormulaPath
