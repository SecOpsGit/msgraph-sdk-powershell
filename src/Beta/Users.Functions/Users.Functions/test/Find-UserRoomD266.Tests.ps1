$TestRecordingFile = Join-Path $PSScriptRoot 'Find-UserRoomD266.Recording.json'
$currentPath = $PSScriptRoot
while(-not $mockingPath) {
    $mockingPath = Get-ChildItem -Path $currentPath -Recurse -Include 'HttpPipelineMocking.ps1' -File
    $currentPath = Split-Path -Path $currentPath -Parent
}
. ($mockingPath | Select-Object -First 1).FullName

Describe 'Find-UserRoomD266' {
    It 'Find' -skip {
        { throw [System.NotImplementedException] } | Should -Not -Throw
    }

    It 'FindViaIdentity' -skip {
        { throw [System.NotImplementedException] } | Should -Not -Throw
    }
}
