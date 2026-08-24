# Runs on windows-tail from a complete stdin-backed PowerShell scriptblock.
#
# The default is deliberately read-only. The caller must prepend
# `$env:GAMING_STOP_MODE = "stop"` to opt into the shutdown path.
# Steam has no supported external "stop the current game" API, so this uses
# Steam's own non-forced +app_stop client command only after its registry,
# process log, and live process tree agree on one running AppID.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$SteamRegistryPath = 'HKCU:\Software\Valve\Steam'
$SteamAppsRegistryPath = Join-Path $SteamRegistryPath 'Apps'
$SteamActiveProcessPath = Join-Path $SteamRegistryPath 'ActiveProcess'
$Mode = if ([string]::IsNullOrWhiteSpace($env:GAMING_STOP_MODE)) {
    'probe'
}
else {
    $env:GAMING_STOP_MODE.ToLowerInvariant()
}

if ($Mode -notin @('probe', 'stop')) {
    throw "Unsupported GAMING_STOP_MODE: $Mode"
}

function Get-PropertyValue {
    param(
        [AllowNull()] [object] $InputObject,
        [Parameter(Mandatory)] [string] $Name,
        [AllowNull()] [object] $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $Property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $Property -or $null -eq $Property.Value) {
        return $DefaultValue
    }

    return $Property.Value
}

function Get-ProcessMap {
    param([Parameter(Mandatory)] [object[]] $Processes)

    $Map = @{}
    foreach ($Process in $Processes) {
        $Map[[int]$Process.ProcessId] = $Process
    }
    return $Map
}

function Get-DescendantIdSet {
    param(
        [Parameter(Mandatory)] [object[]] $Processes,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [int[]] $RootIds
    )

    $Ids = @{}
    foreach ($RootId in $RootIds) {
        $Ids[$RootId] = $true
    }

    do {
        $Added = $false
        foreach ($Process in $Processes) {
            $ProcessId = [int]$Process.ProcessId
            $ParentPid = [int]$Process.ParentProcessId
            if (-not $Ids.ContainsKey($ProcessId) -and $Ids.ContainsKey($ParentPid)) {
                $Ids[$ProcessId] = $true
                $Added = $true
            }
        }
    } while ($Added)

    return $Ids
}

function Get-RunningSteamApps {
    if (-not (Test-Path -LiteralPath $SteamAppsRegistryPath)) {
        return @()
    }

    $Apps = @()
    foreach ($AppKey in Get-ChildItem -LiteralPath $SteamAppsRegistryPath -ErrorAction Stop) {
        $App = Get-ItemProperty -LiteralPath $AppKey.PSPath -ErrorAction Stop
        if ([int](Get-PropertyValue $App 'Running' 0) -ne 1) {
            continue
        }

        $AppId = 0
        if (-not [int]::TryParse($AppKey.PSChildName, [ref]$AppId) -or $AppId -le 0) {
            continue
        }

        $Apps += [pscustomobject][ordered]@{
            AppId = $AppId
            Name = [string](Get-PropertyValue $App 'Name' "AppID $AppId")
        }
    }

    return @($Apps)
}

function Assert-NoSteamGameReported {
    param([Parameter(Mandatory)] [string] $Stage)

    # Re-read both independent registry signals at the decision point. If they
    # disagree or either still reports a game, fail closed instead of allowing
    # Steam/Moonlight shutdown around a potentially detached game process.
    $ReportedApps = @(Get-RunningSteamApps)
    $SteamState = Get-ItemProperty -LiteralPath $SteamRegistryPath -ErrorAction SilentlyContinue
    $ReportedAppId = [int](Get-PropertyValue $SteamState 'RunningAppID' 0)
    if ($ReportedApps.Count -gt 0 -or $ReportedAppId -ne 0) {
        throw "Steam still reports a running game $Stage (RunningAppID=$ReportedAppId, app keys=$($ReportedApps.Count))"
    }
}

function Get-TrackedProcessRecords {
    param(
        [Parameter(Mandatory)] [string] $LogPath,
        [Parameter(Mandatory)] [int] $AppId
    )

    $Tracked = @{}
    if (-not (Test-Path -LiteralPath $LogPath)) {
        return @()
    }

    foreach ($Line in Get-Content -LiteralPath $LogPath -ErrorAction Stop) {
        if ($Line -match 'AppID\s+(?<appid>\d+)\s+adding PID\s+(?<pid>\d+)\s+as a tracked process') {
            $MatchedAppId = [int]$Matches.appid
            $MatchedProcessId = [int]$Matches.pid
            if ($MatchedAppId -ne $AppId) {
                continue
            }

            $ExpectedPath = ''
            if ($Line -match 'tracked process\s+""(?<path>[^"]+\.exe)') {
                $ExpectedPath = $Matches.path
            }

            $Tracked[$MatchedProcessId] = [pscustomobject][ordered]@{
                AppId = $AppId
                Pid = $MatchedProcessId
                ExpectedPath = $ExpectedPath
            }
            continue
        }

        if ($Line -match 'AppID\s+(?<appid>\d+)\s+no longer tracking PID\s+(?<pid>\d+)') {
            if ([int]$Matches.appid -eq $AppId) {
                [void]$Tracked.Remove([int]$Matches.pid)
            }
            continue
        }

        if ($Line -match 'Remove\s+(?<appid>\d+)\s+from running list' -and [int]$Matches.appid -eq $AppId) {
            $Tracked.Clear()
        }
    }

    return @($Tracked.Values)
}

function Get-LiveTrackedRecords {
    param(
        [Parameter(Mandatory)] [object[]] $Records,
        [Parameter(Mandatory)] [hashtable] $ProcessMap,
        [Parameter(Mandatory)] [hashtable] $SteamDescendantIds
    )

    $Live = @()
    foreach ($Record in $Records) {
        if (-not $ProcessMap.ContainsKey([int]$Record.Pid)) {
            continue
        }

        $Process = $ProcessMap[[int]$Record.Pid]
        $ActualPath = [string](Get-PropertyValue $Process 'ExecutablePath' '')
        $PathMatches = -not [string]::IsNullOrWhiteSpace($Record.ExpectedPath) -and
            -not [string]::IsNullOrWhiteSpace($ActualPath) -and
            $ActualPath -ieq $Record.ExpectedPath
        $IsSteamDescendant = $SteamDescendantIds.ContainsKey([int]$Record.Pid)

        # Steam's log identifies the PID and executable. Process ancestry is a
        # second acceptable corroboration for launchers that obscure the path.
        if (-not $PathMatches -and -not $IsSteamDescendant) {
            continue
        }

        $Live += [pscustomobject][ordered]@{
            AppId = [int]$Record.AppId
            Pid = [int]$Process.ProcessId
            Name = [string]$Process.Name
            Path = $ActualPath
            CreationDate = ([datetime]$Process.CreationDate).ToString('o')
        }
    }

    return @($Live)
}

function Test-SameProcessAlive {
    param([Parameter(Mandatory)] [object] $Record)

    $Current = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Record.Pid)" -ErrorAction Stop
    if ($null -eq $Current) {
        return $false
    }

    $CurrentCreation = ([datetime]$Current.CreationDate).ToString('o')
    if ($CurrentCreation -ne $Record.CreationDate) {
        return $false
    }

    $CurrentPath = [string](Get-PropertyValue $Current 'ExecutablePath' '')
    if (-not [string]::IsNullOrWhiteSpace($Record.Path) -and
        -not [string]::IsNullOrWhiteSpace($CurrentPath) -and
        $CurrentPath -ine $Record.Path) {
        return $false
    }

    return $true
}

function Test-GameStopped {
    param(
        [Parameter(Mandatory)] [int] $AppId,
        [Parameter(Mandatory)] [object[]] $TrackedRecords
    )

    $App = Get-ItemProperty -LiteralPath (Join-Path $SteamAppsRegistryPath $AppId) -ErrorAction SilentlyContinue
    $AppStillRunning = $null -ne $App -and [int](Get-PropertyValue $App 'Running' 0) -eq 1

    $Steam = Get-ItemProperty -LiteralPath $SteamRegistryPath -ErrorAction SilentlyContinue
    $RunningAppId = [int](Get-PropertyValue $Steam 'RunningAppID' 0)
    $AnyTrackedProcessAlive = $false
    foreach ($Record in $TrackedRecords) {
        if (Test-SameProcessAlive $Record) {
            $AnyTrackedProcessAlive = $true
            break
        }
    }

    return -not $AppStillRunning -and $RunningAppId -ne $AppId -and -not $AnyTrackedProcessAlive
}

function Wait-Until {
    param(
        [Parameter(Mandatory)] [scriptblock] $Condition,
        [Parameter(Mandatory)] [int] $TimeoutSeconds
    )

    $Deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    } while ([datetime]::UtcNow -lt $Deadline)

    return [bool](& $Condition)
}

try {
    $Steam = Get-ItemProperty -LiteralPath $SteamRegistryPath -ErrorAction SilentlyContinue
    $ActiveProcess = Get-ItemProperty -LiteralPath $SteamActiveProcessPath -ErrorAction SilentlyContinue
    $SteamExeRaw = [string](Get-PropertyValue $Steam 'SteamExe' '')
    $SteamPathRaw = [string](Get-PropertyValue $Steam 'SteamPath' '')
    $RunningAppId = [int](Get-PropertyValue $Steam 'RunningAppID' 0)
    $ActiveSteamPid = [int](Get-PropertyValue $ActiveProcess 'pid' 0)

    $SteamExe = ''
    if (-not [string]::IsNullOrWhiteSpace($SteamExeRaw) -and (Test-Path -LiteralPath $SteamExeRaw)) {
        $SteamExe = (Get-Item -LiteralPath $SteamExeRaw -ErrorAction Stop).FullName
    }

    $SteamPath = ''
    if (-not [string]::IsNullOrWhiteSpace($SteamPathRaw) -and (Test-Path -LiteralPath $SteamPathRaw)) {
        $SteamPath = (Get-Item -LiteralPath $SteamPathRaw -ErrorAction Stop).FullName
    }

    $Processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    $ProcessMap = Get-ProcessMap $Processes
    $SteamProcesses = @($Processes | Where-Object { $_.Name -ieq 'steam.exe' })
    $SteamPids = @($SteamProcesses | ForEach-Object { [int]$_.ProcessId })
    $SteamDescendantIds = Get-DescendantIdSet $Processes $SteamPids
    $RunningApps = @(Get-RunningSteamApps)

    $SteamExeMatchesProcess = $false
    foreach ($SteamProcess in $SteamProcesses) {
        $ProcessPath = [string](Get-PropertyValue $SteamProcess 'ExecutablePath' '')
        if (-not [string]::IsNullOrWhiteSpace($SteamExe) -and $ProcessPath -ieq $SteamExe) {
            $SteamExeMatchesProcess = $true
            break
        }
    }

    $SteamSignatureTrusted = $false
    if (-not [string]::IsNullOrWhiteSpace($SteamExe)) {
        $Signature = Get-AuthenticodeSignature -LiteralPath $SteamExe -ErrorAction Stop
        $SignerSubject = if ($null -ne $Signature.SignerCertificate) {
            [string]$Signature.SignerCertificate.Subject
        }
        else {
            ''
        }
        $SteamSignatureTrusted = $Signature.Status -eq 'Valid' -and $SignerSubject -like '*Valve Corp*'
    }

    $TrackedRecords = @()
    $LiveTrackedRecords = @()
    if ($RunningApps.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($SteamPath)) {
        $GameProcessLog = Join-Path $SteamPath 'logs\gameprocess_log.txt'
        $TrackedRecords = @(Get-TrackedProcessRecords $GameProcessLog $RunningApps[0].AppId)
        $LiveTrackedRecords = @(Get-LiveTrackedRecords $TrackedRecords $ProcessMap $SteamDescendantIds)
    }

    $ReadyToStop = $SteamProcesses.Count -gt 0 -and
        $RunningApps.Count -eq 1 -and
        $RunningAppId -eq $RunningApps[0].AppId -and
        $ActiveSteamPid -in $SteamPids -and
        $SteamExeMatchesProcess -and
        $SteamSignatureTrusted -and
        $LiveTrackedRecords.Count -gt 0

    $Result = [ordered]@{
        Mode = $Mode
        SteamRunning = $SteamProcesses.Count -gt 0
        SteamPidCount = $SteamProcesses.Count
        RunningAppId = $RunningAppId
        RunningApps = @($RunningApps | Select-Object AppId, Name)
        TrackedProcesses = @($LiveTrackedRecords | Select-Object AppId, Pid, Name)
        SteamExecutableTrusted = $SteamSignatureTrusted -and $SteamExeMatchesProcess
        ReadyToStop = $ReadyToStop
        Actions = @()
        Success = $true
    }

    if ($Mode -eq 'probe') {
        Write-Output ($Result | ConvertTo-Json -Compress -Depth 6)
        exit 0
    }

    $Actions = [System.Collections.Generic.List[string]]::new()

    if ($RunningApps.Count -gt 1) {
        throw "Steam reports multiple running AppIDs; refusing an ambiguous stop"
    }

    if ($RunningApps.Count -eq 1) {
        if (-not $ReadyToStop) {
            throw "Steam game identity did not pass registry, signature, log, and process checks"
        }

        $AppId = [int]$RunningApps[0].AppId
        [void](Start-Process -FilePath $SteamExe -ArgumentList @(
            '-ifrunning', '-silent', '+app_stop', $AppId
        ) -WindowStyle Hidden -PassThru -ErrorAction Stop)
        $Actions.Add("requested Steam app_stop for AppID $AppId")

        $GameStopped = Wait-Until -TimeoutSeconds 30 -Condition {
            Test-GameStopped -AppId $AppId -TrackedRecords $LiveTrackedRecords
        }
        if (-not $GameStopped) {
            throw "Steam did not confirm AppID $AppId stopped within 30 seconds; Steam shutdown was not requested"
        }
        $Actions.Add("confirmed AppID $AppId stopped")
    }

    Assert-NoSteamGameReported -Stage 'before Steam shutdown'

    $CurrentSteamProcesses = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'steam.exe'" -ErrorAction Stop)
    if ($CurrentSteamProcesses.Count -gt 0) {
        $SteamExeStillMatches = @($CurrentSteamProcesses | Where-Object {
            [string](Get-PropertyValue $_ 'ExecutablePath' '') -ieq $SteamExe
        }).Count -gt 0
        if ([string]::IsNullOrWhiteSpace($SteamExe) -or -not $SteamExeStillMatches -or -not $SteamSignatureTrusted) {
            throw "Steam executable identity could not be trusted; refusing shutdown"
        }

        [void](Start-Process -FilePath $SteamExe -ArgumentList @('-shutdown') -WindowStyle Hidden -PassThru -ErrorAction Stop)
        $Actions.Add('requested Steam shutdown')

        $SteamStopped = Wait-Until -TimeoutSeconds 45 -Condition {
            @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'steam.exe'" -ErrorAction Stop).Count -eq 0
        }
        if (-not $SteamStopped) {
            throw "Steam did not exit within 45 seconds; no forced termination was attempted"
        }
        $Actions.Add('confirmed Steam exited')
    }
    else {
        $Actions.Add('Steam was not running')
    }

    Assert-NoSteamGameReported -Stage 'after Steam shutdown'

    $Result.Actions = @($Actions)
    $Result.Success = $true
    Write-Output ($Result | ConvertTo-Json -Compress -Depth 6)
    exit 0
}
catch {
    $Failure = [ordered]@{
        Mode = $Mode
        Success = $false
        Error = $_.Exception.Message
        Line = $_.InvocationInfo.ScriptLineNumber
    }
    [Console]::Error.WriteLine(($Failure | ConvertTo-Json -Compress -Depth 4))
    exit 1
}
