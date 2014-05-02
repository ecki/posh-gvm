﻿. .\Utils.ps1
. .\TestUtils.ps1

Describe 'Get-GVM-API-Version' {
    Context 'No cached version' {
        $Script:PGVM_VERSION_PATH = 'TestDrive:version.txt'

        It 'returns `$null' {
            Get-GVM-API-Version | Should Be $null
        }
    }

    Context 'No cached version' {
        $Script:PGVM_VERSION_PATH = 'TestDrive:version.txt'
        Set-Content $Script:PGVM_VERSION_PATH '1.1.1'

        It 'returns $null' {
            Get-GVM-API-Version | Should Be 1.1.1
        }
    }
}

Describe 'Check-Available-Broadcast' {
    Context 'Last execution was online, still online' {
        $Script:PGVM_VERSION = '1.2.3'
        $Script:GVM_ONLINE = $true
        $Script:GVM_AVAILABLE = $true
        Mock Invoke-API-Call { 'Broadcast message' } -parameterFilter { $Path -eq 'broadcast/1.2.3' -and $IgnoreFailure } 
        Mock Handle-Broadcast -verifiable -parameterFilter { $Command -eq $null -and $Broadcast -eq 'Broadcast message' }
        Mock Write-Offline-Broadcast
        Mock Write-Online-Broadcast

        Check-Available-Broadcast

        It 'does not announce any mode changes' {
            Assert-MockCalled Write-Offline-Broadcast 0
            Assert-MockCalled Write-Online-Broadcast 0
        }

        It 'calls Handle-Broadcast' {
            Assert-VerifiableMocks
        }
    }

    Context 'Last execution was online, now offline' {
        $Script:PGVM_VERSION = '1.2.4'
        $Script:GVM_ONLINE = $true
        $Script:GVM_AVAILABLE = $false
        Mock Invoke-API-Call { $null } -parameterFilter { $Path -eq 'broadcast/1.2.4' -and $IgnoreFailure } 
        Mock Handle-Broadcast
        Mock Write-Offline-Broadcast
        Mock Write-Online-Broadcast

        Check-Available-Broadcast

        It 'does announce offline mode' {
            Assert-MockCalled Write-Offline-Broadcast 1
            Assert-MockCalled Write-Online-Broadcast 0
        }

        It 'does not call Handle-Broadcast' {
            Assert-MockCalled Handle-Broadcast 0
        }
    }

    Context 'Last execution was offline, still offline' {
        $Script:PGVM_VERSION = '1.2.4'
        $Script:GVM_ONLINE = $false
        $Script:GVM_AVAILABLE = $false
        Mock Invoke-API-Call { $null } -parameterFilter { $Path -eq 'broadcast/1.2.4' -and $IgnoreFailure } 
        Mock Handle-Broadcast
        Mock Write-Offline-Broadcast
        Mock Write-Online-Broadcast

        Check-Available-Broadcast

        It 'does not announce any mode changes' {
            Assert-MockCalled Write-Offline-Broadcast 0
            Assert-MockCalled Write-Online-Broadcast 0
        }

        It 'does not call Handle-Broadcast' {
            Assert-MockCalled Handle-Broadcast 0
        }
    }

    Context 'Last execution was offline, now online' {
        $Script:PGVM_VERSION = '1.2.5'
        $Script:GVM_ONLINE = $false
        $Script:GVM_AVAILABLE = $true
         Mock Invoke-API-Call { 'Broadcast message' } -parameterFilter { $Path -eq 'broadcast/1.2.5' -and $IgnoreFailure } 
        Mock Handle-Broadcast -verifiable -parameterFilter { $Command -eq $null -and $Broadcast -eq 'Broadcast message' }
        Mock Write-Offline-Broadcast
        Mock Write-Online-Broadcast

        Check-Available-Broadcast

        It 'does announce online mode' {
            Assert-MockCalled Write-Offline-Broadcast 0
            Assert-MockCalled Write-Online-Broadcast 1
        }

        It 'calls Handle-Broadcast' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Invoke-Self-Update' {
    Context 'Selfupdate will be triggered' {
        Mock Write-Output -verifiable -parameterFilter { $InputObject -eq 'The self-update feature of posh-gvm does not match gvm selfupdate.'}
        Mock Write-Output -verifiable -parameterFilter { $InputObject -eq 'Only the update of the candidate list is supported currently.'}
        Mock Update-Candidates-Cache -verifiable

        Invoke-Self-Update

        It 'updates the candidate cache' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Check-Candidate-Present checks if candidate parameter is valid' {
	It 'throws anerror if no candidate is provided' {
		{ Check-Candidate-Present } | Should Throw
	}

    $Script:GVM_CANDIDATES = @('grails','groovy')
    It 'throws error if candidate unknown' {
        { Check-Candidate-Present java } | Should Throw
    }

    It 'throws no error if candidate known' {
        { Check-Candidate-Present groovy } | Should Not Throw
    }
}

Describe 'Check-Candidate-Version-Available select or vadidates a version for a candidate' {
    Context 'When grails version 1.1.1 is locally available' {
        Mock-Check-Candidate-Grails
        Mock-Grails-1.1.1-Locally-Available $true
        
        $result = Check-Candidate-Version-Available grails 1.1.1

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }

        It 'returns the 1.1.1' {
            $result | Should Be 1.1.1
        }
    }

    Context 'When gvm is offline and the provided version is not locally available' {
        Mock-Check-Candidate-Grails 
        Mock-Offline    
        Mock-Grails-1.1.1-Locally-Available $false

        It 'throws an error' {
            { Check-Candidate-Version-Available grails 1.1.1 } | Should Throw
        }

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }
    }

    Context 'When gvm is offline and no version is provided but there is a current version' {
        Mock-Check-Candidate-Grails     
        Mock-Offline
        Mock-Current-Grails-1.2

        $result = Check-Candidate-Version-Available grails

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }

        It 'returns the current version' {
            $result | Should Be 1.2
        }
    }

    Context 'When gvm is offline and no version is provided and no current version is defined' {
        Mock-Check-Candidate-Grails      
        Mock-Offline
        Mock-No-Current-Grails

        It 'throws an error' {
            { Check-Candidate-Version-Available grails } | Should Throw
        }

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }
    }

    Context 'When gvm is online and no version is provided' {
        Mock-Check-Candidate-Grails      
        Mock-Online
        Mock-Api-Call-Default-Grails-2.2

        $result = Check-Candidate-Version-Available grails

        It 'the API default is returned' {
            $result | Should Be 2.2
        }

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }
    }

    Context 'When gvm is online and the provided version is valid' {
        Mock-Check-Candidate-Grails      
        Mock-Online
        Mock-Api-Call-Grails-1.1.1-Available $true

        $result = Check-Candidate-Version-Available grails 1.1.1

        It 'returns the version' {
            $result | Should Be 1.1.1
        }

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }
    }

    Context 'When gvm is online and the provided version is invalid' {
        Mock-Check-Candidate-Grails      
        Mock-Online
        Mock-Api-Call-Grails-1.1.1-Available $false

        It 'throws an error' {
            { Check-Candidate-Version-Available grails 1.1.1 } | Should Throw
        }

        It 'check candidate parameter' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Get-Current-Candidate-Version reads the currently linked version' {
    Context 'When current is not defined' {
        Mock-PGVM-Dir

        It 'returns $null if current not defined' {
            Get-Current-Candidate-Version grails | Should Be $null
        }

        Reset-PGVM-DIR
    }

    Context 'When current is defined' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\2.2.2" | Out-Null
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\current" "$Global:PGVM_DIR\grails\2.2.2"

        It 'returns the liked version' {
            Get-Current-Candidate-Version grails | Should Be 2.2.2
        }

        Reset-PGVM-Dir
    }
}

Describe 'Get-Env-Candidate-Version reads the version set in $Candidate-Home' {
    Context 'When GRAILS_HOME is set to a specific version' { 
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\2.2.1" | Out-Null
        Mock-Grails-Home 2.2.1
         
        It 'returns the set version' {
            Get-Env-Candidate-Version grails | Should Be 2.2.1
        }

        Reset-Grails-Home
        Reset-PGVM-Dir
    }

    Context 'When GRAILS_HOME is set to current' { 
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\2.2.1" | Out-Null
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\current" "$Global:PGVM_DIR\grails\2.2.1"

        Mock-Grails-Home current
         
        It 'returns the version linked to current' {
            Get-Env-Candidate-Version grails | Should Be 2.2.1
        }

        Reset-Grails-Home
        Reset-PGVM-Dir
    }
}

Describe 'Check-Candidate-Version-Locally-Available throws error message if not available' {
    Context 'Version not available' {
        Mock-Grails-1.1.1-Locally-Available $false
        It 'throws an error' {
            { Check-Candidate-Version-Locally-Available grails 1.1.1 } | Should Throw
        }
    }

    Context 'Version is available' {
        Mock-Grails-1.1.1-Locally-Available $true

        It 'not throws any error' {
            { Check-Candidate-Version-Locally-Available grails 1.1.1 } | Should Not Throw
        }
    }
}

Describe 'Is-Candidate-Version-Locally-Available check the path exists' {
    Context 'No version provided' {
        it 'returns $false' {
            Is-Candidate-Version-Locally-Available grails | Should Be $false
        }
    }

    Context 'COC path for grails 1.1.1 is missing' {
        Mock-PGVM-Dir

        it 'returns $false' {
            Is-Candidate-Version-Locally-Available grails 1.1.1 | Should Be $false
        }

        Reset-PGVM-Dir
    }

    Context 'COC path for grails 1.1.1 exists' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.1.1" | Out-Null

        it 'returns $true' {
            Is-Candidate-Version-Locally-Available grails 1.1.1 | Should Be $true
        }

        Reset-PGVM-Dir
    }
}

Describe 'Get-Installed-Candidate-Version-List' {
    Context 'Version 1.1, 1.3.7 and 2.2.1 of grails installed' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.1" | Out-Null
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.3.7" | Out-Null
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\2.2.1" | Out-Null
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\current" "$Global:PGVM_DIR\grails\2.2.1"

        It 'returns list of installed versions' {
            Get-Installed-Candidate-Version-List grails | Should Be 1.1,1.3.7,2.2.1
        }

        Reset-PGVM-Dir
    }
}

Describe 'Set-Env-Candidate-Version' {
    Context 'Env-Version of grails is current' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.3.7" | Out-Null
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\2.2.1" | Out-Null
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\current" "$Global:PGVM_DIR\grails\2.2.1"
        Mock-Grails-Home current
        $backupPATH = $env:Path

        Set-Env-Candidate-Version grails 1.3.7

        It 'sets GRAILS_HOME' {
            $env:GRAILS_HOME -eq "$Global:PGVM_DIR\grails\1.3.7"
        }

        It 'extends the Path' {
            $env:Path -eq "$Global:PGVM_DIR\grails\1.3.7\bin"
        }

        $env:Path = $backupPATH
        Reset-Grails-Home
        Reset-PGVM-Dir
    }
}

Describe 'Set-Linked-Candidate-Version' {
    Context 'In a initialized PGVM-Dir' {
        Mock-PGVM-Dir
        Mock Set-Junction-Via-Mklink -verifiable -parameterFilter { $Candidate -eq 'grails' -and $Version -eq '2.2.1' }

        Set-Linked-Candidate-Version grails 2.2.1

        It 'calls Set-Junction-Via-Mklink with the correct paths' {
            Assert-VerifiableMocks
        }

        Reset-PGVM-Dir
    }
}

Describe 'Set-Junction-Via-Mklink' {
    Context 'No junction for the link-path exists' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.3.7" | Out-Null

        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\bla" "$Global:PGVM_DIR\grails\1.3.7"

        It 'creates a junction to the target location' {
            (Get-Item (Get-Item "$Global:PGVM_DIR\grails\bla").ReparsePoint.Target).FullName -eq "$Global:PGVM_DIR\grails\1.3.7"
        }

        (Get-Item "$Global:PGVM_DIR\grails\bla").Delete()
        Reset-PGVM-Dir
    }

    Context 'A Junction for the link-path exists' {
        Mock-PGVM-Dir
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.3.7" | Out-Null
        New-Item -ItemType Directory "$Global:PGVM_DIR\grails\1.3.8" | Out-Null
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\bla" "$Global:PGVM_DIR\grails\1.3.8"
        Set-Junction-Via-Mklink "$Global:PGVM_DIR\grails\bla" "$Global:PGVM_DIR\grails\1.3.7"

        It 'creates a junction to the target location without errors' {
            (Get-Item (Get-Item "$Global:PGVM_DIR\grails\bla").ReparsePoint.Target).FullName -eq "$Global:PGVM_DIR\grails\1.3.7"
        }

        (Get-Item "$Global:PGVM_DIR\grails\bla").Delete()
        Reset-PGVM-Dir
    }
}

Describe 'Get-Online-Mode check the state variables for GVM-API availablitiy and for force offline mode' {
    Context 'GVM-Api unavailable but may be connected' {
        $Script:GVM_AVAILABLE = $false
        $Script:GVM_FORCE_OFFLINE = $false

        It 'returns $false' {
            Get-Online-Mode | Should Be $false
        }
    }
    
    Context 'GVM-Api unavailable and may not be connected' {
        $Script:GVM_AVAILABLE = $false
        $Script:GVM_FORCE_OFFLINE = $true

        It 'returns $false' {
            Get-Online-Mode | Should Be $false
        }
    }
    
    Context 'GVM-Api is available and may not be connected' {
        $Script:GVM_AVAILABLE = $true
        $Script:GVM_FORCE_OFFLINE = $true

        It 'returns $false' {
            Get-Online-Mode | Should Be $false
        }
    }
    
    Context 'GVM-Api is available and may be connected' {
        $Script:GVM_AVAILABLE = $true
        $Script:GVM_FORCE_OFFLINE = $false

        It 'returns $true' {
            Get-Online-Mode | Should Be $true
        }
    }
}


Describe 'Check-Online-Mode throws an error when offline' {
    Context 'Offline' {
        Mock-Offline

        It 'throws an error' {
            { Check-Online-Mode } | Should Throw
        }
    }

    Context 'Online' {
        Mock-Online

        It 'throws no error' {
            { Check-Online-Mode } | Should Not Throw
        }
    }
}

Describe 'Invoke-API-Call helps doing calls to the GVM-API' {
    Context 'Successful API call only with API path' {
        $Script:PGVM_SERVICE = 'blub'
        Mock Invoke-RestMethod { 'called' } -parameterFilter { $Uri -eq 'blub/na/rock' }

        It 'returns the result from Invoke-RestMethod' {
            Invoke-API-Call 'na/rock' | Should Be 'called'
        }
    }

    Context 'Failed API call only with API path' {
        $Script:PGVM_SERVICE = 'blub'
        $Script:GVM_AVAILABLE = $true
        Mock Invoke-RestMethod { throw 'error' } -parameterFilter { $Uri -eq 'blub/na/rock' }
        Mock Check-Online-Mode -verifiable

        Invoke-API-Call 'na/rock'

        It 'sets GVM_AVAILABLE to false' {
            $Script:GVM_AVAILABLE | Should Be $false
        }

        It 'calls Check-Online-Mode which throws an error' {
            Assert-VerifiableMocks
        }
    }

    Context 'Failed API call with API path and IgnoreFailure' {
        $Script:PGVM_SERVICE = 'blub'
        $Script:GVM_AVAILABLE = $true
        Mock Invoke-RestMethod { throw 'error' } -parameterFilter { $Uri -eq 'blub/na/rock' }
        Mock Check-Online-Mode

        Invoke-API-Call 'na/rock' -IgnoreFailure

        It 'sets GVM_AVAILABLE to false' {
            $Script:GVM_AVAILABLE | Should Be $false
        }

        It 'do not call Check-Online-Mode' {
            Assert-MockCalled Check-Online-Mode 0
        }
    }

    Context 'Successful API call with API path and FilePath' {
        $Script:PGVM_SERVICE = 'blub'
        Mock Invoke-RestMethod -verifiable -parameterFilter { $Uri -eq 'blub/na/rock' -and $OutFile -eq 'TestDrive:a.txt' }
        
        Invoke-API-Call 'na/rock' TestDrive:a.txt

        It 'calls Invoke-RestMethod with file path' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Cleanup-Directory' {
    Context 'Directory with subdirectories and files' {
        New-Item -ItemType Directory TestDrive:bla | Out-Null
        New-Item -ItemType Directory TestDrive:bla\a | Out-Null
        New-Item -ItemType Directory TestDrive:bla\b | Out-Null
        New-Item -ItemType File TestDrive:bla\c | Out-Null
        New-Item -ItemType File TestDrive:bla\a\a | Out-Null

        Mock Write-Output -verifiable -parameterFilter { $InputObject -eq '2 archive(s) flushed, freeing 0 MB' }

        Cleanup-Directory TestDrive:bla

        It 'Cleans the Test-Path file' {
            Test-Path TestDrive:bla | Should Be $False
        }

        It 'Write info to host' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Handle-Broadcast' {
    Context 'Cache broadcast message different than new broadcast' {
        Mock-PGVM-Dir
        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Set-Content $Script:PGVM_BROADCAST_PATH 'Old Broadcast message'
        Mock Write-Output -verifiable -parameterFilter { $InputObject -eq 'New Broadcast message' }

        Handle-Broadcast list 'New Broadcast message'

        It 'outputs the broadcast message' {
            Assert-VerifiableMocks
        }

        It 'sets the new broadcast message in file' {
            Get-Content $Script:PGVM_BROADCAST_PATH | Should Be 'New Broadcast message'
        }


        Reset-PGVM-Dir
    }

    Context 'No cached broadcast message' {
        Mock-PGVM-Dir

        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Mock Write-Output -verifiable -parameterFilter { $InputObject -eq 'New Broadcast message' }

        Handle-Broadcast list 'New Broadcast message'

        It 'outputs the broadcast message' {
            Assert-VerifiableMocks
        }

        It 'sets the new broadcast message in file' {
            Get-Content $Script:PGVM_BROADCAST_PATH | Should Be 'New Broadcast message'
        }

        Reset-PGVM-Dir
    }

    Context 'b do not print the new broadcast message' {
        Mock-PGVM-Dir

        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Mock Write-Output -verifiable

        Handle-Broadcast b 'New Broadcast message'

        It 'no Broadcast' {
            Assert-MockCalled Write-Output 0
        }

        It 'sets the new broadcast message in file' {
            Test-Path $Script:PGVM_BROADCAST_PATH | Should Be $false
        }

        Reset-PGVM-Dir
    }

    Context 'Broadcast do nOt print the new broadcast message' {
        Mock-PGVM-Dir

        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Mock Write-Output -verifiable

        Handle-Broadcast broadcast 'New Broadcast message'

        It 'no Broadcast' {
            Assert-MockCalled Write-Output 0
        }

        It 'sets the new broadcast message in file' {
            Test-Path $Script:PGVM_BROADCAST_PATH | Should Be $false
        }

        Reset-PGVM-Dir
    }

    Context 'selfupdate do not print the new broadcast message' {
        Mock-PGVM-Dir

        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Mock Write-Output -verifiable

        Handle-Broadcast selfupdate 'New Broadcast message'

        It 'no Broadcast' {
            Assert-MockCalled Write-Output 0
        }

        It 'sets the new broadcast message in file' {
            Test-Path $Script:PGVM_BROADCAST_PATH | Should Be $false
        }

        Reset-PGVM-Dir
    }

    Context 'flush do not print the new broadcast message' {
        Mock-PGVM-Dir

        $Script:PGVM_BROADCAST_PATH = "$Global:PGVM_DIR\broadcast.txt"
        Mock Write-Output -verifiable

        Handle-Broadcast flush 'New Broadcast message'

        It 'no Broadcast' {
            Assert-MockCalled Write-Output 0
        }

        It 'sets the new broadcast message in file' {
            Test-Path $Script:PGVM_BROADCAST_PATH | Should Be $false
        }

        Reset-PGVM-Dir
    }
}

Describe 'Init-Candidate-Cache' {
    Context 'Candidate cache file does not exists' {
        Mock-PGVM-Dir
        $Script:PGVM_CANDIDATES_PATH = "$Global:PGVM_DIR\candidates.txt"

        It 'throws an error' {
            { Init-Candidate-Cache } | Should Throw
        }

        Reset-PGVM-Dir
    }

    Context 'Candidate cache file does exists' {
        Mock-PGVM-Dir
        $Script:PGVM_CANDIDATES_PATH = "$Global:PGVM_DIR\candidates.txt"
        Set-Content $Script:PGVM_CANDIDATES_PATH 'grails,groovy,test'
        $Script:GVM_CANDIDATES = $null

        Init-Candidate-Cache

        It 'sets `$Script:GVM_CANDIDATES' {
            $Script:GVM_CANDIDATEs | Should Be grails,groovy,test
        }

        Reset-PGVM-Dir
    }
}

Describe 'Update-Candidate-Cache' {
    Context 'Checks online mode and than get version and candidates from api' {
        Mock-PGVM-Dir

        $Script:PGVM_VERSION_PATH = "$Global:PGVM_DIR\version.txt"
        $Script:PGVM_CANDIDATES_PATH = "$Global:PGVM_DIR\candidates.txt"

        Mock Check-Online-Mode -verifiable
        Mock Invoke-API-Call -verifiable -parameterFilter { $Path -eq '/app/version' -and $FileTarget -eq "$Global:PGVM_DIR\version.txt" }
        Mock Invoke-API-Call -verifiable -parameterFilter { $Path -eq '/candidates' -and $FileTarget -eq "$Global:PGVM_DIR\candidates.txt" }

        Update-Candidates-Cache

        It 'calls the Check-Online-Mode and two API paths' {
            Assert-VerifiableMocks
        }

        Reset-PGVM-Dir
    }
}

Describe 'Write-Offline-Version-List' {
    Context 'no versions of grails installed' {
        Mock Write-Output
        Mock Get-Current-Candidate-Version { $null } -parameterFilter { $Candidate -eq 'grails' }
        Mock Get-Installed-Candidate-Version-List { $null } -parameterFilter { $Candidate -eq 'grails' }

        Write-Offline-Version-List grails

        It 'Outputs 11 lines' {
            Assert-MockCalled Write-Output 9
        }
    }

    Context 'Three versions of grails installed' {
        Mock Write-Output
        Mock Get-Current-Candidate-Version { 1.1.1 } -parameterFilter { $Candidate -eq 'grails' }
        Mock Get-Installed-Candidate-Version-List { 1.1.1,2.2.2,2.3.0 } -parameterFilter { $Candidate -eq 'grails' }

        Write-Offline-Version-List grails

        It 'Outputs 11 lines' {
            Assert-MockCalled Write-Output 11
        }
    }
}

Describe 'Write-Version-List' {
    Context 'Three versions of grails installed' {
        Mock Write-Output
        Mock Get-Current-Candidate-Version { '1.1.1' } -parameterFilter { $Candidate -eq 'grails' }
        Mock Get-Installed-Candidate-Version-List { return '1.1.1','2.2.2','2.3.0' } -parameterFilter { $Candidate -eq 'grails' }
        Mock Invoke-API-Call { 'bla' } -parameterFilter { $Path -eq 'candidates/grails/list?current=1.1.1&installed=1.1.1,2.2.2,2.3.0' }

        Write-Version-List grails

        It 'writes to host' {
            Assert-MockCalled Write-Output 1
        }
    }
}

Describe 'Install-Local-Version' {
    Context 'LocalPath is no directory' {
        New-Item -ItemType File TestDrive:a.txt | Out-Null

        It 'throws an error' {
            { Install-Local-Version grails snapshot TestDrive:a.txt } | Should Throw
        }
    }

    Context 'LocalPath is valid' {
        New-Item -ItemType Directory TestDrive:Snapshot | Out-Null
        Mock Write-Output
        Mock Set-Junction-Via-Mklink -verifiable -parameterFilter { $Link -eq "$Global:PGVM_DIR\grails\snapshot" -and $Target -eq 'TestDrive:Snapshot' } 
        
        Install-Local-Version grails snapshot TestDrive:Snapshot

        It 'creates junction for candidate version' {
            Assert-VerifiableMocks
        }
    }
}

Describe 'Install-Remote-Version' {
    Context 'Install of a valid version without local archive' {
        Mock-PGVM-Dir
        
        Mock Write-Output
        Mock Check-Online-Mode -verifiable

        $Script:PGVM_ARCHIVES_PATH = "$Global:PGVM_DIR\archives"
        $Script:PGVM_TEMP_PATH = "$Global:PGVM_DIR\temp"
        
        Mock Download-File -verifiable { Copy-Item "$PSScriptRoot\test\grails-1.3.9.zip" "$Script:PGVM_ARCHIVES_PATH\grails-1.3.9.zip" }

        Install-Remote-Version grails 1.3.9

        It 'downloads the archive' {
            Assert-VerifiableMocks
        }

        It 'install it correctly' {
            Test-Path "$Global:PGVM_DIR\grails\1.3.9\bin\grails" | Should be $true
        }

        Reset-PGVM-DIR
    }

    Context 'Install of a valid version with local archive' {
        Mock-PGVM-Dir
        
        Mock Write-Output
        Mock Download-File

        $Script:PGVM_ARCHIVES_PATH = "$Global:PGVM_DIR\archives"
        $Script:PGVM_TEMP_PATH = "$Global:PGVM_DIR\temp"
        New-Item -ItemType Directory $Script:PGVM_ARCHIVES_PATH | Out-Null
        Copy-Item "$PSScriptRoot\test\grails-1.3.9.zip" "$Script:PGVM_ARCHIVES_PATH\grails-1.3.9.zip"

        Install-Remote-Version grails 1.3.9

        It 'does not download the archive again' {
            Assert-MockCalled Download-File 0
        }

        It 'install it correctly' {
            Test-Path "$Global:PGVM_DIR\grails\1.3.9\bin\grails" | Should be $true
        }

        Reset-PGVM-DIR
    }

    Context 'Install of a currupt archive' {
        Mock-PGVM-Dir
        
        Mock Write-Output
        Mock Download-File

        $Script:PGVM_ARCHIVES_PATH = "$Global:PGVM_DIR\archives"
        $Script:PGVM_TEMP_PATH = "$Global:PGVM_DIR\temp"
        New-Item -ItemType Directory $Script:PGVM_ARCHIVES_PATH | Out-Null
        Copy-Item "$PSScriptRoot\test\grails-2.2.2.zip" "$Script:PGVM_ARCHIVES_PATH\grails-2.2.2.zip"

        It 'fails because of no unziped files' {
            {  Install-Remote-Version grails 2.2.2 } | Should Throw
        }

        It 'does not download the archive again' {
            Assert-MockCalled Download-File 0
        }

        Reset-PGVM-DIR
    }
}