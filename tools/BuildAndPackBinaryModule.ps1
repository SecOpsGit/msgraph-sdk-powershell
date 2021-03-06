# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Param(
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string] $Module,
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string] $ModuleNamespace,
    [Parameter(ParameterSetName = "GraphResource")] [ValidateNotNullOrEmpty()][string] $GraphVersion,
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string] $ArtifactsLocation,
    [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()][string] $ModuleVersion,
    [int] $ModulePreviewNumber = -1,
    [string[]] $RequiredModules
)
$ErrorActionPreference = "Stop"
if($PSEdition -ne "Core") {
  Write-Error "This script requires PowerShell Core to execute. [Note] Generated cmdlets will work in both PowerShell Core or Windows PowerShell."
}

$NuspecHelperPS1 = Join-Path $PSScriptRoot "./NuspecHelper.ps1"
$ModuleProjLocation = Join-Path $PSScriptRoot "../src/$Module/$Module"
if($PSCmdlet.ParameterSetName -eq "GraphResource"){
    $ModuleProjLocation = Join-Path $PSScriptRoot "../src/$GraphVersion/$Module/$Module"
}
$BuildModulePS1 = Join-Path $ModuleProjLocation "/build-module.ps1"
$PackModulePS1 = Join-Path $ModuleProjLocation "/pack-module.ps1"
$ModuleManifest = Join-Path $ModuleProjLocation "$ModuleNamespace.$Module.psd1"
$ModuleNuspec = Join-Path $ModuleProjLocation "$ModuleNamespace.$Module.nuspec"
[HashTable] $NuspecMetadata = Get-Content (Join-Path $PSScriptRoot "..\config\ModuleMetadata.json") | ConvertFrom-Json -AsHashTable

# Import scripts
. $NuspecHelperPS1

if (-not (Test-Path -Path $BuildModulePS1)){
    Write-Error "Build script file '$BuildModulePS1' not found for '$Module' module."
}

# Build module
Write-Host -ForegroundColor Green "Building '$Module' module..."
& $BuildModulePS1 -Docs -Release
if($LastExitCode -ne 0) {
    Write-Error "Failed to build '$Module' module."
}

[HashTable]$ModuleManifestSettings = @{
    Path = $ModuleManifest
    FunctionsToExport = "*"
    ModuleVersion = $ModuleVersion
    IconUri = $NuspecMetadata["iconUri"]
}
$FullVersionNumber = $ModuleVersion

if($ModulePreviewNumber -ge 0){
    if($RequiredModules.Count -gt 0) {
        # Prerelease is only supported in PowerShell 7 (preview) and above.
        $ModuleManifestSettings["RequiredModules"] = $RequiredModules
        $ModuleManifestSettings["Prerelease"] = "preview$ModulePreviewNumber"
    } else {
        $ModuleManifestSettings["Prerelease"] = "preview$ModulePreviewNumber"
    }
    $FullVersionNumber = "$ModuleVersion-preview$ModulePreviewNumber"
} else {
    if($RequiredModules.Count -gt 0) {
        $ModuleManifestSettings["RequiredModules"] = $RequiredModules
    }
}

Write-Host -ForegroundColor Green "Updating '$Module' module manifest and nuspec..."
Update-ModuleManifest @ModuleManifestSettings
Set-NuSpecValues -NuSpecFilePath $ModuleNuspec -VersionNumber $FullVersionNumber -Dependencies $RequiredModules -IconUrl $NuspecMetadata["iconUri"]

# Pack module
& $PackModulePS1
if($LastExitCode -ne 0) {
    Write-Error "Failed to pack '$Module' module."
}

# Get generated .nupkg
$NuGetPackage = (Get-ChildItem (Join-Path $ModuleProjLocation "./bin") | Where-Object Name -Match ".nupkg").FullName

$ModuleArtifactLocation = "$ArtifactsLocation\$Module"
if(-not (Test-Path $ModuleArtifactLocation)) {
    New-Item -Path $ModuleArtifactLocation -Type Directory
} else {
    Remove-Item -Path "$ModuleArtifactLocation\*" -Recurse -Force
}

# Copy package to artifacts folder.
Write-Host -ForegroundColor Green "Copying '$NuGetPackage' to $ModuleArtifactLocation..."
Copy-Item -Path $NuGetPackage -Destination $ModuleArtifactLocation -Force

Write-Host -ForegroundColor Green "-------------Done-------------"