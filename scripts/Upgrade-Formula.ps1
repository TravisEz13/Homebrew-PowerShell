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

function Get-FormulaString
{
    param(
        [Parameter(Mandatory)]
        [object[]]
        $OriginalFomula,

        [string]
        $Pattern,

        [Parameter(Mandatory)]
        [string]
        $PropertyName
    )

    if ($Pattern) {
        $actualPattern = $Pattern
    }
    else {
        $actualPattern = '^\s*{0}\s*"([^"]*)"$' -f $PropertyName
    }

    Write-Verbose "Finding $PropertyName uning $actualPattern" -Verbose

    return $OriginalFomula | Select-String -Raw -Pattern $actualPattern
}

$versionString = Get-FormulaString -OriginalFomula $formulaString -PropertyName 'version_scheme'

Write-Verbose $versionString -verbose
$versionPattern = '(\d*\.\d*\.\d*(-\w*(\.\d*)?)?)'
if (! ($versionString -match "`"$versionPattern`"")) {
    throw "version not found"
}

$version = $Matches.1

$versionMatch = $version -eq $expectedVersion
Write-Verbose "version Match: $versionMatch" -Verbose
if ($versionMatch) {
    return
}

function Update-Formula {
    param(
        [Parameter(Mandatory)]
        [object[]]
        $OriginalFomula,

        [Parameter(Mandatory)]
        [System.Text.StringBuilder]
        $CurrentFormula,

        [string]
        $Pattern,

        [Parameter(Mandatory)]
        [string]
        $NewValue,

        [Parameter(Mandatory)]
        [string]
        $PropertyName
    )

    $propertyString = Get-FormulaString -OriginalFomula $OriginalFomula -PropertyName $PropertyName -Pattern $Pattern
    if(!$propertyString)
    {
        throw "could not find $PropertyName"
    }

    Write-Verbose $propertyString -Verbose
    $newPropertyString = $propertyString -replace '"([^"]*)"', ('"{0}"' -f $NewValue)

    $null = $CurrentFormula.Replace($propertyString, $newPropertyString)
}

Write-Host "::set-env name=NEW_FORMULA_VERSION::$expectedVersion"

$url = $urlTemplate -f $expectedVersion
Write-Verbose "new url: $url" -Verbose

$newFormula = [System.Text.StringBuilder]::new($formulaString -join [System.Environment]::NewLine)

Update-Formula -PropertyName 'url' -CurrentFormula $newFormula -NewValue $url -OriginalFomula $formulaString


Update-Formula -PropertyName 'version_scheme' -CurrentFormula $newFormula -NewValue $expectedVersion -OriginalFomula $formulaString

#assert_equal "7.1.0-preview.1",
Update-Formula -PropertyName 'assert_equal_version' -CurrentFormula $newFormula -NewValue $expectedVersion -Pattern ('^\s*assert_equal\s*"{0}",$' -f $versionPattern)  -OriginalFomula $formulaString

Invoke-WebRequest -Uri $url -OutFile ./FileToHash.file

$hash = (Get-FileHash -Path ./FileToHash.file -Algorithm SHA256).Hash.ToLower()
Remove-Item ./FileToHash.file
Write-Verbose "hash: $hash"

Update-Formula -PropertyName 'sha256' -CurrentFormula $newFormula -NewValue $hash -OriginalFomula $formulaString

$null = $newFormula.Replace($versionString,$newVersionSchemeString)

$newFormula.ToString() | Out-File -Encoding utf8NoBOM -FilePath $FormulaPath
