# EM (ExchangeMigration) Powershell Module
# Pietro Ciaccio 2019

# Start
################################################################################################################

write-host ""
write-host "Exchange Migration Powershell Module / 0.5.0" -ForegroundColor yellow -BackgroundColor black

# Module wide variables
################################################################################################################

	$ModuleSourceCred = $null
	$ModuleSourceDomain = $null
	$ModuleSourceEndPoint = $null
	$ModuleTargetCred = $null
	$ModuleTargetDomain = $null
	$ModuleTargetEndPoint = $null
	$ModuleActivity = "Migrate"
	$ModuleMode = "LogOnly"
	$ModuleMoveMailbox = "No"
	$ModuleLink = $false
	$ModuleSeparate = $false
	$ModuleLogPath = "C:\Temp\EM"
	$ModuleThreads = 8
	$ModuleWait = $false
	$ModuleSourceGALSyncOU = $null
	$ModuleTargetGALSyncOU = $null
	$ModuleEMConfigPath = $env:LOCALAPPDATA + "\EM\ExchangeMigration.config"
	$ModuleEMDataPath = $ModuleLogPath + "\Data\"

# Log management
################################################################################################################

function Start-EMCheckPaths() {
	if (!(test-path $ModuleLogPath)) {try {new-item $ModuleLogPath -Type directory -Force | out-null} catch {throw "Unable to create logging directory '$ModuleLogPath'"}}
	if (!(test-path $ModuleEMDataPath)) {try {new-item $ModuleEMDataPath -Type directory -Force | out-null} catch {throw "Unable to create logging directory '$ModuleEMDataPath'"}}
}
Start-EMCheckPaths

function Write-log ($type,$comment){

		$type = $type.toupper()
		if ($comment.length -gt $([int]($Host.UI.RawUI.WindowSize.Width * 0.8))) {
			$comment = $comment.substring(0,$([int]($Host.UI.RawUI.WindowSize.Width * 0.8))) + "..."
		}
		write-host $comment" " -nonewline
		switch ($type) {
			"OK" {write-host '[' -nonewline; write-host "$type" -fore green -nonewline; write-host "]"}
			"WARN" {write-host '[' -nonewline; write-host "$type" -fore yellow -nonewline; write-host "]"}
			"ERR" {write-host '[' -nonewline; write-host "$type" -fore red -nonewline; write-host "]"}
			"AR" {write-host '[' -nonewline; write-host "$type" -fore magenta -nonewline; write-host "]"}
			default {write-host ""}
		}
}
function Write-Slog () {
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Identity = $null,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Type = $null,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Comment = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Console = $true
	)

	Process {
		#check for dir
		$LogPath = $null; $LogPath = $Script:ModuleLogPath

		$Ref = ("{0:yyyyMMddHHmmssfff}" -f (get-date)).tostring()
		$identity = $identity.toupper()
		$thisserver = $null; $thisserver = ($env:computername).toupper()
		$out = $null; $out = "$LogPath\EM_$($thisserver)_$($Script:ModuleSourceDomain)_$($Script:ModuleTargetDomain)_$identity.log"
		[pscustomobject]@{
			Ref = $Ref
			Timestamp = $(get-date)
			Identity = $($identity.toupper())
			Type = $($type.toupper())
			Comment = $comment
		} | % {
			if ($Console) {
				write-log $type "$ref $identity $comment"
			}
			if (!(test-path $out)) {
				$_ | convertto-csv -notypeinformation  | out-file $out -append -encoding utf8
			} else {
				$_ | convertto-csv -notypeinformation  | ? {$_ -notmatch '"ref","timestamp","identity","type","comment"'} | out-file $out -append -encoding utf8
			}
		}

		if ($type -eq "err") {
			throw $comment
		}
	}
}

function Read-EMLogs () {
<#
.SYNOPSIS
	Get ExchangeMigration Logs.

.DESCRIPTION
	This cmdlet allows you to review the migration or batch logs associated with EM activities.

.PARAMETER Identity
	This is the samaccountname of the Active Directory object or the name of the batch job. This is used to identify the log you wish to review.

.PARAMETER Type
	This is the type of log entry, e.g. LOG, WARN, ERR.

.PARAMETER Ref
	Every log entry has a reference. This parameter allows you to specify which log entry you wish to review.

#>

#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Identity = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$Type = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$Ref = $null
	)

	Process {
		$LogPath = $null; $LogPath = $Script:ModuleLogPath
		$identity = $identity.toupper()
		$thisserver = $null; $thisserver = ($env:computername).toupper()
		$out = $null; $out = "$LogPath\EM_$($thisserver)_$($Script:ModuleSourceDomain)_$($Script:ModuleTargetDomain)_$identity.log"
		
		try {
			$log = $null; $log = import-csv $out
		} catch {
			throw "Issue getting log data for '$($identity)'"
		}

		if ($type) {
			$log = $log | ? {$_.type -eq $type}
		}

		if ($ref) {
			$log = $log | ? {$_.ref -eq $ref}
		}
		$log
	} 
}

function Start-EMLogsArchive () {
<#
.SYNOPSIS
	Archives ExchangeMigration Logs.

.DESCRIPTION
	This cmdlet will package all .log files and compress them into a single zip using a timestamp based naming convention.
#>

#===============================================================================================================

	$LogPath = $null; $LogPath = $Script:ModuleLogPath
	$timestamp = ("{0:yyyyMMddHHmmss}" -f (get-date)).tostring()

	$logs = $null; $logs = gci "$LogPath\*.log"
	try {
		if ($logs) {$logs | compress-archive -destinationpath "$LogPath\EM$($timestamp).zip"}
	} catch {throw "Issue archiving"}

	try {
		if ($logs) {$logs | rm -force -confirm:$false}
	} catch {throw "Issue removing logs"}
}

function Clear-EMData() {
<#
.SYNOPSIS
	Deletes all logs, archives, and data.

.DESCRIPTION
	This cmdlet will delete all logs and archives. 
#>

#===============================================================================================================

	write-host "This will delete all logs, archives, and data! " -nonewline
	write-host "Are you sure? " -nonewline; write-host "[Y] Yes" -fore yellow -nonewline; write-host ' [N] No (default is "Y")' -nonewline
	[ValidateSet('Yes','No','Y','N',$null)][string]$read = Read-Host -Prompt " "
	if ($read -match "^No$|^N$") {
		wwrite-log "WARN" "Aborted"
		break
	}

	try {
		gci c:\temp\EM | remove-item -recurse -force -confirm:$false -ea stop
		Start-EMCheckPaths
		write-log "OK" "Done"
	} catch {
		write-log "ERR" "Issue deleting"
	}
}

# Function to read out the configuration data loaded into the module
function Get-EMConfiguration () {
<#
.SYNOPSIS
	Displays the ExchangeMigration configuration.

.DESCRIPTION
	This cmdlet displays the configuration that has been loaded for the EM module to use. The EM configuration is the baseline for all activities unless overridden at runtime.
#>

#===============================================================================================================
	[pscustomobject]@{
			SourceCred = $ModuleSourceCred
			SourceDomain = $ModuleSourceDomain
			SourceEndPoint = $ModuleSourceEndPoint
			SourceGALSyncOU = $ModuleSourceGALSyncOU
			TargetCred= $ModuleTargetCred
			TargetDomain = $ModuleTargetDomain
			TargetEndPoint = $ModuleTargetEndPoint
			TargetGALSyncOU = $ModuleTargetGALSyncOU
			Activity = $ModuleActivity
			Link = $ModuleLink
			LogPath = $ModuleLogPath
			Mode = $ModuleMode
			MoveMailbox = $ModuleMoveMailbox
			Threads = $ModuleThreads
			Wait = $ModuleWait
		}
}

function Read-EMData () {
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Identity = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Raw = $false
	)

	Process {
		$LogPath = $null; $LogPath = $Script:ModuleEMDataPath
		$thisserver = $null; $thisserver = ($env:computername).toupper()
		$in = $null; $in = "$LogPath\EM_$($thisserver)_$($Script:ModuleSourceDomain)_$($Script:ModuleTargetDomain)_$identity.emdata"
	
		try {
			$data = $null; 
			if (test-path $in){
				$data = gc $in -ea stop
			}
		} catch {
			throw "Issue getting post migration data for '$($identity)'"
		}
		
		if ($raw -eq $false) {
			$returndata = $null;
			if ($data) {
				$returndata = $data | % {
					try{
						$_ | convertfrom-json
					}catch{
						write-Slog "$samaccountname" "WARN" "'$_' issue converting from JSON and will be excluded"
					}			
				}
			}
			return $returndata
		} else {
			return $data
		}
	}
}

function Write-EMData () {
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Identity = $null,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Type = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)]$Data = $null
	)

	Process {
		Start-EMCheckPaths
		$read = $null; $read = Read-EMData -identity $identity -raw $true | ? {$_ -notmatch $type}
		$LogPath = $null; $LogPath = $Script:ModuleEMDataPath
		$identity = $identity.toupper()
		$thisserver = $null; $thisserver = ($env:computername).toupper()
		$out = $null; $out = "$LogPath\EM_$($thisserver)_$($Script:ModuleSourceDomain)_$($Script:ModuleTargetDomain)_$identity.emdata"

		try {
			[pscustomobject]@{
				Type = $($type.toupper())
				Data = $Data
			} | % {
				$write = $null; $write = $_ | convertto-json -compress 
			}
			if ($read -notcontains $write) {
				$read + $write | out-file $out 
			}
		} catch {
			write-Slog "$samaccountname" "WARN" "'$_' issue converting to JSON and will be excluded"
		}
	}
}

function Update-EMData () {
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Identity = $null,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Type = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)]$Data = $null
	)

	Process {
		Start-EMCheckPaths
		$read = $null; $read = Read-EMData -identity $identity -raw $true
		$LogPath = $null; $LogPath = $Script:ModuleEMDataPath
		$identity = $identity.toupper()
		$thisserver = $null; $thisserver = ($env:computername).toupper()
		$out = $null; $out = "$LogPath\EM_$($thisserver)_$($Script:ModuleSourceDomain)_$($Script:ModuleTargetDomain)_$identity.emdata"

		try {
			[pscustomobject]@{
				Type = $($type.toupper())
				Data = $Data
			} | % {
				$update = $null; $update = $_ | convertto-json -compress 
			}
			$commit = $null
			$commit = $read | ? {$_ -ne $update}
			if ($commit) {
				$commit | out-file $out
			} else {
				remove-item $out -confirm:$false -force
			}
		} catch {
			write-Slog "$samaccountname" "WARN" "Issue updating '$out' and will be excluded"
		}		
	}
}


# Pre-load, read, and apply configuration
################################################################################################################

# Validate credentials
#===============================================================================================================
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
function Test-EMCredential() {

	Param (
		[Parameter(mandatory=$true)][string]$DomainName,
		[Parameter(mandatory=$false)][string]$Username,
		[Parameter(mandatory=$false)][System.Security.SecureString]$SecurePassword
	)
	Process {
		try {
			$Password = New-Object system.Management.Automation.PSCredential("user", $SecurePassword)
			$Password = $Password.GetNetworkCredential().Password			
			$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain,$domainname)
			$DS.ValidateCredentials($username,$Password)
		} catch {
			$false
		}
	}
}

function Read-EMConfiguration() {
#===============================================================================================================
if (test-path $Script:ModuleEMConfigPath) {
		try {
			$Secureconfig = $null; $Secureconfig = Get-Content $Script:ModuleEMConfigPath
			$Secureconfig = $Secureconfig | ConvertTo-SecureString
			$Secureconfig = New-Object system.Management.Automation.PSCredential("user", $Secureconfig)
			$Config = $Secureconfig.GetNetworkCredential().Password
			$Config = $Config | ConvertFrom-Json
			$Config 
		} catch {throw "There was an issue reading the configuration data."}
	} else {
		throw "EM configuration file not found."
	}
}

function Test-EMConfiguration () {
<#
.SYNOPSIS
	Test the ExchangeMigration configuration.

.DESCRIPTION
	This cmdlet will test the credentials and settings that are specified in the EM configuration file. This can be used to rule out any issues that may be related to configuration, e.g. credentials.
#>

#===============================================================================================================
	write-host ""
	$Config = Get-EMConfiguration

	# Health checking source
	if (Test-EMCredential -DomainName $($Config.SourceDomain) -Username $($Config.SourceCred.Username) -SecurePassword $($Config.SourceCred.Password)) {
		write-log "OK" "Source Credential '$($Config.SourceCred.Username)'"	
	} else {
		write-log "ERR" "Source Credential '$($Config.SourceCred.Username)'"
	}	

	if (test-connection $($Config.SourceDomain) -Quiet) {
		write-log "OK" "Source Domain '$($Config.SourceDomain)'"
	} else {
		write-log "ERR" "Source Domain '$($Config.SourceDomain)'"
	}

	if (test-connection $($Config.SourceEndPoint) -Quiet) {
		write-log "OK" "Source End Point '$($Config.SourceEndPoint)'"
	} else {
		write-log "ERR" "Source End point '$($Config.SourceEndPoint)'"
	}

	if ($(try{Get-ADObject $($Config.SourceGALSyncOU) -Server $($config.SourceDomain) -Credential $($Config.SourceCred)}catch{})){
		write-log "OK" "Source GAL OU '$($Config.SourceGALSyncOU)'"
	} else {
		write-log "ERR" "Source GAL OU '$($Config.SourceGALSyncOU)'"
	}

	# Health checking target
	if (Test-EMCredential -DomainName $($Config.TargetDomain) -Username $($Config.TargetCred.Username) -SecurePassword $($Config.TargetCred.Password)) {
		write-log "OK" "Target Credential '$($Config.TargetCred.Username)'"	
	} else {
		write-log "ERR" "Target Credential '$($Config.TargetCred.Username)'"	
	}

	if (test-connection $($Config.TargetDomain) -Quiet) {
		write-log "OK" "Target Domain '$($Config.TargetDomain)'"
	} else {
		write-log "ERR" "Target Domain '$($Config.TargetDomain)'"
	}

	if (test-connection $($Config.TargetEndPoint) -Quiet) {
		write-log "OK" "Target End Point '$($Config.TargetEndPoint)'"
	} else {
		write-log "ERR" "Target End Point '$($Config.TargetEndPoint)'"
	}

	if ($(try{Get-ADObject $($Config.TargetGALSyncOU) -Server $($config.TargetDomain) -Credential $($Config.TargetCred)}catch{})){
		write-log "OK" "Target GAL OU '$($Config.TargetGALSyncOU)'"
	} else {
		write-log "ERR" "Target GAL OU '$($Config.TargetGALSyncOU)'"
	}

	if (test-path $($Config.LogPath)) {
		write-log "OK" "LogPath '$($Config.LogPath)'"
	} else {
		write-log "ERR" "LogPath '$($Config.LogPath)'"
	}

	write-host ""
}

function Enable-EMConfiguration() {
#===============================================================================================================
try {
		$Config = Read-EMConfiguration

		$SourceCred = $null; $SourceCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $($Config.SourceUsername),$($Config.SourcePassword | ConvertTo-SecureString)
		$TargetCred = $null; $TargetCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $($Config.TargetUsername),$($Config.TargetPassword | ConvertTo-SecureString)

		# Committing
		$Script:ModuleSourceDomain = $Config.SourceDomain.toupper()
		$Script:ModuleSourceEndPoint = $config.SourceEndPoint.toupper()
		$Script:ModuleTargetDomain = $Config.TargetDomain.toupper()
		$Script:ModuleTargetEndPoint = $Config.TargetEndPoint.toupper()
		$Script:ModuleLogPath = $Config.LogPath
		$Script:ModuleSourceGALSyncOU = $Config.SourceGALSyncOU
		$Script:ModuleTargetGALSyncOU = $Config.TargetGALSyncOU
		$Script:ModuleSourceCred = $SourceCred
		$Script:ModuleTargetCred = $TargetCred

		write-log "OK" "Configuration successfully enabled."
		write-log "LOG" "Logging to '$Script:ModuleLogPath'."
		write-host ""
		write-host "Use 'Read-EMConfiguration' to review."
		write-host "To create a new configuration use the 'Write-EMConfiguration' cmdlet."
		write-host "To test configuration data settings use 'Test-EMConfiguraion'"
		write-host ""
	} catch {throw "There was an issue enabling the configuration data."}
}

function Write-EMConfiguration() {
<#
.SYNOPSIS
	Creates the ExchangeMigration configuration file and loads it for EM to use.

.DESCRIPTION
	Creates the ExchangeMigration configuration file and loads it for EM to use. This file is called ExchangeMigration.config and is stored C:\Users\samaccountname\AppData\Local\EM\.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER SourceEndPoint
	Specify the source end point for the source Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER SourceGALSyncOU
	Specify the OU where you would like GALSync objects to be created / moved to in the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER TargetEndPoint
	Specify the target end point for the target Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER TargetGALSyncOU
	Specify the OU where you would like GALSync objects to be created / moved to in the target domain.

.PARAMETER LogPath
	Specify the log path to be used by EM.

#>
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
		[Parameter(mandatory=$false)][string]$SourceDomain = $Script:ModuleSourceDomain,
		[Parameter(mandatory=$false)][string]$SourceEndPoint = $Script:ModuleSourceEndPoint,
		[Parameter(mandatory=$false)][string]$SourceGALSyncOU = $Script:ModuleSourceGALSyncOU,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
		[Parameter(mandatory=$false)][string]$TargetDomain = $Script:ModuleTargetDomain,
		[Parameter(mandatory=$false)][string]$TargetEndPoint = $Script:ModuleTargetEndPoint,
		[Parameter(mandatory=$false)][string]$TargetGALSyncOU = $Script:ModuleTargetGALSyncOU,
		[Parameter(mandatory=$false)][string]$LogPath = $Script:ModuleLogPath
	)

	Process {
		if (!($sourceCred)) {
			write-host ""
			write-host "Username for Source administrator? (As Domain\UPN)> " -nonewline
			$SourceUsername = read-host
			write-host "Password for Source administrator?> " -nonewline;
			$SourcePassword = read-host -AsSecureString | ConvertFrom-SecureString
		} else {
			$SourceUsername = $SourceCred.UserName
			$SourcePassword = $SourceCred.password | ConvertFrom-SecureString
		}

		if (!($SourceDomain)) {$SourceDomain = read-host "SourceDomain"}
		if (!($SourceEndPoint)) {$SourceEndPoint = read-host "SourceEndPoint"}
		if (!($SourceGALSyncOU)) {$SourceGALSyncOU = read-host "SourceGALSyncOU"}

		if (!($targetcred)) {
			write-host ""
			write-host "Username for Target administrator? (As Domain\UPN)> " -nonewline
			$TargetUsername = read-host
			write-host "Password for Target administrator?> " -nonewline;
			$TargetPassword = read-host -AsSecureString | ConvertFrom-SecureString
		} else {
			$TargetUsername = $TargetCred.UserName
			$TargetPassword = $TargetCred.password | ConvertFrom-SecureString			
		}

		if (!($TargetDomain)) {$TargetDomain = read-host "TargetDomain"}
		if (!($TargetEndPoint)) {$TargetEndPoint = read-host "TargetEndPoint"}
		if (!($TargetGALSyncOU)) {$TargetGALSyncOU = read-host "TargetGALSyncOU"}

		try {
			$Config = $null; $Config = [pscustomobject]@{
				SourceUsername = $SourceUsername
				SourcePassword = $SourcePassword
				SourceDomain = $SourceDomain
				SourceEndPoint = $SourceEndPoint
				TargetUsername = $TargetUsername
				TargetPassword = $TargetPassword
				TargetDomain = $TargetDomain
				TargetEndPoint = $TargetEndPoint
				LogPath = $LogPath
				SourceGALSyncOU = $SourceGALSyncOU
				TargetGALSyncOU = $TargetGALSyncOU
			}
		} catch { throw "There is an issue with the information provided."}

		try {
			$config = $config | convertto-json
		} catch {throw "There was an issue converting the configuration data to JSON."}

		try {
			$Secureconfig = $null; $Secureconfig = $Config | ConvertTo-SecureString -Force -AsPlainText
			$Secureconfig = $Secureconfig | ConvertFrom-SecureString 
		} catch {throw "There was an issue protecting the configuration data."}

		if (!(test-path $($Script:ModuleEMConfigPath -replace "ExchangeMigration.config"))) {
			try {
				new-item $($Script:ModuleEMConfigPath -replace "ExchangeMigration.config") -Type directory -Force | out-null
			} catch {
				throw "Unable to create logging directory '$LogPath'"
			}
		}

		write-host ""
		try{
			$Secureconfig | out-file $Script:ModuleEMConfigPath -Force -Confirm:$false			
			write-log "OK" "Configuration written to '$Script:ModuleEMConfigPath'"
		} catch {throw "There was an issue writing the configuration to disk."}

		Enable-EMConfiguration
	}
}

write-host ""
# Load ExchangeMigration.config if present
if (Test-Path $Script:ModuleEMConfigPath) {
	write-log "OK" "Configuration detected. '$Script:ModuleEMConfigPath'"
	Enable-EMConfiguration
} else {
	write-log "WARN" "Configuration not detected. Calling 'Write-EMConfiguration'"
	Write-EMConfiguration
}

# Module wide functions
################################################################################################################
function Get-EMSecondaryDistinguishedNames() {
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Attribute,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$PrimaryCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$PrimaryPDC,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)]$PrimaryDNs,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SecondaryCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SecondaryPDC
	)
	Process {

		if ($primaryDNs) {
			# get sams
			$psams = $null; $psams = @(); $primaryDNs | % {
				$dn = $null; $dn = $_
				try {
					$adobject = $null; $adobject = get-adobject $dn -properties mailnickname,samaccountname -server $primarypdc -credential $primarycred 
					if (($adobject | measure).count -eq 1) {
						$psams += $adobject.samaccountname							
					}
					if (($adobject | measure).count -gt 1) {
						write-Slog "$samaccountname" "WARN" "'$dn' $Attribute multiple user objects returned from primary domain and will be excluded"
					}
				} catch {
					write-Slog "$samaccountname" "WARN" "'$dn' Issue getting $Attribute in primary domain and will be excluded"
				}
			}
			
			$allsams = $null; $allsams = @()
			$psams | % {$allsams += $_}
			$allsams = $allsams | sort | get-unique

			# get distinguishednames from secondary
			if ($allsams) {
				$sdns = $null; $sdns = @(); $allsams | % {
					$sam = $null; $sam = $_
					try {
						$adobject = $null; $adobject = get-adobject -filter {samaccountname -eq $sam} -properties mailnickname,samaccountname -server $secondarypdc -credential $secondarycred 
						if (($adobject | measure).count -eq 1) {
							$sdns += $adobject.distinguishedname
						}					
						if (($adobject | measure).count -eq 0) {
							write-Slog "$samaccountname" "WARN" "'$sam' $Attribute no object found in secondary domain and will be excluded"
						}
						if (($adobject | measure).count -gt 1) {
							write-Slog "$samaccountname" "WARN" "'$sam' $Attribute multiple objects found in secondary domain and will be excluded"
						}
					} catch {
						write-Slog "$samaccountname" "ERR" "'$sam' Issue getting $Attribute in secondary domain"
					}
				}				
				$sdns = $sdns | sort | get-unique | % {$_.tostring()}
				return $sdns
			} else {
				return $null
			}
		} else {
			return $null
		}			
	}
}

function Get-EMSecondaryGUIDs() {
	#===============================================================================================================
		[cmdletbinding()]
		Param (
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Attribute,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$PrimaryCred,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$PrimaryPDC,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)]$PrimaryDNs,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SecondaryCred,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SecondaryPDC
		)
		Process {
	
			if ($primaryDNs) {
				# get sams
				$psams = $null; $psams = @(); $primaryDNs | % {
					$dn = $null; $dn = $_
					try {
						$adobject = $null; $adobject = get-adobject $dn -properties mailnickname,samaccountname -server $primarypdc -credential $primarycred 
						if (($adobject | measure).count -eq 1) {
							$psams += $adobject.samaccountname							
						}
						if (($adobject | measure).count -gt 1) {
							write-Slog "$samaccountname" "WARN" "'$dn' $Attribute multiple user objects returned from primary domain and will be excluded"
						}
					} catch {
						write-Slog "$samaccountname" "WARN" "'$dn' Issue getting $Attribute in primary domain and will be excluded"
					}
				}
				
				$allsams = $null; $allsams = @()
				$psams | % {$allsams += $_}
				$allsams = $allsams | sort | get-unique
	
				# get GUIDs from secondary
				if ($allsams) {
					$sGUIDs = $null; $sGUIDs = @(); $allsams | % {
						$sam = $null; $sam = $_
						try {
							$adobject = $null; $adobject = get-adobject -filter {samaccountname -eq $sam} -properties objectguid,samaccountname -server $secondarypdc -credential $secondarycred 
							if (($adobject | measure).count -eq 1) {
								$sGUIDs += $adobject.objectguid.guid
							}					
							if (($adobject | measure).count -eq 0) {
								write-Slog "$samaccountname" "WARN" "'$sam' $Attribute no object found in secondary domain and will be excluded"
							}
							if (($adobject | measure).count -gt 1) {
								write-Slog "$samaccountname" "WARN" "'$sam' $Attribute multiple objects found in secondary domain and will be excluded"
							}
						} catch {
							write-Slog "$samaccountname" "ERR" "'$sam' Issue getting $Attribute in secondary domain"
						}
					}				
					$sGUIDs = $sGUIDs | sort | get-unique | % {$_.tostring()}
					return $sGUIDs
				} else {
					return $null
				}
			} else {
				return $null
			}			
		}
	}

function Convertto-DistinguishedName() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true)][string]$Samaccountname,
		[Parameter(mandatory=$true)][string]$CanonicalName
	)
	Process {
		try {
			$DN = $null;
			$DN = $CanonicalName -split "/"
			$DNout = $null;

			$count = $($DN | measure).count - 1
			for ($i = $count; $i -ge 0; $i--) {
				if ($i -eq $count) {
					$DNout = "CN=" + $DN[$i]
				}
				if ($i -lt $count -and $i -ne 0) {
					$DNout += ",OU=" + $DN[$i]
				}
				if ($i -eq 0) {
					$DNtemp = $null; $DNtemp = ",DC=" + $DN[$i]; $DNtemp = $DNtemp -replace "\.",",DC="
					$DNout += $DNtemp
				}
			}
			return $DNout
		} catch {
			write-Slog "$samaccountname" "WARN" "'$Canonicalname' issue converting canonicalname to distringuishedname and will be excluded"
		}
	}
}

function Invoke-EMExchangeCommand() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true)][string]$Endpoint,
		[Parameter(mandatory=$true)][string]$DomainController,
		[Parameter(mandatory=$true)][system.management.automation.pscredential]$Credential,
		[Parameter(mandatory=$true)][string]$Command
	)
	Process {
		[scriptblock]$scriptblock = [scriptblock]::Create($command)
		Invoke-Command -ConnectionUri http://$Endpoint/powershell -credential $credential -ConfigurationName microsoft.exchange -scriptblock $scriptblock -sessionoption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -allowredirection -warningaction silentlycontinue -ea stop
	}
}
	
function Get-EMConflict() { 
#===============================================================================================================
		[cmdletbinding()]
		Param (
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$samaccountname,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$sourcepdc,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$targetpdc,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$sourcedomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$targetdomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$targetendpoint,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred
	
		)
		Process {
			$smtps = $($source.proxyaddresses | ? {$_ -match "^smtp:"}) + $("smtp:" + $source.mail) | % {$_.tolower()} | sort | get-unique
			$smtps += "smtp:" + $($source.mailnickname) + "@mail.on" + $targetdomain
			if (!($smtps)) {
				write-Slog "$samaccountname" "ERR" "Issues getting SMTPs in source domain '$($sourcedomain)'"
			}
	
			$x500 = $null; $x500 = "$($source.legacyexchangedn)"
			if (!($x500)) {
				write-Slog "$samaccountname" "ERR" "Issue getting X500 / legacyexchangedn in source domain '$($sourcedomain)'"
			}
			$x500 = "X500:" + $x500
			
			$smtps += $x500
	
			$ldapquery = $null; $($smtps | % {$ldapquery += "(proxyaddresses=" + $_ + ")"})
			$ldapquery += "(mailnickname=" + $source.mailnickname + ")"
			$ldapquery = "(|" + $ldapquery + ")"
	
			try {	
				$cresult = $null; $cresult = Get-ADObject -LDAPFilter "$ldapquery" -properties samaccountname,proxyaddresses,mailnickname -server $($targetpdc) -Credential $TargetCred
				if ($cresult) {
					$cresult | % {if ($_.samaccountname -ne $samaccountname){$_}}					
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue running command '$command'"
			}
		}
	}
	
function Get-EMRecipientTypeDetails() { 
#===============================================================================================================
	
		Param (
			[Parameter(mandatory=$false)][string]$type
		)
	
		$data = $type
		if($type -band 1) {$data = "UserMailbox"}
		if($type -band 2) {$data = "LinkedMailbox"}
		if($type -band 4) {$data = "SharedMailbox"}
		if($type -band 16) {$data = "RoomMailbox"}
		if($type -band 32) {$data = "EquipmentMailbox"}
		if($type -band 128) {$data = "MailUser"}
		if($type -band 33554432) {$data = "LinkedUser"}
		if($type -band 2147483648) {$data = "RemoteUserMailbox"}
		if($type -band 8589934592) {$data = "RemoteRoomMailbox"}
		if($type -band 17179869184) {$data = "RemoteEquipmentMailbox"}
		if($type -band 34359738368) {$data = "RemoteSharedMailbox"}
		if ($type -band 268435456) {$data = "roomlist"}
		if ($type -band 1073741824) {$data = "rolegroup"}
		
		$data
	}
	
function Get-EMRecipientDisplayType() { 
#===============================================================================================================
	
		Param (
			[Parameter(mandatory=$true,valuefrompipeline=$true)][string]$type
		)
	
		$data = $type
		if($type -band -2147483642) {$data = "RemoteUserMailbox"}
		if($type -band -2147481850) {$data = "RemoteRoomMailbox"}
		if($type -band -2147481594) {$data = "RemoteEquipmentMailbox"}
		if($type -band 0) {$data = "SharedMailbox"}
		if($type -band 1) {$data = "MailUniversalDistributionGroup"}
		if($type -band 6) {$data = "MailContact"}
		if($type -band 7) {$data = "RoomMailbox"}
		if($type -band 8) {$data = "EquipmentMailbox"}
		if($type -band 1073741824) {$data = "UserMailbox"}
		if($type -band 1073741833) {$data = "MailUniversalSecurityGroup"}
	
		return $data
	}

function Start-EMCleanActiveDirectoryObject() {
<#
.SYNOPSIS
	Cleans an Active Directory object's Exchange attributes

.DESCRIPTION
	You can use this cmdlet to clean the Exchange attributes of any Active Directory object. 

.PARAMETER Samaccountname
	The samaccountname of the Active Directory object.

.PARAMETER SourceOrTarget
	Specify whether the action should be applied to the source or target domain.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER SourceCred
	Specify the source credentials for the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER TargetCred
	Specify the target credentials for the target domain.

.PARAMETER Confirm
	Specify whether you want to be asked for confirmation. The default is TRUE.
#>

#===============================================================================================================
		[cmdletbinding()]
		Param (
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Samaccountname,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Source','Target')][string]$SourceOrTarget,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceDomain = $Script:ModuleSourceDomain,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain = $Script:ModuleTargetDomain,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Confirm = $true
	
		)
		Process {
			
			#Setup

			if ($SourceOrTarget -eq "Source") {
				$ScopedDomain = $SourceDomain.toupper()
				$ScopedCred = $SourceCred
			}

			if ($SourceOrTarget -eq "Target") {
				$ScopedDomain = $TargetDomain.toupper()
				$ScopedCred = $TargetCred
			}

			write-Slog "$samaccountname" "LOG" "Cleaning AD object in domain '$ScopedDomain'"

			# collect info
			try {
				$Scopedpdc = $null; get-addomain  -Server $Scopeddomain -credential $Scopedcred -ea stop | % {
					$Scopedpdc = $_.pdcemulator
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting domain information for domain '$Scopeddomain'"
			}

			$ADobj = $null; $ADobj = Get-ADObject -server $Scopedpdc -filter {samaccountname -eq $samaccountname} -properties * -credential $Scopedcred -ea stop
			if (($ADobj | measure).count -gt 1) {
				write-Slog "$samaccountname" "ERR" "Multiple user objects returned from domain '$Scopeddomain'. Unable to continue"
			}

			if (($ADobj | measure).count -eq 0) {
				write-Slog "$samaccountname" "ERR" "No user objects returned from domain '$Scopeddomain'. Unable to continue"
			}

			if ($confirm -eq $true) {
				write-host "This will remove all Exchange attributes! " -nonewline
				write-host "Are you sure? " -nonewline; write-host "[Y] Yes" -fore yellow -nonewline; write-host ' [N] No (default is "Y")' -nonewline
				[ValidateSet('Yes','No','Y','N',$null)][string]$read = Read-Host -Prompt " "
				if ($read -match "^No$|^N$") {
					write-Slog "$samaccountname" "WARN" "Cleaning AD object in domain '$ScopedDomain' aborted"
					break
				}
			}
			
			try {
				if ($ADobj.mail) {$ADobj.mail = $null}
				if ($ADobj.HomeMDB) {$ADobj.HomeMDB = $null}
				if ($ADobj.HomeMTA) {$ADobj.HomeMTA = $null}
				if ($ADobj.legacyExchangeDN) {$ADobj.legacyExchangeDN = $null}
				if ($ADobj.msExchMailboxAuditEnable) {$ADobj.msExchMailboxAuditEnable = $null}
				if ($ADobj.msExchAddressBookFlags) {$ADobj.msExchAddressBookFlags = $null}
				if ($ADobj.msExchArchiveQuota) {$ADobj.msExchArchiveQuota = $null}
				if ($ADobj.msExchArchiveWarnQuota) {$ADobj.msExchArchiveWarnQuota = $null}
				if ($ADobj.msExchBypassAudit) {$ADobj.msExchBypassAudit = $null}
				if ($ADobj.msExchDumpsterQuota) {$ADobj.msExchDumpsterQuota = $null}
				if ($ADobj.msExchDumpsterWarningQuota) {$ADobj.msExchDumpsterWarningQuota = $null}
				if ($ADobj.msExchHomeServerName) {$ADobj.msExchHomeServerName = $null}
				if ($ADobj.msExchMailboxAuditEnable) {$ADobj.msExchMailboxAuditEnable = $null}
				if ($ADobj.msExchMailboxAuditLogAgeLimit) {$ADobj.msExchMailboxAuditLogAgeLimit = $null}
				if ($ADobj.msExchMailboxGuid) {$ADobj.msExchMailboxGuid = $null}
				if ($ADobj.msExchMDBRulesQuota) {$ADobj.msExchMDBRulesQuota = $null}
				if ($ADobj.msExchModerationFlags) {$ADobj.msExchModerationFlags = $null}
				if ($ADobj.msExchPoliciesIncluded) {$ADobj.msExchPoliciesIncluded = $null}
				if ($ADobj.msExchProvisioningFlags) {$ADobj.msExchProvisioningFlags = $null}
				if ($ADobj.msExchRBACPolicyLink) {$ADobj.msExchRBACPolicyLink = $null}
				if ($ADobj.msExchRecipientDisplayType) {$ADobj.msExchRecipientDisplayType = $null}
				if ($ADobj.msExchRecipientTypeDetails) {$ADobj.msExchRecipientTypeDetails = $null}
				if ($ADobj.msExchADCGlobalNames) {$ADobj.msExchADCGlobalNames = $null}
				if ($ADobj.msExchALObjectVersion) {$ADobj.msExchALObjectVersion = $null}
				if ($ADobj.msExchRemoteRecipientType) {$ADobj.msExchRemoteRecipientType = $null}
				if ($ADobj.msExchSafeSendersHash) {$ADobj.msExchSafeSendersHash = $null}
				if ($ADobj.msExchUserHoldPolicies) {$ADobj.msExchUserHoldPolicies = $null}
				if ($ADobj.msExchWhenMailboxCreated) {$ADobj.msExchWhenMailboxCreated = $null}
				if ($ADobj.msExchTransportRecipientSettingsFlags) {$ADobj.msExchTransportRecipientSettingsFlags = $null}
				if ($ADobj.msExchRecipientSoftDeletedStatus) {$ADobj.msExchRecipientSoftDeletedStatus = $null}
				if ($ADobj.msExchUMDtmfMap) {$ADobj.msExchUMDtmfMap = $null}
				if ($ADobj.msExchUMEnabledFlags2) {$ADobj.msExchUMEnabledFlags2 = $null}
				if ($ADobj.msExchUserAccountControl) {$ADobj.msExchUserAccountControl = $null}
				if ($ADobj.msExchVersion) {$ADobj.msExchVersion = $null}
				if ($ADobj.proxyAddresses) {$ADobj.proxyAddresses = $null}
				if ($ADobj.showInAddressBook) {$ADobj.showInAddressBook = $null}
				if ($ADobj.mailNickname) {$ADobj.mailNickname = $null}				

				Set-ADObject -Instance $ADobj -server $Scopedpdc -Credential $ScopedCred -ea stop

				write-Slog "$samaccountname" "OK" "Cleaned object"
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue cleaning object. Unable to continue"
			}
			write-Slog "$samaccountname" "LOG" "Ready"
		}
}

# Batch handling
################################################################################################################
function Start-EMProcessMailboxBatch() {
<#
.SYNOPSIS
	Processes mailboxes in batches

.DESCRIPTION
	This cmdlet runs the Start-EMProcessMailbox cmdlet against many mailboxes in a batch. It will also provide a batch log and has options to send a notification email when is it done.

.PARAMETER Samaccountnames
	This is an array of samaccountname attributes you want the cmdlet to batch process.

.PARAMETER SourceCred
	Specify the source credentials of the source domain.

.PARAMETER TargetCred
	Specify the target credentials of the target domain.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER Activity
	Specify whether you want to MIGRATE or GALSYNC.

.PARAMETER Mode
	Specify whether you want to PREPARE or LOGONLY.

.PARAMETER MoveMailbox
	Specify what move request operation you would like to perform. It is possible to select SUSPEND which will copy up to 95% of the mail data but will not complete. 

.PARAMETER SourceEndPoint
	Specify the source end point for the source Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER TargetEndPoint
	Specify the target end point for the target Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER Link
	Specified whether to link the primary object, i.e. the mailbox, to the secondary object, i.e. the user object in the opposite Active Directory forest.

.PARAMETER Separate
	Specifies whether to break the cross-forest relationship and apply limitations to the secondary object.

.PARAMETER Threads
	Specify how many threads you would like to create for parallel execution of Start-EMProcessMailbox

.PARAMETER wait
	For mailbox move request operations you can specify whether to wait for the move request to complete. On full mailbox moves this will result in the required post migration tasks being applied. If you don't wait then Start-EMProcessMailbox will need to be run manually after the move request has completed.

.PARAMETER ReportSMTP
	The email address you would like a notification sent to when the batch completes.

.PARAMETER SMTPServer
	The SMTP relay server to use when sending an email.

#>

#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][array]$Samaccountnames = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceDomain = $Script:ModuleSourceDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain = $Script:ModuleTargetDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity = $Script:ModuleActivity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode = $Script:ModuleMode,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox = $Script:ModuleMoveMailbox,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint = $Script:ModuleSourceEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint = $Script:ModuleTargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Link = $Script:ModuleLink,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][int]$Threads=$Script:ModuleThreads,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$wait = $Script:ModuleWait,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$ReportSMTP = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SMTPServer= $null
	)
	Process {
		$samaccountnames = $samaccountnames | sort | get-unique
		$total = $null; $total = ($samaccountnames | measure).count
		$warnings = 0
		$throws = 0
		$sleep = 5
		$timestamp = ("{0:yyyyMMddHHmmss}" -f (get-date)).tostring()
		$jobname = $null; $jobname = "EMProcessMailboxBatch$($timestamp)"
		$EMPath = (get-module exchangemigration).path
		$errorcount = 0

		if ($reportsmtp) {
			if ($reportsmtp -notmatch "^[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$") {
				write-Slog "$jobname" "ERR" "'$reportsmtp' is not a valid SMTP address. Unable to continue" $false
			}
			if ($reportsmtp -and !($smtpserver)) {
				write-Slog "$jobname" "ERR" "Must provide SMTPServer if using ReportSMTP. Unable to continue" $false
			}
		}

		#Starting
		write-host ""
		write-host "Job:`t`t$($jobname)"
		$start = $(get-date)
		write-host "Started:`t$($start)"
		$n = 0
		foreach ($samaccountname in $samaccountnames) {
			$n++
			write-progress -activity "$jobname" -status "Processing $n of $($total): '$samaccountname'" -percentcomplete (($n) / $total*100)
			start-job -name $jobname -ScriptBlock {
				sleep -s $(get-random -Minimum 5 -Maximum 60);
				try{import-module "$using:EMPath"}catch{throw}; try{import-module activedirectory}catch{throw};
				sleep -s $(get-random -Minimum 5 -Maximum 60);
				write-Slog "$using:samaccountname" "LOG" "'$using:jobname' started" $false | out-null
				Start-EMProcessMailbox -Samaccountname $using:samaccountname `
				-SourceCred $using:sourcecred `
				-TargetCred $using:targetcred `
				-SourceDomain $using:sourcedomain `
				-TargetDomain $using:targetdomain `
				-Activity $using:activity `
				-Mode $using:mode `
				-MoveMailbox $using:movemailbox `
				-SourceEndPoint $using:sourceendpoint `
				-TargetEndPoint $using:targetendpoint `
				-Link $using:link `
				-Wait $using:wait `
				-Separate $using:separate | out-null;
				write-Slog "$using:samaccountname" "LOG" "'$using:jobname' ended" $false | out-null
				} | out-null
			write-Slog "$jobname" "LOG" "Samaccountname: $samaccountname SourceDomain: $sourcedomain; TargetDomain: $targetdomain; Activity: $Activity; Mode: $Mode; MoveMailbox: $MoveMailbox; SourceEndPoint: $SourceEndPoint; TargetEndPoint: $TargetEndPoint; Link: $Link; Separate: $Separate;" $false| out-null
			sleep -s 1
    			while($(get-job -name $jobname | ? {$_.state -eq 'running'}).Count -ge $threads) {
          				sleep -s $sleep			
     			}
			
			#tidy
			get-job -name $jobname | ? {$_.state -ne 'running'} | remove-job -Force -Confirm:$false
		}
		sleep -s 1; [System.GC]::Collect()
		
		#Completing
		write-host "Completing:`t$(get-date)"
    		while($(get-job -name $jobname | ? {$_.state -eq 'running'})) {          					
			sleep -s $sleep			
     		}
		
		#Finishing
		foreach ($samaccountname in $samaccountnames) {
			try {
				try {
					$emlog = $null; $emlog = Read-EMLogs -identity $samaccountname
				} catch {
					write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname Notes: Logs not found" $false | out-null
				}

				if ($($emlog | ? {$_.comment -match $jobname} | measure).count -ne 2) {
					write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname Notes: Job not found or complete in logs" $false | out-null
				}

				$readout = $false
				foreach ($line in $emlog) {
					if ($line.comment -match $jobname -and $line.comment -match "ended") {$readout = $false}
					if ($readout) {
						if ($line.type -eq "ERR") {
							write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname" $false | out-null
						}
					}
					if ($line.comment -match $jobname -and $line.comment -match "started") {$readout = $true}
				}				
			} catch {
				$errorcount += 1
			}
		}

		$summary = $null; $summary =  "Total $total ERR $errorcount"
		write-Slog "$jobname" "LOG" "$summary" $false | out-null
		get-job -name $jobname | remove-job -Force -Confirm:$false
		$end = $(get-date)
		$output = $null; $output = "Completed:`t$($end) `nDuration:`t$([math]::round((new-timespan -Start $start -End (get-date)).totalminutes)) minutes `nSummary:`t$summary"
		write-host $output
		write-host

		if ($reportsmtp) {
			try {
				Send-MailMessage -To $ReportSMTP -From $("EM@" + $targetdomain) -Subject $jobname -SmtpServer $smtpserver -body $output
			} catch {
				write-Slog "$jobname" "ERR" "Issue sending SMTP report to '$ReportSMTP' using SMTPServer: '$SMTPServer'" $false
			}
		}	
	}
}

function Start-EMProcessDistributionGroupBatch() {
<#
.SYNOPSIS
	Processes distribution groups in batches

.DESCRIPTION
	This cmdlet runs the Start-EMProcessDistributionGroup cmdlet against many groups in a batch. It will also provide a batch log and has options to send a notification email when is it done.

.PARAMETER Samaccountnames
	This is an array of samaccountname attributes you want the cmdlet to batch process.

.PARAMETER SourceCred
	Specify the source credentials of the source domain.

.PARAMETER TargetCred
	Specify the target credentials of the target domain.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER Activity
	Specify whether you want to MIGRATE or GALSYNC.

.PARAMETER Mode
	Specify whether you want to PREPARE or LOGONLY.

.PARAMETER SourceEndPoint
	Specify the source end point for the source Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER TargetEndPoint
	Specify the target end point for the target Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER Separate
	Specifies whether to break the cross-forest relationship and apply limitations to the secondary object.

.PARAMETER Threads
	Specify how many threads you would like to create for parallel execution of Start-EMProcessMailbox

.PARAMETER ReportSMTP
	The email address you would like a notification sent to when the batch completes.

.PARAMETER SMTPServer
	The SMTP relay server to use when sending an email.

#>

#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][array]$Samaccountnames = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceDomain = $Script:ModuleSourceDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain = $Script:ModuleTargetDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity = $Script:ModuleActivity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode = $Script:ModuleMode,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint = $Script:ModuleSourceEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint = $Script:ModuleTargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][int]$Threads=$Script:ModuleThreads,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$ReportSMTP = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SMTPServer= $null
	)
	Process {
		$samaccountnames = $samaccountnames | sort | get-unique
		$total = $null; $total = ($samaccountnames | measure).count
		$warnings = 0
		$throws = 0
		$sleep = 5
		$timestamp = ("{0:yyyyMMddHHmmss}" -f (get-date)).tostring()
		$jobname = $null; $jobname = "EMProcessDistributionGroupBatch$($timestamp)"
		$EMPath = (get-module exchangemigration).path
		$errorcount = 0

		if ($reportsmtp) {
			if ($reportsmtp -notmatch "^[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$") {
				write-Slog "$jobname" "ERR" "'$reportsmtp' is not a valid SMTP address. Unable to continue" $false
			}
			if ($reportsmtp -and !($smtpserver)) {
				write-Slog "$jobname" "ERR" "Must provide SMTPServer if using ReportSMTP. Unable to continue" $false
			}
		}

		#Starting
		write-host ""
		write-host "Job:`t`t$($jobname)"
		$start = $(get-date)
		write-host "Started:`t$($start)"
		$n = 0
		foreach ($samaccountname in $samaccountnames) {
			$n++
			write-progress -activity "$jobname" -status "Processing $n of $($total): '$samaccountname'" -percentcomplete (($n) / $total*100)
			start-job -name $jobname -ScriptBlock {
				sleep -s $(get-random -Minimum 5 -Maximum 60);
				try{import-module "$using:EMPath"}catch{throw}; try{import-module activedirectory}catch{throw};
				sleep -s $(get-random -Minimum 5 -Maximum 60);
				write-Slog "$using:samaccountname" "LOG" "'$using:jobname' started" $false | out-null
				Start-EMProcessDistributionGroup -Samaccountname $using:samaccountname `
				-SourceCred $using:sourcecred `
				-TargetCred $using:targetcred `
				-SourceDomain $using:sourcedomain `
				-TargetDomain $using:targetdomain `
				-Activity $using:activity `
				-Mode $using:mode `
				-SourceEndPoint $using:sourceendpoint `
				-TargetEndPoint $using:targetendpoint `
				-Separate $using:separate | out-null;
				write-Slog "$using:samaccountname" "LOG" "'$using:jobname' ended" $false | out-null
				} | out-null				
			write-Slog "$jobname" "LOG" "Samaccountname: $samaccountname SourceDomain: $sourcedomain; TargetDomain: $targetdomain; Activity: $Activity; Mode: $Mode; SourceEndPoint: $SourceEndPoint; TargetEndPoint: $TargetEndPoint; Separate: $Separate;" $false | out-null
			sleep -s 1
    			while($(get-job -name $jobname | ? {$_.state -eq 'running'}).Count -ge $threads) {
          				sleep -s $sleep			
     			}
			
			#tidy
			get-job -name $jobname | ? {$_.state -ne 'running'} | remove-job -Force -Confirm:$false
		}
		sleep -s 1; [System.GC]::Collect()
		
		#Completing
		write-host "Completing:`t$(get-date)"
    		while($(get-job -name $jobname | ? {$_.state -eq 'running'})) {          					
			sleep -s $sleep			
     		}
		
		#Finishing
		foreach ($samaccountname in $samaccountnames) {
			try {
				try {
					$emlog = $null; $emlog = Read-EMLogs -identity $samaccountname
				} catch {
					write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname Notes: Logs not found"  $false | out-null
				}

				if ($($emlog | ? {$_.comment -match $jobname} | measure).count -ne 2) {
					write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname Notes: Job not found or complete in logs" $false | out-null
				}

				$readout = $false
				foreach ($line in $emlog) {
					if ($line.comment -match $jobname -and $line.comment -match "ended") {$readout = $false}
					if ($readout) {
						if ($line.type -eq "ERR") {
							write-Slog "$jobname" "ERR" "Samaccountname: $samaccountname" $false | out-null
						}
					}
					if ($line.comment -match $jobname -and $line.comment -match "started") {$readout = $true}
				}				
			} catch {
				$errorcount += 1
			}
		}

		$summary = $null; $summary =  "Total $total ERR $errorcount"
		write-Slog "$jobname" "LOG" "$summary" $false | out-null
		get-job -name $jobname | remove-job -Force -Confirm:$false
		$end = $(get-date)
		$output = $null; $output = "Completed:`t$($end) `nDuration:`t$([math]::round((new-timespan -Start $start -End (get-date)).totalminutes)) minutes `nSummary:`t$summary"
		write-host $output
		write-host

		if ($reportsmtp) {
			try {
				Send-MailMessage -To $ReportSMTP -From $("EM@" + $targetdomain) -Subject $jobname -SmtpServer $smtpserver -body $output
			} catch {
				write-Slog "$jobname" "ERR" "Issue sending SMTP report to '$ReportSMTP' using SMTPServer: '$SMTPServer'" $false
			}
		}	
	}
}

# Mailboxes
################################################################################################################
function Start-EMProcessMailbox() { 
<#
.SYNOPSIS
	Processes a mailbox for migration

.DESCRIPTION
	This cmdlet is used to prepare and migrate a mailbox from the source to the target Exchange Organization.

.PARAMETER Samaccountname
	This is the samaccountname attribute of the mailbox you want the cmdlet to process.

.PARAMETER SourceCred
	Specify the source credentials of the source domain.

.PARAMETER TargetCred
	Specify the target credentials of the target domain.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER Activity
	Specify whether you want to MIGRATE or GALSYNC.

.PARAMETER Mode
	Specify whether you want to PREPARE or LOGONLY.

.PARAMETER MoveMailbox
	Specify what move request operation you would like to perform. It is possible to select SUSPEND which will copy up to 95% of the mail data but will not complete. 

.PARAMETER SourceEndPoint
	Specify the source end point for the source Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER TargetEndPoint
	Specify the target end point for the target Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER Link
	Specified whether to link the primary object, i.e. the mailbox, to the secondary object, i.e. the user object in the opposite Active Directory forest.

.PARAMETER Separate
	Specifies whether to break the cross-forest relationship and apply limitations to the secondary object.

.PARAMETER wait
	For mailbox move request operations you can specify whether to wait for the move request to complete. On full mailbox moves this will result in the required post migration tasks being applied. If you don't wait then Start-EMProcessMailbox will need to be run manually after the move request has completed.


#>

#===============================================================================================================

	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Samaccountname = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceDomain = $Script:ModuleSourceDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain = $Script:ModuleTargetDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity = $Script:ModuleActivity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode = $Script:ModuleMode,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox = $Script:ModuleMoveMailbox,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint = $Script:ModuleSourceEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint = $Script:ModuleTargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Link = $Script:ModuleLink,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate = $Script:ModuleSeparate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait = $Script:ModuleWait

	)
	Process {
		#formatting
		$sourcedomain = $sourcedomain.toupper()
		$targetdomain = $targetdomain.toupper()
		$sourceendpoint = $sourceendpoint.toupper()
		$targetendpoint = $targetendpoint.toupper()
		$activity = $activity.toupper()
		$Mode = $Mode.toupper()
		$MoveMailbox = $MoveMailbox.toupper()

		write-Slog "$samaccountname" "GO" "$activity mailbox"
		write-Slog "$samaccountname" "LOG" "SourceDomain: $sourcedomain; TargetDomain: $targetdomain; Activity: $Activity; Mode: $Mode; MoveMailbox: $MoveMailbox; SourceEndPoint: $SourceEndPoint; TargetEndPoint: $TargetEndPoint; Link: $Link; Separate: $Separate;"
		
		# start checks
		if ($MoveMailbox -match "Yes|Suspend" -and ($activity -eq 'GALSync')) {
			write-Slog "$samaccountname" "ERR" "Unable to move mailboxes for the activity GALSync"
		}

		if ($MoveMailbox -match "Yes|Suspend" -and !($SourceEndPoint)) {
			write-Slog "$samaccountname" "ERR" "SourceEndPoint required when moving mailboxes"
		}

		if ($movemailbox -match "Yes|Suspend" -and $Mode -ne 'Prepare') {
			write-Slog "$samaccountname" "ERR" "Unable to move mailbox when mode is $Mode"
		}

		if ($link -eq $true -and ($mode -ne 'Prepare' -or $separate -eq $true -or $activity -eq "galsync")) {
			write-Slog "$samaccountname" "WARN" "Unable to link mailbox when Mode is not '$Mode', Separate is '$Separate', or Activity is '$activity'. Forcing Link to $false"
			$Link = $false
		}

		#get source data
		try {
			try {
				$sourcepdc = $null; $sourcedomainsid = $null; $sourceNBdomain = $null
				get-addomain  -Server $sourcedomain -credential $sourcecred -ea stop | % {
					$sourcepdc = $_.pdcemulator
					$sourcedomainsid = $_.domainsid.value
					$sourcenbdomain = $_.netbiosname.tostring()
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting domain information for source domain '$sourcedomain'"
			}

			$smeu = $null; $smeu = get-aduser -server $sourcepdc -filter {mailnickname -like "*" -and samaccountname -eq $samaccountname} -properties * -credential $sourcecred -ea stop 
			if (($smeu | measure).count -gt 1) {
				write-Slog "$samaccountname" "ERR" "Multiple user objects returned from source domain '$sourcedomain'. Unable to continue"
			}
		} catch {
			write-Slog "$samaccountname" "ERR" "Issue getting mail enabled user from source domain '$sourcedomain'"
		}

		if (!($smeu)) {
			write-Slog "$samaccountname" "ERR" "No mail enabled user object found in source domain '$sourcedomain'"
		} else {
			try {
				$SourceType = $null; $SourceType = Get-EMRecipientTypeDetails -type $smeu.msexchrecipienttypedetails
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting source type from '$sourcedomain'"
			}
		}

		#get target data
		try {
			try {
				$targetpdc = $null; $targetdomainsid = $null; $targetNBdomain = $null
				get-addomain  -Server $targetdomain -credential $targetcred -ea stop | % {
					$targetpdc = $_.pdcemulator
					$targetdomainsid = $_.domainsid.value
					$targetnbdomain = $_.netbiosname.tostring()
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting domain information for target domain '$targetdomain'"
			}
			$tmeu = $null; $tmeu = get-aduser -server $targetpdc -filter {samaccountname -eq $samaccountname} -properties * -credential $targetcred -ea stop 
			if (($tmeu | measure).count -gt 1) {
				write-Slog "$samaccountname" "ERR" "Multiple user objects returned from target domain '$targetdomain'. Unable to continue"
			}

		} catch {
			write-Slog "$samaccountname" "ERR" "Issues getting user from target domain '$targetdomain'"
		}

		if (!($tmeu) -and $activity -eq "migrate") {
			write-Slog "$samaccountname" "ERR" "Target not found in target domain '$targetdomain' and is required for activity '$activity'"
		}

		if ($tmeu) {
			try {
				$TargetType = $null; $TargetType = Get-EMRecipientTypeDetails -type $tmeu.msexchrecipienttypedetails
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting target type from '$targetdomain'"
			}
		}

		try {
			$detected = $null; $detected = Get-EMConflict -samaccountname $samaccountname -Source $smeu -sourcepdc $sourcepdc -targetpdc $targetpdc -sourcedomain $sourcedomain -targetdomain $targetdomain -sourcecred $sourcecred -targetcred $targetcred -targetendpoint $targetendpoint
		} catch {
			write-Slog "$samaccountname" "ERR" "Issue detecting conflict in target domain '$($targetdomain)'"
		}

		if ($detected) {
			$detected | select samaccountname,distinguishedname,mailnickname,proxyaddresses | % {
				write-slog "$samaccountname" "WARN" "Conflict $($_ | convertto-json -compress)"
			}
			write-Slog "$samaccountname" "ERR" "SMTP, X500, or Alias conflict detected in target domain '$($targetdomain)'"
		}

		$meu = [pscustomobject]@{
			SamAccountName = $samaccountname
			Activity = $Activity
			Source = $smeu
			SourceType = $SourceType
			SourceDomain = $SourceDomain.toupper()
			SourceNBDomain = $sourcenbdomain
			SourcePDC = $SourcePDC.toupper()
			SourceDomainSID = $sourcedomainsid
			Target = $tmeu
			TargetType = $TargetType
			TargetDomain = $TargetDomain
			TargetNBDomain = $targetnbdomain
			TargetPDC = $TargetPDC.toupper()
			TargetDomainSID = $targetdomainsid
			TargetCred = $TargetCred
			SourceCred = $SourceCred
			Mode = $Mode
			MoveMailbox = $MoveMailbox
			SourceEndPoint = $SourceEndPoint
			TargetEndPoint = $TargetEndPoint
			Link = $Link
			Separate = $Separate
			Wait = $Wait
		}

		write-Slog "$samaccountname" "LOG" "SourceType: $($sourcetype); SourcePDC: $($meu.sourcepdc); TargetType: $($targettype); TargetPDC: $($targetpdc)"
		$meu | Start-EMMailboxPrep
	}
}

function Start-EMMailboxPrep() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceType,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourcePDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomainSID,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetType,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomainSID,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Link = $false,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Separate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait
	)
	Process {
		#determine action
		$next = $null
		$primary = $null
		if ($source -eq $null) {
			write-Slog "$samaccountname" "ERR" "Not found in source domain '$sourcedomain'. Unable to continue"
			$next = "Stop"
		} else {
			if ($SourceType -eq $TargetType) {
				write-Slog "$samaccountname" "ERR" "source and target recipient types are the same. Unable to continue"
				$next = "Stop"	
			}

			#Migration activity handling
			if ($Activity -eq "migrate" -and !($target)) {
				write-Slog "$samaccountname" "ERR" "MIGRATE requires a target user object. Unable to continue"
				$next = "Stop"
			}
			
			if ($Activity -eq "migrate" -and $target) {
				if ($target.distinguishedname -match $Script:ModuleTargetGALSyncOU) {
					write-Slog "$samaccountname" "WARN" "MIGRATE target user object located in GALSync OU '$Script:ModuleTargetGALSyncOU'"
				}
			}			
			
			#GALsync activity handling
			if ($activity -eq "galsync" -and !($target)) {
				write-Slog "$samaccountname" "LOG" "Primary: SOURCE"
				write-Slog "$samaccountname" "AR" "Target user object to be created in '$Script:ModuleTargetGALSyncOU'"
				$primary = "Source"
				$next = "CreateTargetGALUser"
			}

			
			if ($activity -eq "galsync" -and $target) {
				if ($target.distinguishedname -notmatch $Script:ModuleTargetGALSyncOU) {
					write-Slog "$samaccountname" "WARN" "GALSync target user object not located in GALSync OU '$Script:ModuleTargetGALSyncOU'"
				}
			}
			
			#other
			if (!($next) -AND ($SourceType -match "^usermailbox$|^linkedmailbox$|^sharedmailbox$|^roommailbox$|^equipmentmailbox$" -and !($TargetType))) {
				write-Slog "$samaccountname" "AR" "Source is primary. Target to be mail enabled"
				$primary = "Source"
				$next = "MailEnableTargetUser"
			}

			if (!($next) -AND ($SourceType -match "^usermailbox$|^linkedmailbox$|^sharedmailbox$|^roommailbox$|^equipmentmailbox$" -and ($TargetType))) {
				write-Slog "$samaccountname" "LOG" "Primary: SOURCE"
				$primary= "Source"
				$next = "PrepareSourceAndTarget"
			}

			if (!($next) -AND ($SourceType -match "^mailuser$|^linkeduser$|^remoteusermailbox$|^remoteroommailbox$|^remoteequipmentmailbox$|^remotesharedmailbox$" -and $TargetType -match "^usermailbox$|^linkedmailbox$|^sharedmailbox$|^roommailbox$|^equipmentmailbox$")) {
				write-Slog "$samaccountname" "LOG" "Primary: TARGET"
				$primary= "Target"
				$next = "PrepareSourceAndTarget"
			}

			if (!($next) -AND ($SourceType -notmatch "^usermailbox$|^linkedmailbox$|^sharedmailbox$|^roommailbox$|^equipmentmailbox$" -and $TargetType -notmatch "^usermailbox$|^linkedmailbox$|^sharedmailbox$|^roommailbox$|^equipmentmailbox$")) {
				write-Slog "$samaccountname" "ERR" "No mailboxes detected. Unable to continue"
			}
		}

		if ($mode -eq "logonly"){
			$next = "Stop"
		}

		if ($next -ne "stop") {
			#calculate source SMTP addresses
			$sourcePrimarySMTP = $null; $sourcePrimarySMTP = ($source.proxyaddresses | ? {$_ -cmatch "^SMTP:"}) -replace "SMTP:",""
			if (($sourcePrimarySMTP | measure).count -gt 1) {
				write-Slog "$samaccountname" "ERR" "source has multiple primary SMTP addresses. Unable to continue"
				$next = "Stop"
			}
			if (($sourcePrimarySMTP | measure).count -eq 0) {
				write-Slog "$samaccountname" "ERR" "Source has no primary SMTP address. Unable to continue"
				$next = "Stop"
			}
		
			$SourceRoutingSMTP = $null; $SourceRoutingSMTP = $("$($Source.mailnickname)@mail.on$($sourcedomain)").tolower()

			#prepare mode object
			$Modeobj = [pscustomobject]@{
				Samaccountname = $samaccountname
				Source = $source
				SourceDomain = $SourceDomain
				SourceNBDomain = $SourceNBDomain
				SourcePDC = $SourcePDC
				Target = $target
				TargetDomain = $TargetDomain
				TargetNBDomain = $TargetNBDomain
				TargetPDC = $TargetPDC
				Mode = $Mode
				SourcePrimarySMTP = $SourcePrimarySMTP
				SourceRoutingSMTP = $SourceRoutingSMTP
				TargetCred = $TargetCred
				SourceCred = $SourceCred
				Primary = $Primary
				Activity = $Activity
				MoveMailbox = $MoveMailbox
				SourceEndPoint = $SourceEndPoint
				TargetEndPoint = $TargetEndPoint
				Sourcetype = $sourcetype
				Targettype = $targettype
				SourceDomainSID = $SourceDomainSID
				TargetDomainSID = $TargetDomainSID
				Link = $Link
				Separate = $Separate
				Wait = $Wait
			}

			#apply action
			if ($next -eq "MailEnableTargetUser") {
				if ($mode -eq "prepare") {
					$Modeobj | Start-EMMailEnableTargetUser
				} else {
					write-Slog "$samaccountname" "LOG" "Not mail enabling target user due to mode"
					$next = "Stop"
				}
			}

			if ($next -eq "CreateTargetGALUser") {
				if ($mode -eq "prepare") {
					$Modeobj | New-EMTargetGALUser
				} else {
					write-Slog "$samaccountname" "LOG" "Not creating target GAL user due to mode"
					$next = "Stop"
				}
			}

			if ($next -eq "PrepareSourceAndTarget") {
				$Modeobj | Start-EMPrepareUserObjects 
			}

		}

		if ($next -eq "Stop") {
			write-Slog "$samaccountname" "LOG" "Ready"
		}
	}	
}

function Start-EMMailEnableTargetUser() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceRoutingSMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourcePrimarySMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Link = $false,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Separate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait
	)
	Process {

		$completed = $null
		$secondsmax = $null; $secondsmax = 300
		$secondsinc = $null; $secondsinc = 30
		$start = $null; $start = get-date
	
		try {
			invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "enable-mailuser -identity $($target.objectguid.guid) -externalemailaddress $($SourceRoutingSMTP) -primarysmtpaddress $($SourcePrimarySMTP) -domaincontroller $($targetpdc) -ea stop" | out-null 
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem mail enabling in target domain '$targetdomain'"
		}

		write-Slog "$samaccountname" "LOG" "Waiting for mail enabled object to be ready in target domain '$targetdomain'. Waiting up to $secondsmax seconds"
		Do {				
			$invresult = $null;	
			try {
				$invresult = invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-mailuser -identity $($target.objectguid.guid) -domaincontroller $($targetpdc) -ea stop" #| out-null 
				$completed = $true
			} catch{sleep -s $secondsinc}

			if ($($invresult | measure).count -gt 1) {write-Slog "$samaccountname" "ERR" "Multiple objects found in target domain '$targetdomain'. Unable to continue"}

			if ((new-timespan -Start $start -End (get-date)).seconds -ge $secondsmax) {
				write-Slog "$samaccountname" "ERR" "Timeout mail enabling. Unable to continue"
			}
			write-Slog "$samaccountname" "LOG" "Waited $([math]::round((new-timespan -Start $start -End (get-date)).totalseconds)) seconds"				

		} while (!($completed))

		if ($completed) {
			write-Slog "$samaccountname" "LOG" "mail enabled OK in target domain '$targetdomain'"
			Start-EMProcessMailbox -SourceDomain $sourcedomain -TargetDomain $targetdomain -Samaccountname $samaccountname -SourceCred $SourceCred -TargetCred $TargetCred  -Mode $Mode -Activity $activity -MoveMailbox $MoveMailbox -SourceEndPoint $SourceEndPoint -TargetEndPoint $TargetEndPoint -Link $Link -Separate $Separate -Wait $Wait
		}
	}
}

function New-EMTargetGALUser() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Link = $false,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Separate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait
	)
	Process {
		try {
			$t = 300
			$path = $Script:ModuleTargetGALSyncOU
			New-ADUser -UserPrincipalName ("$samaccountname" + "@" + "$($targetdomain.tolower())") -SamAccountName $samaccountname -Path $path -Name $samaccountname -Server $targetpdc -credential $targetcred -ea stop
			write-Slog "$samaccountname" "OK" "GAL user object created in target domain '$targetdomain'"
			write-Slog "$samaccountname" "LOG" "Waiting for user object to be ready in target domain '$targetdomain'. Waiting up to $t seconds"
			$n = 0
			
			while ($n -lt $t) {
				$esid = $null; $esid = $(try{(get-aduser -server $targetpdc -filter {samaccountname -eq $samaccountname} -credential $targetcred).sid.tostring()}catch{}) 
				if ($($esid | measure).count -gt 1) {write-Slog "$samaccountname" "WARN" "Multiple objects found in target domain '$targetdomain'";throw}
				if ($esid) {				
					if ($(try {invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-user $esid -domaincontroller $targetpdc"}catch{})) {
						Start-EMProcessMailbox -SourceDomain $sourcedomain -TargetDomain $targetdomain -Samaccountname $samaccountname -SourceCred $SourceCred -TargetCred $TargetCred  -Mode $Mode -Activity $activity -MoveMailbox $MoveMailbox -SourceEndPoint $SourceEndPoint -TargetEndPoint $TargetEndPoint -Link $Link -Separate $Separate -Wait $Wait
						break
					} else {				
						sleep -s 1; $n++
					}
				} else {
					sleep -s 1; $n++
				}
			}
				
			if ($n -ge $t) {
				throw
			}
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem creating GAL user object in target domain '$targetdomain'"
		}
	}
}


function Start-EMPrepareUserObjects() { 
	#===============================================================================================================
		[cmdletbinding()]
		Param (
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceNBDomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomainSID,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceType,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetType,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetNBDomain,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomainSID,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Primary,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceRoutingSMTP,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Link = $false,
			[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Separate,
			[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait
		)
		Process {	
	
			#calcs
			#calculate target routing SMTP address
			try {
				$targetRoutingSMTP = $null; $targetRoutingSMTP = $("$($target.mailnickname)@mail.on$($targetdomain)").tolower()
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing target routing SMTP address"
			}
	
			#calculate source routing X500 address
			try {
				$sourceRoutingX500 = $null; $sourceRoutingX500 = $("X500:" + $source.legacyexchangedn)
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing source routing X500 address"
			}
	
			#calculate target routing X500 address
			try {
				$targetRoutingX500 = $null; $targetRoutingX500 = $("X500:" + $target.legacyexchangedn)
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing target routing X500 address"
			}
	
			#direction
			if ($primary -eq "source") {		
				$primaryobj = $source
				$secondaryobj = $target	
				$primarynbdomain = $null; $primarynbdomain = $sourcenbdomain
				$secondarynbdomain = $null; $secondarynbdomain = $targetnbdomain
				$primarydomain = $null; $primarydomain = $sourcedomain
				$secondarydomain = $null; $secondarydomain = $targetdomain
				$primaryendpoint = $null; $primaryendpoint = $sourceendpoint
				$secondaryendpoint = $null; $secondaryendpoint = $targetendpoint
				$primarypdc = $null; $primarypdc = $sourcepdc
				$secondarypdc = $null; $secondarypdc = $targetpdc
				$primarycred = $null; $primarycred = $sourcecred
				$secondarycred = $null; $secondarycred = $targetcred
				$primaryroutingsmtp = $null; $primaryroutingsmtp = $sourceroutingsmtp
				$secondaryroutingsmtp = $null; $secondaryroutingsmtp = $targetroutingsmtp
				$primaryroutingx500 = $null; $primaryroutingx500 = $sourceRoutingX500
				$secondaryroutingx500 = $null; $secondaryroutingx500 = $targetRoutingX500
				$primarytype = $null; $primarytype = $sourcetype
				$secondarytype = $null; $secondarytype = $targettype
				$primarydomainsid = $null; $primarydomainsid = $sourcedomainsid
				$secondarydomainsid = $null; $secondarydomainsid = $targetdomainsid
				$PrimaryGALSyncOU = $null; $PrimaryGALSyncOU = $Script:ModuleSourceGALSyncOU
				$SecondaryGALSyncOU = $null; $SecondaryGALSyncOU = $Script:ModuleTargetGALSyncOU
				
			}
	
			if ($primary -eq "target") {	
				$primaryobj = $target
				$secondaryobj = $source			
				$primarynbdomain = $null; $primarynbdomain = $targetnbdomain
				$secondarynbdomain = $null; $secondarynbdomain = $sourcenbdomain
				$primarydomain = $null; $primarydomain = $targetdomain
				$secondarydomain = $null; $secondarydomain = $sourcedomain
				$primaryendpoint = $null; $primaryendpoint = $targetendpoint
				$secondaryendpoint = $null; $secondaryendpoint = $sourceendpoint
				$primarypdc = $null; $primarypdc = $targetpdc
				$secondarypdc = $null; $secondarypdc = $sourcepdc
				$primarycred = $null; $primarycred = $targetcred
				$secondarycred = $null; $secondarycred = $sourcecred
				$primaryroutingsmtp = $null; $primaryroutingsmtp = $targetroutingsmtp
				$secondaryroutingsmtp = $null; $secondaryroutingsmtp = $sourceroutingsmtp
				$primaryroutingx500 = $null; $primaryroutingx500 = $targetRoutingX500
				$secondaryroutingx500 = $null; $secondaryroutingx500 = $sourceRoutingX500
				$primarytype = $null; $primarytype = $targettype
				$secondarytype = $null; $secondarytype = $sourcetype
				$primarydomainsid = $null; $primarydomainsid = $targetdomainsid
				$secondarydomainsid = $null; $secondarydomainsid = $sourcedomainsid
				$PrimaryGALSyncOU = $null; $PrimaryGALSyncOU = $Script:ModuleTargetGALSyncOU
				$SecondaryGALSyncOU = $null; $SecondaryGALSyncOU = $Script:ModuleSourceGALSyncOU
			}
	
			$pupdate = $false
			$supdate = $false
	
			#displayname
			if ($($primaryobj.displayname) -ne $($secondaryobj.displayname)) {
				write-Slog "$samaccountname" "AR" "Secondary displayname attr update required: $($primaryobj.displayname)"
				$secondaryobj.displayname = $primaryobj.displayname
				$supdate = $true
			}
	
			#givenName
			if ($($primaryobj.givenName) -ne $($secondaryobj.givenName)) {
				write-Slog "$samaccountname" "AR" "Secondary givenName attr update required: $($primaryobj.givenName)"
				$secondaryobj.givenName = $primaryobj.givenName
				$supdate = $true
			}
	
			#Sn
			if ($($primaryobj.Sn) -ne $($secondaryobj.Sn)) {
				write-Slog "$samaccountname" "AR" "Secondary Sn attr update required: $($primaryobj.Sn)"
				$secondaryobj.Sn = $primaryobj.Sn
				$supdate = $true
			}
	
			#mail
			if ($($primaryobj.mail) -ne $($secondaryobj.mail)) {
				write-Slog "$samaccountname" "AR" "Secondary mail attr update required: $($primaryobj.mail)"
				$secondaryobj.mail = $primaryobj.mail
				$supdate = $true
			}
	
			#mailnickname
			if ($($primaryobj.mailnickname) -ne $($secondaryobj.mailnickname)) {
				write-Slog "$samaccountname" "AR" "Secondary mailnickname attr update required: $($primaryobj.mailnickname)"
				$secondaryobj.mailnickname = $primaryobj.mailnickname
				$supdate = $true
			}
	
			#msexchmailboxguid
			try {$pguid = $null; $pguid = (new-object guid @(,$primaryobj.msExchMailboxGUID)).guid}catch{}
			try {$sguid = $null; $sguid = (new-object guid @(,$secondaryobj.msExchMailboxGUID)).guid}catch{}
			
			if (!($pguid)) {
				write-Slog "$samaccountname" "ERR" "Primary msExchMailboxGuid attribute cannot be null"
			}
	
			if ($pguid -ne $sguid) {
				write-Slog "$samaccountname" "AR" "Secondary msExchMailboxGuid attr update required"
				$secondaryobj.msExchMailboxGuid = $primaryobj.msExchMailboxGuid
				$supdate = $true
				$sguidupdate = $true
			}
	
			#msexcharchiveguid
			try {$paguid = $null; $paguid = (new-object guid @(,$primaryobj.msExchArchiveGUID)).guid}catch{}
			try {$saguid = $null; $saguid = (new-object guid @(,$secondaryobj.msExchArchiveGUID)).guid}catch{}
	
			if ($paguid -ne $saguid) {
				write-Slog "$samaccountname" "AR" "Secondary msExchArchiveGuid attr update required: $paguid"
				$secondaryobj.msExchArchiveGuid = $primaryobj.msExchArchiveGuid
				$supdate = $true
			}
	
			#msExchUserCulture
			if ($($primaryobj.msExchUserCulture) -ne $($secondaryobj.msExchUserCulture)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchUserCulture attr update required: $($primaryobj.msExchUserCulture)"
				$secondaryobj.msExchUserCulture = $primaryobj.msExchUserCulture
				$supdate = $true
			}
	
			#countryCode
			if ($($primaryobj.countryCode) -ne $($secondaryobj.countryCode)) {
				write-Slog "$samaccountname" "AR" "Secondary countryCode attr update required: $($primaryobj.countryCode)"
				$secondaryobj.countryCode = $primaryobj.countryCode
				$supdate = $true
			}
	
			#msExchELCMailboxFlags
			if ($($primaryobj.msExchELCMailboxFlags) -ne $($secondaryobj.msExchELCMailboxFlags)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchELCMailboxFlags attr update required: $($primaryobj.msExchELCMailboxFlags)"
				$secondaryobj.msExchELCMailboxFlags = $primaryobj.msExchELCMailboxFlags
				$supdate = $true
			}
	
			#textEncodedORAddress
			if ($($primaryobj.textEncodedORAddress) -ne $($secondaryobj.textEncodedORAddress)) {
				write-Slog "$samaccountname" "AR" "Secondary textEncodedORAddress attr update required"
				$secondaryobj.textEncodedORAddress = $primaryobj.textEncodedORAddress
				$supdate = $true
			}
	
			#extensionAttribute1
			if ($($primaryobj.extensionAttribute1) -ne $($secondaryobj.extensionAttribute1)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute1 attr update required"
				$secondaryobj.extensionAttribute1 = $primaryobj.extensionAttribute1
				$supdate = $true
			}
	
			#extensionAttribute2
			if ($($primaryobj.extensionAttribute2) -ne $($secondaryobj.extensionAttribute2)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute2 attr update required"
				$secondaryobj.extensionAttribute2 = $primaryobj.extensionAttribute2
				$supdate = $true
			}
	
			#extensionAttribute3
			if ($($primaryobj.extensionAttribute3) -ne $($secondaryobj.extensionAttribute3)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute3 attr update required"
				$secondaryobj.extensionAttribute3 = $primaryobj.extensionAttribute3
				$supdate = $true
			}
	
			#extensionAttribute4
			if ($($primaryobj.extensionAttribute4) -ne $($secondaryobj.extensionAttribute4)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute4 attr update required"
				$secondaryobj.extensionAttribute4 = $primaryobj.extensionAttribute4
				$supdate = $true
			}
	
			#extensionAttribute5
			if ($($primaryobj.extensionAttribute5) -ne $($secondaryobj.extensionAttribute5)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute5 attr update required"
				$secondaryobj.extensionAttribute5 = $primaryobj.extensionAttribute5
				$supdate = $true
			}
	
			#extensionAttribute6
			if ($($primaryobj.extensionAttribute6) -ne $($secondaryobj.extensionAttribute6)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute6 attr update required"
				$secondaryobj.extensionAttribute6 = $primaryobj.extensionAttribute6
				$supdate = $true
			}
	
			#extensionAttribute7
			if ($($primaryobj.extensionAttribute7) -ne $($secondaryobj.extensionAttribute7)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute7 attr update required"
				$secondaryobj.extensionAttribute7 = $primaryobj.extensionAttribute7
				$supdate = $true
			}
	
			#extensionAttribute8
			if ($($primaryobj.extensionAttribute8) -ne $($secondaryobj.extensionAttribute8)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute8 attr update required"
				$secondaryobj.extensionAttribute8 = $primaryobj.extensionAttribute8
				$supdate = $true
			}
	
			#extensionAttribute9
			if ($($primaryobj.extensionAttribute9) -ne $($secondaryobj.extensionAttribute9)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute9 attr update required"
				$secondaryobj.extensionAttribute9 = $primaryobj.extensionAttribute9
				$supdate = $true
			}
	
			#extensionAttribute10
			if ($($primaryobj.extensionAttribute10) -ne $($secondaryobj.extensionAttribute10)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute10 attr update required"
				$secondaryobj.extensionAttribute10 = $primaryobj.extensionAttribute10
				$supdate = $true
			}
	
			#extensionAttribute11
			if ($($primaryobj.extensionAttribute11) -ne $($secondaryobj.extensionAttribute11)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute11 attr update required"
				$secondaryobj.extensionAttribute11 = $primaryobj.extensionAttribute11
				$supdate = $true
			}
	
			#extensionAttribute12
			if ($($primaryobj.extensionAttribute12) -ne $($secondaryobj.extensionAttribute12)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute12 attr update required"
				$secondaryobj.extensionAttribute12 = $primaryobj.extensionAttribute12
				$supdate = $true
			}
	
			#extensionAttribute13
			if ($($primaryobj.extensionAttribute13) -ne $($secondaryobj.extensionAttribute13)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute13 attr update required"
				$secondaryobj.extensionAttribute13 = $primaryobj.extensionAttribute13
				$supdate = $true
			}
	
			#extensionAttribute14
			if ($($primaryobj.extensionAttribute14) -ne $($secondaryobj.extensionAttribute14)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute14 attr update required"
				$secondaryobj.extensionAttribute14 = $primaryobj.extensionAttribute14
				$supdate = $true
			}
	
			#extensionAttribute15
			if ($($primaryobj.extensionAttribute15) -ne $($secondaryobj.extensionAttribute15)) {
				write-Slog "$samaccountname" "AR" "Secondary extensionAttribute15 attr update required"
				$secondaryobj.extensionAttribute15 = $primaryobj.extensionAttribute15
				$supdate = $true
			}

			#authOrig (users allowed to send to the recipient)
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute authOrig -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.authOrig -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.authOrig) $($sdns)}catch{})) -or ($($secondaryobj.authOrig) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary authOrig attr update required"
					$secondaryobj.authOrig = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary authOrig attr"
				}
			}

			#unauthOrig (users not allowed to send to the recipient)
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute unauthOrig -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.unauthOrig -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.unauthOrig) $($sdns)}catch{})) -or ($($secondaryobj.unauthOrig) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary unauthOrig attr update required"
					$secondaryobj.unauthOrig = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary unauthOrig attr"
				}
			}

			#dLMemSubmitPerms (groups allowed to send to the recipient)	
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute dLMemSubmitPerms -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.dLMemSubmitPerms -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.dLMemSubmitPerms) $($sdns)}catch{})) -or ($($secondaryobj.dLMemSubmitPerms) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary dLMemSubmitPerms attr update required"
					$secondaryobj.dLMemSubmitPerms = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary dLMemSubmitPerms attr"
				}
			}

			#dLMemRejectPerms (groups not allowed to send to the recipient)
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute dLMemRejectPerms -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.dLMemRejectPerms -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc 
			if (($(try{compare-object $($secondaryobj.dLMemRejectPerms) $($sdns)}catch{})) -or ($($secondaryobj.dLMemRejectPerms) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary dLMemRejectPerms attr update required"
					$secondaryobj.dLMemRejectPerms = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary dLMemRejectPerms attr"
				}
			}
	
			#msExchHideFromAddressLists / msExchSenderHintTranslations (mailtips)
			if ($separate -eq $false -and $activity -eq "migrate") {
				if ($($primaryobj.msExchHideFromAddressLists) -ne $($secondaryobj.msExchHideFromAddressLists)) {
					write-Slog "$samaccountname" "AR" "Secondary msExchHideFromAddressLists attr update required"
					$secondaryobj.msExchHideFromAddressLists = $primaryobj.msExchHideFromAddressLists
					$supdate = $true
				}
				if ($($primaryobj.msExchSenderHintTranslations) -ne $($secondaryobj.msExchSenderHintTranslations)) {
					write-Slog "$samaccountname" "AR" "Secondary msExchSenderHintTranslations attr update required"
					$secondaryobj.msExchSenderHintTranslations = $primaryobj.msExchSenderHintTranslations
					$supdate = $true
				}
			}

			if ($separate -eq $true -or $activity -eq "GALSync") {
				if ($($secondaryobj.msExchHideFromAddressLists) -ne $true) {
					write-Slog "$samaccountname" "AR" "Secondary msExchHideFromAddressLists attr update required"
					$secondaryobj.msExchHideFromAddressLists = $true
					$supdate = $true
				}
				$tip = $null; $tip = "default:<html>`n<body>`nPlease be aware this is an external recipient.`n</body>`n</html>`n"	
				
				if ($($secondaryobj.msExchSenderHintTranslations) -ne $tip -or (!($secondaryobj.msExchSenderHintTranslations))) {
					write-Slog "$samaccountname" "AR" "Secondary msExchSenderHintTranslations attr update required"
					$secondaryobj.msExchSenderHintTranslations = $tip
					$supdate = $true
				}
			}

			#disable sender auth requirement
			if ($($primaryobj.msExchRequireAuthToSendTo) -eq $true) {
				write-Slog "$samaccountname" "AR" "Primary msExchRequireAuthToSendTo attr update required"
				$primaryobj.msExchRequireAuthToSendTo = $false
				$pupdate = $true
			}

			if ($($secondaryobj.msExchRequireAuthToSendTo) -eq $true) {
				write-Slog "$samaccountname" "AR" "Secondary msExchRequireAuthToSendTo attr update required"
				$secondaryobj.msExchRequireAuthToSendTo = $false
				$supdate = $true
			}
	
			#targetaddress
			if ($($primaryobj.targetaddress) -ne $null) {
				try {
					write-Slog "$samaccountname" "AR" "Primary targetaddress attr update required"
					$primaryobj.targetaddress = $null
					$pupdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing primary targetaddress"
				}
			}
			
			if ($separate -eq $false) {
				if ($($secondaryobj.targetaddress) -ne $primaryRoutingSMTP) {
					try {
						write-Slog "$samaccountname" "AR" "Secondary targetaddress attr update required"
						$secondaryobj.targetaddress = $primaryRoutingSMTP
						$supdate = $true
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem preparing secondary targetaddress"
					}
				}
			}
	
			if ($separate -eq $true) {
				$emailaddr = $null; $emailaddr = $secondaryobj | select @{label="email";expression={$secondaryobj.proxyaddresses | ? {$_ -cmatch "^SMTP:"}}} | % {$_.email -replace "SMTP:",""}
				if (($emailaddr | measure).count -ne 1)  {
					write-Slog "$samaccountname" "ERR" "Problem calculating secondary targetaddress for separation"
				}
				if ($($secondaryobj.targetaddress) -ne $secondaryobj.mail) {
					try {
						write-Slog "$samaccountname" "AR" "Secondary targetaddress attr update required"
						$secondaryobj.targetaddress = $secondaryobj.mail
						$supdate = $true
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem preparing secondary targetaddress"
					}
				}
			}
	
			#quotas
			if ($($primaryobj.mDBOverHardQuotaLimit) -ne $($secondaryobj.mDBOverHardQuotaLimit)) {
				write-Slog "$samaccountname" "AR" "Secondary mDBOverHardQuotaLimit attr update required"
				$secondaryobj.mDBOverHardQuotaLimit = $primaryobj.mDBOverHardQuotaLimit
				$supdate = $true
			}
	
			if ($($primaryobj.mDBOverQuotaLimit) -ne $($secondaryobj.mDBOverQuotaLimit)) {
				write-Slog "$samaccountname" "AR" "Secondary mDBOverQuotaLimit attr update required"
				$secondaryobj.mDBOverQuotaLimit = $primaryobj.mDBOverQuotaLimit
				$supdate = $true
			}
	
			if ($($primaryobj.mDBStorageQuota) -ne $($secondaryobj.mDBStorageQuota)) {
				write-Slog "$samaccountname" "AR" "Secondary mDBStorageQuota attr update required"
				$secondaryobj.mDBStorageQuota = $primaryobj.mDBStorageQuota
				$supdate = $true
			}
	
			if ($($primaryobj.mDBUseDefaults) -ne $($secondaryobj.mDBUseDefaults)) {
				write-Slog "$samaccountname" "AR" "Secondary mDBUseDefaults attr update required"
				$secondaryobj.mDBUseDefaults = $primaryobj.mDBUseDefaults
				$supdate = $true
			}

			#maximum size restrictions
			if ($($primaryobj.delivContLength) -ne $($secondaryobj.delivContLength)) {
				try {
					write-Slog "$samaccountname" "AR" "Secondary delivContLength attr update required"
					$secondaryobj.delivContLength = $primaryobj.delivContLength
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem setting secondary delivContLength attr"
				}
			}

			if ($($primaryobj.submissionContLength) -ne $($secondaryobj.submissionContLength)) {
				try {
					write-Slog "$samaccountname" "AR" "Secondary submissionContLength attr update required"
					$secondaryobj.submissionContLength = $primaryobj.submissionContLength
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem setting secondary submissionContLength attr"
				}
			}

			#forwarding
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute altRecipient -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.altRecipient -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($sdns | measure).count -gt 1) {write-Slog "$samaccountname" "ERR" "Secondary altRecipient too many objects returned. Unable to continue"}
			if (($(try{compare-object $($secondaryobj.altRecipient) $($sdns)}catch{})) -or ($($secondaryobj.altRecipient) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary altRecipient attr update required"
					$secondaryobj.altRecipient = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary altRecipient attr"
				}
			}
			if ($secondaryobj.altRecipient){
				if (($secondaryobj.deliverAndRedirect) -ne $($primaryobj.deliverAndRedirect)) {
					try {
						write-Slog "$samaccountname" "AR" "Secondary deliverAndRedirect attr update required"
						$secondaryobj.deliverAndRedirect = $($primaryobj.deliverAndRedirect)
						$supdate = $true
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem preparing secondary deliverAndRedirect"
					}
				}
			} else {
				if ($($secondaryobj.deliverAndRedirect) -ne $null) {
					try {
						write-Slog "$samaccountname" "AR" "Secondary deliverAndRedirect attr update required"
						$secondaryobj.deliverAndRedirect = $null
						$supdate = $true
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem preparing secondary deliverAndRedirect"
					}
				}
			}					

			#recipient limits
			if ($($primaryobj.msExchRecipLimit) -ne $($secondaryobj.msExchRecipLimit)) {
				try {
					write-Slog "$samaccountname" "AR" "Secondary msExchRecipLimit attr update required"
					$secondaryobj.msExchRecipLimit = $primaryobj.msExchRecipLimit
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchRecipLimit attr"
				}
			}
			
			#enabled
			if ($Activity -eq "migrate" -and $Separate -eq $false) {
				if ($secondaryobj.enabled -ne $primaryobj.enabled) {
					write-Slog "$samaccountname" "WARN" "Secondary enabled attr does not match primary"
				}
			}

			if ($Activity -eq "galsync" -or $Separate -eq $true) {
				if ($secondaryobj.enabled -eq $true) {
					write-Slog "$samaccountname" "AR" "Secondary user object to be disabled due to Activity '$Activity' or Separate '$Separate'"
					$secondaryobj.enabled = $false
					$supdate = $true			
				}
			}

			if ($primarytype -match "shared") {
				if ($primaryobj.enabled -eq $true) {
					write-Slog "$samaccountname" "AR" "Primarytype is '$primarytype'. Primary user object to be disabled"
					$primaryobj.enabled = $false
					$pupdate = $true			
				}
				if ($secondaryobj.enabled -eq $true) {
					write-Slog "$samaccountname" "AR" "Primarytype is '$primarytype'. Secondary user object to be disabled"
					$secondaryobj.enabled = $false
					$supdate = $true			
				}
			}
	
			#proxyaddresses
			$pproxsticky = $null; $pproxsticky = $primaryobj.proxyaddresses -notmatch "^smtp:|^x500:"
			$sproxsticky = $null; $sproxsticky = $secondaryobj.proxyaddresses -notmatch "^smtp:|^x500"
			$pprox = $primaryobj.proxyaddresses -match "^smtp:|^x500"
			$sprox = $pprox
	
			#primary
			#smtp
			if ($pprox -notcontains $("smtp:" + $primaryRoutingSMTP)) {
				$pprox += $("smtp:" + $primaryRoutingSMTP)
			}
	
			#nonsmtp
			$pproxsticky | % {$pprox += $_}
			if ($pprox -notcontains $secondaryRoutingX500) {
				$pprox += $secondaryRoutingX500
			}
	
			#remove unwanted
			$pprox = $pprox -notmatch "mail\.on$($secondarydomain)$"
			$pprox = $pprox -notmatch [regex]::escape($primaryRoutingX500)
	
			#formatting
			$pproxarray = $null; $pproxarray = @(); $pprox | % {$pproxarray += ($_.tostring())}	
	
			if ($(try{compare-object $($primaryobj.proxyaddresses) $($pproxarray)}catch{}) -or ($($primaryobj.proxyaddresses) -xor $($pproxarray))) {
				try {
					write-Slog "$samaccountname" "AR" "Primary proxyaddresses attr update required"
					$primaryobj.proxyaddresses = $pproxarray
					$pupdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing primary proxyaddresses attr"
				}
			}
	
			#secondary
			#smtp
			if ($sprox -notcontains $("smtp:" + $secondaryRoutingSMTP)) {
				$sprox += $("smtp:" + $secondaryRoutingSMTP)
			}
	
			#nonsmtp
			$sproxsticky | % {$sprox += $_}
			if ($sprox -notcontains $primaryRoutingX500) {
				$sprox += $primaryRoutingX500
			}
	
			#remove unwanted
			$sprox = $sprox -notmatch "mail\.on$($primarydomain)$"
			$sprox = $sprox -notmatch [regex]::escape($secondaryRoutingX500)
	
			#formatting
			$sproxarray = $null; $sproxarray = @(); $sprox | % {$sproxarray += ($_.tostring())}
	
			if ($(try{compare-object $($secondaryobj.proxyaddresses) $($sproxarray)}catch{}) -or $($($secondaryobj.proxyaddresses) -xor $($sproxarray))) {
				try {
					write-Slog "$samaccountname" "AR" "Secondary proxyaddresses attr update required"
					$secondaryobj.proxyaddresses = $sproxarray
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary proxyaddresses attr"
				}
			}	
	
			#remote mailbox settings
			if ($primarytype -match "^usermailbox$|^linkedmailbox$" -and $secondarytype -ne "remoteusermailbox") {
				try {
					write-Slog "$samaccountname" "AR" "Converting secondary to remote user mailbox"
					$secondaryobj.msExchRecipientDisplayType = "-2147483642"
					$secondaryobj.msExchRecipientTypeDetails = "2147483648"
					$secondaryobj.msExchRemoteRecipientType = "1"
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem converting secondary to remote user mailbox. Unable to continue"
				}
			}
	
			if ($primarytype -eq "sharedmailbox" -and $secondarytype -ne "remotesharedmailbox") {
				try {
					write-Slog "$samaccountname" "AR" "Converting secondary to remote shared mailbox"
					$secondaryobj.msExchRecipientDisplayType = "-2147483642"
					$secondaryobj.msExchRecipientTypeDetails = "34359738368"
					$secondaryobj.msExchRemoteRecipientType = "1"
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem converting secondary to remote shared mailbox. Unable to continue"
				}
			}

			if ($primarytype -match "shared" -and $primaryobj.enabled -eq $true) {
				try {
					write-Slog "$samaccountname" "AR" "Disabling user object for primary '$primarytype'"
					$primaryobj.enabled = $false
					$pupdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem disabling user object for primary '$primarytype'. Unable to continue"
				}
			}

			if ($primarytype -match "shared" -and $secondaryobj.enabled -eq $true) {
				try {
					write-Slog "$samaccountname" "AR" "Disabling user object for secondary '$secondarytype'"
					$secondaryobj.enabled = $false
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem disabling user object for secondary '$secondarytype'. Unable to continue"
				}
			}
	
			if ($primarytype -eq "roommailbox" -and $secondarytype -ne "remoteroommailbox") {
				try {
					write-Slog "$samaccountname" "AR" "Converting secondary to remote room mailbox"
					$secondaryobj.msExchRecipientDisplayType = "-2147481850"
					$secondaryobj.msExchRecipientTypeDetails = "8589934592"
					$secondaryobj.msExchRemoteRecipientType = "1"
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem converting secondary to remote room mailbox. Unable to continue"
				}
			}
	
			if ($primarytype -eq "equipmentmailbox" -and $secondarytype -ne "remoteequipmentmailbox") {
				try {
					write-Slog "$samaccountname" "AR" "Converting secondary to remote equipment mailbox"
					$secondaryobj.msExchRecipientDisplayType = "-2147481594"
					$secondaryobj.msExchRecipientTypeDetails = "17179869184"
					$secondaryobj.msExchRemoteRecipientType = "1"
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem converting secondary to remote equipment mailbox. Unable to continue"
				}
			}
	
			#room and equipment external meeting processing
			if ($primarytype -match "^roommailbox$|^equipmentmailbox$") {
				try {
					$calproc = $null; $calproc = invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-calendarprocessing -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop" 
					$BookinPolicy = $null; $BookinPolicy = $calproc | select -ExpandProperty bookinpolicy | % {Convertto-DistinguishedName -Samaccountname $samaccountname -CanonicalName $_}
					$RequestInPolicy = $null; $RequestInPolicy = $calproc | select -ExpandProperty RequestInPolicy | % {Convertto-DistinguishedName -Samaccountname $samaccountname -CanonicalName $_}
					$RequestOutOfPolicy = $null; $RequestOutOfPolicy = $calproc | select -ExpandProperty RequestOutOfPolicy | % {Convertto-DistinguishedName -Samaccountname $samaccountname -CanonicalName $_}

					# need to apply after mailbox migration
					if ($primary -eq "source") {
						$BookinPolicyGUIDs = $null; $BookinPolicyGUIDs = @(); $BookinPolicyGUIDs = Get-EMSecondaryGUIDs -Attribute BookInPolicy -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $BookinPolicy -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
						Write-EMData -Identity $samaccountname -Type BookInPolicy -Data $BookinPolicyGUIDs

						$RequestInPolicyGUIDs = $null; $RequestInPolicyGUIDs = @(); $RequestInPolicyGUIDs = Get-EMSecondaryGUIDs -Attribute RequestInPolicy -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $RequestInPolicy -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
						Write-EMData -Identity $samaccountname -Type RequestInPolicy -Data $RequestinPolicyGUIDs

						$RequestOutOfPolicyGUIDs = $null; $RequestOutOfPolicyGUIDs = @(); $RequestOutOfPolicyGUIDs = Get-EMSecondaryGUIDs -Attribute RequestOutOfPolicy -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $RequestOutOfPolicy -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
						Write-EMData -Identity $samaccountname -Type RequestOutOfPolicy -Data $RequestOutOfPolicyGUIDs
					}
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem getting calendar processing from primary. Unable to continue"
				}
	
				if (!($calproc.ProcessExternalMeetingMessages)) {
					write-Slog "$samaccountname" "AR" "Setting ProcessExternalMeetingMessages to $true for primary"
					if ($mode -eq "prepare") {
						try {
							write-Slog "$samaccountname" "OK" "Set ProcessExternalMeetingMessages to $true for primary"
							invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "set-calendarprocessing -identity $($primaryobj.objectguid.guid) -ProcessExternalMeetingMessages 1 -domaincontroller $($primarypdc) -ea stop" 
						} catch {
							write-Slog "$samaccountname" "ERR" "Problem setting calendar processing from primary. Unable to continue"
						}
					}
				}
			}
	
			#msExchEnableModeration
			if ($($primaryobj.msExchEnableModeration) -ne $($secondaryobj.msExchEnableModeration)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchEnableModeration attr update required"
				$secondaryobj.msExchEnableModeration = $primaryobj.msExchEnableModeration
				$supdate = $true
			}

			#msExchModerationFlags
			if ($($primaryobj.msExchModerationFlags) -ne $($secondaryobj.msExchModerationFlags)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchModerationFlags attr update required"
				$secondaryobj.msExchModerationFlags = $primaryobj.msExchModerationFlags
				$supdate = $true
			}

			#msExchModeratedByLink
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute msExchModeratedByLink -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.msExchModeratedByLink -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.msExchModeratedByLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchModeratedByLink) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary msExchModeratedByLink attr update required"
					$secondaryobj.msExchModeratedByLink = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary msExchModeratedByLink attr"
				}
			}

			#msExchBypassModerationLink
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute msExchBypassModerationLink -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.msExchBypassModerationLink -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.msExchBypassModerationLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchBypassModerationLink) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary msExchBypassModerationLink attr update required"
					$secondaryobj.msExchBypassModerationLink = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary msExchBypassModerationLink attr"
				}
			}

			#publicdelegates
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute publicdelegates -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.publicdelegates -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.publicdelegates) $($sdns)}catch{})) -or ($($secondaryobj.publicdelegates) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary publicdelegates attr update required"
					$secondaryobj.publicdelegates = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary publicdelegates attr"
				}
			}

			#msExchDelegateListLink (automapping)
			$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute msExchDelegateListLink -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.msExchDelegateListLink -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
			if (($(try{compare-object $($secondaryobj.msExchDelegateListLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchDelegateListLink) -xor $($sdns))) {
				try {				
					write-Slog "$samaccountname" "AR" "Secondary msExchDelegateListLink attr update required"
					$secondaryobj.msExchDelegateListLink = $sdns
					$supdate = $true
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary $Attribute attr"
				}
			}

			#msExchMailboxTemplateLink (retention policies)
			if ($primaryobj.msExchMailboxTemplateLink) {
				try {
					$primarypol = $null; $primarypol = invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-retentionpolicy '$($primaryobj.msExchMailboxTemplateLink)' -domaincontroller $($primarypdc)" 
					if (($primarypol | measure).count -gt 1) {write-Slog "$samaccountname" "WARN" "Multiple retention policies for primary for '$($primaryobj.msExchMailboxTemplateLink)'";throw}
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem getting retention policy data from primary for '$($primaryobj.msExchMailboxTemplateLink)'. Unable to continue"
				}

				try {
					$allsecpols = $null; $allsecpols = invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command "get-retentionpolicy -domaincontroller $($secondarypdc)" 					
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem getting retention policy data from secondary for '$($primarypol.retentionid)'. Unable to continue"
				}
					
				$secondarypol = $null
				if ($allsecpols) {
					$secondarypol = $allsecpols | ? {$_.retentionid -eq $($primarypol.retentionid)}
				} else {
					write-Slog "$samaccountname" "ERR" "Secondary retention policies not found. Unable to continue"
				}

				if ($secondarypol) {
					if ($secondaryobj.msExchMailboxTemplateLink -ne $($secondarypol.distinguishedname)) {
						write-Slog "$samaccountname" "AR" "Secondary msExchMailboxTemplateLink attr update required"
						$secondaryobj.msExchMailboxTemplateLink = $($secondarypol.distinguishedname)
						$supdate = $true
					}
				} else {
					write-Slog "$samaccountname" "WARN" "Retention policy with retentionid '$($primarypol.retentionid)' does not exist in secondary"

					$defpol = $null; $defpol = $allsecpols | ? {$_.name -match "^Default MRM Policy$|^Default Archive and Retention Policy$"}
					if ($($defpol | measure).count -eq 0) {
						write-Slog "$samaccountname" "ERR" "No default retention policy found in secondary. Unable to continue"
					}
					if ($($defpol | measure).count -gt 1) {
						write-Slog "$samaccountname" "ERR" "Multiple default retention policies found in secondary. Unable to continue"
					}
					if ($($defpol | measure).count -eq 1) {
						write-Slog "$samaccountname" "AR" "Assigning default retention policy '$($defpol.name)' to secondary"
						$secondaryobj.msExchMailboxTemplateLink = $($defpol.distinguishedname)
						$supdate = $true
					}					
				}
			}
	
			#msExchPoliciesExcluded msExchPoliciesIncluded (do not apply email address policies)
			if ($mode -eq "prepare") {
				if ($primaryobj.msExchPoliciesExcluded -notcontains '{26491cfc-9e50-4857-861b-0cb8df22b5d7}') {
					write-Slog "$samaccountname" "AR" "Primary msExchPoliciesExcluded attr update required"
					$primaryobj.msExchPoliciesExcluded = '{26491cfc-9e50-4857-861b-0cb8df22b5d7}'
					$pupdate = $true
				}
				if ($primaryobj.msExchPoliciesIncluded -ne $null) {
					write-Slog "$samaccountname" "AR" "Primary msExchPoliciesIncluded attr update required"
					$primaryobj.msExchPoliciesIncluded = $null
					$pupdate = $true
				}
				if ($secondaryobj.msExchPoliciesExcluded -notcontains '{26491cfc-9e50-4857-861b-0cb8df22b5d7}') {
					write-Slog "$samaccountname" "AR" "Secondary msExchPoliciesExcluded attr update required"
					$secondaryobj.msExchPoliciesExcluded = '{26491cfc-9e50-4857-861b-0cb8df22b5d7}'
					$supdate = $true
				}
				if ($secondaryobj.msExchPoliciesIncluded -ne $null) {
					write-Slog "$samaccountname" "AR" "Secondary msExchPoliciesIncluded attr update required"
					$secondaryobj.msExchPoliciesIncluded = $null
					$supdate = $true
				}
			}

			# single item recovery
			if ($($primaryobj.deletedItemFlags) -ne $($secondaryobj.deletedItemFlags)) {
				write-Slog "$samaccountname" "AR" "Secondary deletedItemFlags attr update required"
				$secondaryobj.deletedItemFlags = $primaryobj.deletedItemFlags
				$supdate = $true
			}

			if ($($primaryobj.garbageCollPeriod) -ne $($secondaryobj.garbageCollPeriod)) {
				write-Slog "$samaccountname" "AR" "Secondary garbageCollPeriod attr update required"
				$secondaryobj.garbageCollPeriod = $primaryobj.garbageCollPeriod
				$supdate = $true
			}
	
			#commit changes
			if ($Mode -eq "Prepare") {
				try {
					if ($pupdate -eq $true) {
						set-aduser -instance $primaryobj -server $primarypdc -Credential $primaryCred -ea stop 
						write-Slog "$samaccountname" "OK" "Primary user prepared in domain '$primarydomain'"
					}
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing primary user in domain '$primarydomain'"
				}
			
				try {
					if ($supdate -eq $true) {
						set-aduser -instance $secondaryobj -server $secondarypdc -Credential $secondaryCred -ea stop 
						write-Slog "$samaccountname" "OK" "Secondary user prepared in domain '$secondarydomain'"
					}	
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem preparing secondary user in domain '$secondarydomain'"
				}
	
				if ($supdate -eq $true -and $sguidupdate -eq $true) {
					$completed = $null
					$secondsmax = $null; $secondsmax = 300
					$secondsinc = $null; $secondsinc = 30
					$start = $null; $start = get-date
					if (!($pguid)) {write-Slog "$samaccountname" "ERR" "Primary guid missing. Unable to continue"}
	
					write-Slog "$samaccountname" "LOG" "Waiting for secondary AD changes to be ready. Waiting up to $secondsmax seconds"					
					Do {						
						try {
							invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command "get-user $pguid -domaincontroller $($secondarypdc) -ea stop" | out-null 	 					
							$completed = $true
						} catch{sleep -s $secondsinc}	
						
						if ((new-timespan -Start $start -End (get-date)).seconds -ge $secondsmax) {
							write-Slog "$samaccountname" "ERR" "AD preparation timeout. Unable to continue"
						}
						write-Slog "$samaccountname" "LOG" "Waited $([math]::round((new-timespan -Start $start -End (get-date)).totalseconds)) seconds"							
					} while (!($completed))
				}
			}

			#move mailbox if req
			if ($activity -eq "migrate") {
				#movehistory
				$movehistory = $null; try {$movehistory = invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-moverequest -identity $($target.objectguid.guid) -domaincontroller $($targetpdc)"} catch {} 
				if (($movehistory | measure).count -gt 1) {write-Slog "$samaccountname" "ERR" "Multiple move requests found. Unable to continue"}
				if ($movehistory) {$movehistory = $movehistory.status.tostring()}
	
					$moveobj = $null; $moveobj = [pscustomobject]@{
						Source = $Source
						Target = $Target
						SourceDomain = $SourceDomain
						TargetDomain = $TargetDomain
						SamAccountname = $Samaccountname
						SourceCred = $sourcecred
						TargetCred = $targetcred
						Activity = $Activity
						SourceEndPoint = $SourceEndPoint
						TargetEndPoint = $TargetEndPoint
						TargetRoutingSMTP = $TargetRoutingSMTP
						SourcePDC = $SourcePDC
						TargetPDC = $targetPDC
						Mode = $Mode
						MoveMailbox = $MoveMailbox
						MoveHistory = $MoveHistory
						Link = $Link
						Separate = $Separate
						Wait = $Wait
					}
					
					if ($movehistory) {
						switch ($($movehistory)) {
							"Completed" 	{
										write-Slog "$samaccountname" "LOG" "Move request state: $($movehistory)"

										# process the Data directory to apply post migration actions
										$actions = $null; 
										try {
											$actions = $(Read-EMData -Identity $samaccountname)
										} catch {
											write-Slog "$samaccountname" "WARN" "Issue reading post migration actions. Unable to continue"	
										}
										if ($actions -and $primary -eq "target") {
											write-Slog "$samaccountname" "LOG" "Post migration actions detected"
											$actions | % {
												$action = $null; $action = $_
												$actiontype = $null; $actiontype = $_.type
												$actiondata = $null; $actiondata = $_.data
												if (!($actiondata)) {$actiondata = "`$null"}
												switch ($actiontype) {
													"BookInPolicy"	{
														try {
															write-Slog "$samaccountname" "AR" "'BookInPolicy' attr update required"
															invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "set-calendarprocessing -identity $($primaryobj.objectguid.guid) -BookInPolicy $($actiondata -join ",") -domaincontroller $($primarypdc) -ea stop" 
															write-Slog "$samaccountname" "OK" "'BookInPolicy' attr updated"
															$action | Update-EMData -Identity $samaccountname
														} catch {
															write-Slog "$samaccountname" "WARN" "'BookInPolicy' issue updating"
														}	
													}
													"RequestInPolicy"	{
														try {
															write-Slog "$samaccountname" "AR" "'RequestInPolicy' attr update required"
															invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "set-calendarprocessing -identity $($primaryobj.objectguid.guid) -RequestInPolicy $($actiondata -join ",") -domaincontroller $($primarypdc) -ea stop" 
															write-Slog "$samaccountname" "OK" "'RequestInPolicy' attr updated"
															$action | Update-EMData -Identity $samaccountname
														} catch {
															write-Slog "$samaccountname" "WARN" "'RequestInPolicy' issue updating"
														}	
													}
													"RequestOutOfPolicy"	{
														try {
															write-Slog "$samaccountname" "AR" "'RequestOutOfPolicy' attr update required"
															invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "set-calendarprocessing -identity $($primaryobj.objectguid.guid) -RequestOutOfPolicy $($actiondata -join ",") -domaincontroller $($primarypdc) -ea stop" 
															write-Slog "$samaccountname" "OK" "'RequestOutOfPolicy' attr updated"
															$action | Update-EMData -Identity $samaccountname
														} catch {
															write-Slog "$samaccountname" "WARN" "'RequestOutOfPolicy' issue updating"
														}	
													}
													default {write-Slog "$samaccountname" "WARN" "Type '$($actiontype)' unsupported and will be ignored"}
												} 
											}
										}
									}
							"AutoSuspended" 	{							
										if ($mode -eq "prepare" -and $movemailbox -match "^yes$|^suspend$") {
											write-Slog "$samaccountname" "AR" "Resuming move request. Move request state: $($movehistory)"
											$moveobj | Start-EMMigrateMailbox; return
										}
									}
								
							default 		{
										write-Slog "$samaccountname" "ERR" "Move request in unsupported state: $($movehistory). Unable to continue"					
									}					
						}
					}
	
					if (!($movehistory)) {					
						if ($mode -eq "prepare" -and $movemailbox -match "yes|suspend") {
							write-Slog "$samaccountname" "AR" "Creating move request. Move request state: None"
							$moveobj | Start-EMMigrateMailbox; return
						}
					}
	
				$checkperms = $false
				if ($movehistory -match "^completed$|^autosuspended$" -or (!($movehistory))) {
					$checkperms = $true
				}
			
				#permissions
				if ($checkperms -and $separate -eq $false -and $activity -eq "migrate") {
					#full access
					write-Slog "$samaccountname" "LOG" "Checking full access permissions on primary"
					try {
						if(!($($primaryobj.objectguid.guid))){write-Slog "$samaccountname" "WARN" "Primary missing guid";throw}
						$mperms = $null; $mperms = invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-mailboxpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.accessrights -eq 'fullaccess' -and $_.deny -eq $false}  
					} catch {
						write-Slog "$samaccountname" "ERR" "Issue checking full access permissions on primary"
					}
					
					if ($mperms) {			
						foreach ($perm in $mperms) {
							if ($perm.user -match "^($primarynbdomain)\\") {
								$sam = $null; $sam = $perm.user -replace ($primarynbdomain + "\\"),""
								if (!($mperms | ? {$_.user -match "^$secondarynbdomain\\$sam$"})) {
									write-Slog "$samaccountname" "AR" "'$("$secondarynbdomain\$sam")' full access missing"
									if ($Mode -eq "prepare") {
										try {
											if (get-adobject -filter {samaccountname -eq $sam} -server $secondarypdc -Credential $secondarycred -ea stop) {
												invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "add-mailboxpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $("$secondarynbdomain\$sam") -accessrights fullaccess -automapping 0" | out-null 
												write-Slog "$samaccountname" "OK" "'$("$secondarynbdomain\$sam")' full access added"						
											} else {
												write-Slog "$samaccountname" "WARN" "'$("$secondarynbdomain\$sam")' does not exist in domain '$secondarydomain'"
											}
										} catch {
											write-Slog "$samaccountname" "WARN" "'$("$secondarynbdomain\$sam")' issue adding full access permission and will be excluded"
										}
									} else {
										write-Slog "$samaccountname" "WARN" "No full access changes committed due to mode"
									}
								}
							}
	
							if ($perm.user -match "^($secondarynbdomain)\\") {
								$sam = $null; $sam = $perm.user -replace ($secondarynbdomain + "\\"),""
								if (!($mperms | ? {$_.user -match "^$primarynbdomain\\$sam$"}) -and $sam -ne $samaccountname) {
									write-Slog "$samaccountname" "AR" "'$("$primarynbdomain\$sam")' full access missing"
									if ($Mode -eq "prepare") {
										try {
											if (get-adobject -filter {samaccountname -eq $sam} -server $primarypdc -Credential $primarycred -ea stop) {									
												invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "add-mailboxpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $("$primarynbdomain\$sam") -accessrights fullaccess -automapping 0" | out-null 
												write-Slog "$samaccountname" "OK" "'$("$primarynbdomain\$sam")' full access added"
											} else {
												write-Slog "$samaccountname" "WARN" "'$("$primarynbdomain\$sam")' does not exist in domain '$primarydomain'"
											}
										} catch {
											write-Slog "$samaccountname" "WARN" "'$("$primarynbdomain\$sam")' issue adding full access permission and will be excluded"
										}
									} else {
										write-Slog "$samaccountname" "WARN" "No full access changes committed due to mode"
									}
								}
							}	
						}
					}
					
					#send-as
					write-Slog "$samaccountname" "LOG" "Checking send-as permissions on primary"
					try {
						$adperms = $null; $adperms =  invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
					} catch {
						write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on primary"
					}
		
					if ($adperms) {			
						foreach ($perm in $adperms) {
							if ($perm.user -match "^($primarynbdomain)\\") {
								$sam = $null; $sam = $perm.user -replace ($primarynbdomain + "\\"),""
								if (!($adperms | ? {$_.user -match "^$secondarynbdomain\\$sam$"})) {
									write-Slog "$samaccountname" "AR" "'$("$secondarynbdomain\$sam")' send-as missing"
									if ($Mode -eq "prepare") {
										try {
											if (get-adobject -filter {samaccountname -eq $sam} -server $secondarypdc -Credential $secondarycred -ea stop) {									
												invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "add-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $("$secondarynbdomain\$sam") -accessrights extendedright -extendedrights send-as" | out-null 
												write-Slog "$samaccountname" "OK" "'$("$secondarynbdomain\$sam")' send-as added"									
											} else {
												write-Slog "$samaccountname" "WARN" "'$("$secondarynbdomain\$sam")' does not exist in domain '$secondarydomain'"
											}
										} catch {
											write-Slog "$samaccountname" "WARN" "'$("$secondarynbdomain\$sam")' issue adding send-as permission and will be excluded"
										}
									} else {
										write-Slog "$samaccountname" "WARN" "No send-as changes committed due to mode"
									}
								}
							}
							if ($perm.user -match "^($secondarynbdomain)\\") {
								$sam = $null; $sam = $perm.user -replace ($secondarynbdomain + "\\"),""
								if (!($adperms | ? {$_.user -match "^$primarynbdomain\\$sam$"}) -and $sam -ne $samaccountname) {
									write-Slog "$samaccountname" "AR" "'$("$primarynbdomain\$sam")' send-as missing"
									if ($Mode -eq "prepare") {
										try {
											if (get-adobject -filter {samaccountname -eq $sam} -server $primarypdc -Credential $primarycred -ea stop) {									
												invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "add-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $("$primarynbdomain\$sam") -accessrights extendedright -extendedrights send-as" | out-null 
												write-Slog "$samaccountname" "OK" "'$("$primarynbdomain\$sam")' send-as added"
											} else {
												write-Slog "$samaccountname" "WARN" "'$("$primarynbdomain\$sam")' does not exist in domain '$primarydomain'"
											}
										} catch {
											write-Slog "$samaccountname" "WARN" "'$("$primarynbdomain\$sam")' issue adding send-as permission and will be excluded"
										}
									} else {	
										write-Slog "$samaccountname" "WARN" "No send-as changes committed due to mode"
									}
								}
							}
						}
					}	
				}
			}
	
			#permissions on separate or galsync
			if ($separate -eq $true -or $activity -eq "galsync") {
				#full access
				write-Slog "$samaccountname" "LOG" "Checking full access permissions on primary"
				try {
					if(!($($primaryobj.objectguid.guid))){write-Slog "$samaccountname" "WARN" "Primary missing guid";throw}
					$mperms = $null; $mperms = invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-mailboxpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.accessrights -eq 'fullaccess' -and $_.deny -eq $false}  
				} catch {
					write-Slog "$samaccountname" "ERR" "Issue checking full access permissions on primary"
				}
			
				if ($mperms) {			
					foreach ($perm in $mperms) {
						if ($perm.user -match "^$($secondarynbdomain)\\") {
							write-Slog "$samaccountname" "AR" "'$($perm.user)' full access to be removed"
							try {
								invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command $("remove-mailboxpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $($perm.user) -accessrights fullaccess" + ' -confirm:$false') | out-null 
								write-Slog "$samaccountname" "OK" "'$($perm.user)' full access removed"
							} catch {
								write-Slog "$samaccountname" "WARN" "'$($perm.user)' issue removing full access permission and will be excluded"
							}
						}
					}
				}
				#send-as
				write-Slog "$samaccountname" "LOG" "Checking send-as permissions on primary"
				try {
					$adperms = $null; $adperms =  invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
				} catch {
					write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on primary"
				}	
				
				if ($adperms) {			
					foreach ($perm in $adperms) {
						if ($perm.user -match "^$($secondarynbdomain)\\") {
							write-Slog "$samaccountname" "AR" "'$($perm.user)' send-as to be removed"
							try {
								invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command $("remove-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $($perm.user) -accessrights extendedright -extendedrights send-as" + ' -confirm:$false') | out-null 
								write-Slog "$samaccountname" "OK" "'$($perm.user)' send-as removed"
							} catch {
								write-Slog "$samaccountname" "WARN" "'$($perm.user)' issue removing send-as permission and will be excluded"
							}
						}
					}
				}
			}
	
			#link
			if ($mode -eq "prepare" -and $activity -eq "migrate" -and $link -eq $true) {
				if ($primarytype -eq "usermailbox") {
					write-Slog "$samaccountname" "AR" "Converting primary to linked mailbox"
					try {
						
						$masteraccount = $null; $masteraccount = "$($secondarynbdomain)\$($samaccountname)"
						Invoke-Command -ConnectionUri http://$PrimaryEndPoint/powershell -credential $PrimaryCred -ConfigurationName microsoft.exchange -scriptblock {set-user -identity $(($using:primaryobj).objectguid.guid) -linkeddomaincontroller $using:secondarypdc -linkedmasteraccount $using:masteraccount -linkedcredential:$using:secondarycred -domaincontroller $($using:primarypdc) -ea stop} -sessionoption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -allowredirection -warningaction silentlycontinue -ea stop | out-null 
						write-Slog "$samaccountname" "OK" "Primary converted to linked mailbox"
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem converting to linked mailbox. Unable to continue"
					}
				} else {
					if ($primarytype -ne "linkedmailbox") {
						write-Slog "$samaccountname" "WARN" "Unable to convert primary to linked mailbox due to unsupported recipient type '$($primarytype)'"
					}
				}
			}
	
			if (($mode -eq "prepare" -and $activity -eq "migrate" -and $link -eq $false) -or ($mode -eq "prepare" -and $activity -eq "galsync")) {
				if ($primarytype -eq "linkedmailbox") {
					write-Slog "$samaccountname" "AR" "Converting primary to user mailbox"
					try {
						Invoke-Command -ConnectionUri http://$PrimaryEndPoint/powershell -credential $PrimaryCred -ConfigurationName microsoft.exchange -scriptblock {set-user -identity $(($using:primaryobj).objectguid.guid) -linkedmasteraccount $null -domaincontroller $($using:primarypdc) -ea stop} -sessionoption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -allowredirection -warningaction silentlycontinue -ea stop | out-null 
						write-Slog "$samaccountname" "LOG" "Primary converted to user mailbox"
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem converting to user mailbox. Unable to continue"
					}
				}
			}

			#GALSync on separation handling
			if ($activity -eq "GalSync"){
				if ($Secondaryobj.distinguishedname -notmatch $SecondaryGALSyncOU ) {
					write-Slog "$samaccountname" "AR" "Moving secondary to GALSync OU '$SecondaryGALSyncOU'"
					try {
						Move-ADObject -Identity $($Secondaryobj.objectguid.guid) -TargetPath $SecondaryGALSyncOU -Server $secondarypdc -Credential $secondarycred -ea Stop
						write-Slog "$samaccountname" "LOG" "Moved secondary to GALSync OU '$SecondaryGALSyncOU'"
					} catch {
						write-Slog "$samaccountname" "ERR" "Problem moving secondary to GALSync OU '$SecondaryGALSyncOU'"
					}
				}
			}
	
			write-Slog "$samaccountname" "LOG" "Ready"
		}
	}



function Start-EMMigrateMailbox() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourcePDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountname,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetRoutingSMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Yes','No','Suspend')]$MoveMailbox,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$MoveHistory,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][boolean]$Link = $false,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Wait = $Script:ModuleWait
	)
	Process {
		try {
			$tddomain = $null; $tddomain = $tddomain = $source.proxyaddresses
			$tddomain = ($tddomain | ? {$_ -cmatch "^SMTP:"}) -replace "SMTP:",""
			$tddomain = $tddomain.substring($tddomain.indexof("@") + 1,$tddomain.length - $tddomain.indexof("@") -1)
			$tddomain = $tddomain.toupper()
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem preparing target delivery domain for '$targetdomain'"
		}

		$completed = $null
		$secondsmax = $null; $secondsmax = 43200
		$secondsinc = $null; $secondsinc = 30
		$start = $null; $start = get-date

		if ($movehistory) {
			switch ($movehistory) {
				"Completed" 	{
							write-Slog "$samaccountname" "LOG" "Move request state: $($movehistory)"
						}
				"AutoSuspended" 	{
							if ($movemailbox -eq 'Yes') {
								try {
									invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "Resume-MoveRequest -identity $($target.objectguid.guid) -domaincontroller $($targetpdc)" 
									if ($wait) {
										write-Slog "$samaccountname" "OK" "Resumed move request and set to complete. Waiting $secondsmax seconds to complete"
									} else {
										write-Slog "$samaccountname" "OK" "Resumed move request and set to complete."
									}
								} catch {
									write-Slog "$samaccountname" "ERR" "Problem resuming move request"
								}
							}
							if ($movemailbox -eq 'Suspend') {
								try {
									invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "Resume-MoveRequest -identity $($target.objectguid.guid) -SuspendWhenReadyToComplete -domaincontroller $($targetpdc)" 
									if ($wait) {
										write-Slog "$samaccountname" "OK" "Resumed move request and set to suspend. Waiting $secondsmax seconds to suspend"
									} else {
										write-Slog "$samaccountname" "OK" "Resumed move request and set to suspend."
									}
								} catch {
									write-Slog "$samaccountname" "ERR" "Problem resuming move request"
								}
							}
						}
						
				default 		{
							write-Slog "$samaccountname" "ERR" "Move request in unsupported state: $($movehistory). Unable to continue"
						}					
			}
		}

		if (!($movehistory)) {
			if ($movemailbox -eq "Yes") {
				try {
					Invoke-Command -ConnectionUri http://$TargetEndpoint/powershell -credential $TargetCred -ConfigurationName microsoft.exchange -scriptblock {New-MoveRequest -Identity $using:TargetRoutingSMTP -RemoteGlobalCatalog $using:SourcePDC -Remote -RemoteHostName $using:SourceEndPoint -BadItemLimit 1000 -AcceptLargeDataLoss -TargetDeliveryDomain $using:tddomain -domaincontroller $using:targetpdc -remotecredential $using:sourcecred -ea stop -warningaction silentlycontinue} -sessionoption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -allowredirection -warningaction silentlycontinue -ea stop | out-null 
					if ($wait) {
						write-Slog "$samaccountname" "OK" "Move request created. Waiting $secondsmax seconds to complete"
					} else {
						write-Slog "$samaccountname" "OK" "Move request created."
					}

				} catch {
					write-Slog "$samaccountname" "ERR" "Problem creating move request"								
				}
			}
			if ($movemailbox -eq "suspend") {
				try {
					Invoke-Command -ConnectionUri http://$TargetEndpoint/powershell -credential $TargetCred -ConfigurationName microsoft.exchange -scriptblock {New-MoveRequest -Identity $using:TargetRoutingSMTP -RemoteGlobalCatalog $using:SourcePDC -Remote -RemoteHostName $using:SourceEndPoint -BadItemLimit 1000 -AcceptLargeDataLoss -SuspendWhenReadyToComplete -TargetDeliveryDomain $using:tddomain -domaincontroller $using:targetpdc -remotecredential $using:sourcecred -ea stop -warningaction silentlycontinue} -sessionoption (New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck) -allowredirection -warningaction silentlycontinue -ea stop | out-null 
					if ($wait) {
						write-Slog "$samaccountname" "OK" "Move request created and set to suspend. Waiting $secondsmax seconds to suspend"
					} else {
						write-Slog "$samaccountname" "OK" "Move request created and set to suspend."
					}
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem creating move request"								
				}
			}
		}

		if ($wait) {
			Do {	
				sleep -s $secondsinc	
				$movestatus = $null; try {$movestatus = invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-moverequest $($target.objectguid.guid) -domaincontroller $($targetpdc)"} catch {} 
				if ($movestatus) {$movestatus = $movestatus.status.tostring()}
				write-Slog "$samaccountname" "LOG" "Waited $([math]::round((new-timespan -Start $start -End (get-date)).totalseconds)) seconds. State: $($movestatus)"
	
				if ((new-timespan -Start $start -End (get-date)).seconds -ge $secondsmax) {
					write-Slog "$samaccountname" "ERR" "Move request did not complete in $secondsmax seconds. Unable to continue"
				}				
				
				if  ($movestatus -match "warn") {
					write-Slog "$samaccountname" "WARN" "Move request warning detected"
				}

				if  ($movestatus -eq "failed") {
					write-Slog "$samaccountname" "ERR" "Move request failed. Unable to continue"
				}

				if  ($movemailbox -eq "yes" -and $movestatus -eq "Completed") {
					$completed = $true
				}

				if  ($movemailbox -eq "Suspend" -and $movestatus -eq "AutoSuspended") {
					$completed = $true
				}			
			
			} while (!($completed))
	
			if ($completed) {
				write-Slog "$samaccountname" "OK" "Move mailbox request"
				Start-EMProcessMailbox -SourceDomain $sourcedomain -TargetDomain $targetdomain -Samaccountname $samaccountname -SourceCred $SourceCred -TargetCred $TargetCred  -Mode $Mode -Activity $activity -MoveMailbox No -SourceEndPoint $SourceEndPoint -TargetEndPoint $TargetEndPoint -Link $Link -Separate $Separate -Wait $Wait
			}
		} else {
			if ($movemailbox -eq "Yes") {
				write-Slog "$samaccountname" "LOG" "Not waiting for move request to complete. Post migration actions will be required."
			} else {
				write-Slog "$samaccountname" "LOG" "Not waiting for move request to complete."
			}
			write-Slog "$samaccountname" "LOG" "Ready"
		}
	}
}

# Distribution Groups
################################################################################################################
function Start-EMProcessDistributionGroup() { 
<#
.SYNOPSIS
	Process a distribution group.

.DESCRIPTION
	This cmdlet is used to prepare and migrate a distribution group from the source to the target Exchange Organization.

.PARAMETER Samaccountname
	This is the samaccountname attribute of the distribution group you want the cmdlet to process.

.PARAMETER SourceCred
	Specify the source credentials of the source domain.

.PARAMETER TargetCred
	Specify the target credentials of the target domain.

.PARAMETER SourceDomain
	Specify the source domain.

.PARAMETER TargetDomain
	Specify the target domain.

.PARAMETER Activity
	Specify whether you want to MIGRATE or GALSYNC.

.PARAMETER Mode
	Specify whether you want to PREPARE or LOGONLY.

.PARAMETER SourceEndPoint
	Specify the source end point for the source Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER TargetEndPoint
	Specify the target end point for the target Exchange Organization operations. This could be a specific Exchange server, client access array, or load balanced name.

.PARAMETER Separate
	Specifies whether to break the cross-forest relationship and apply limitations to the secondary object.

#>

#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$Samaccountname = $null,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred = $Script:ModuleSourceCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred = $Script:ModuleTargetCred,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceDomain = $Script:ModuleSourceDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain = $Script:ModuleTargetDomain,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity = $Script:ModuleActivity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode = $Script:ModuleMode,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint = $Script:ModuleSourceEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint = $Script:ModuleTargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate

	)
	Process {
		#formatting
		$sourcedomain = $sourcedomain.toupper()
		$targetdomain = $targetdomain.toupper()
		$sourceendpoint = $sourceendpoint.toupper()
		$targetendpoint = $targetendpoint.toupper()
		$activity = $activity.toupper()
		$Mode = $Mode.toupper()

		write-Slog "$samaccountname" "GO" "$activity distribution group"
		write-Slog "$samaccountname" "LOG" "SourceDomain: $sourcedomain; TargetDomain: $targetdomain; Activity: $Activity; Mode: $Mode; SourceEndPoint: $SourceEndPoint; TargetEndPoint: $TargetEndPoint; Separate: $Separate;"

		if ($separate) {
			write-Slog "$samaccountname" "WARN" "Separate parameter not in use and will be ignored"
		}
		
		#get source data
		try {
			try {
				$sourcepdc = $null; $sourcedomainsid = $null; $sourceNBdomain = $null
				get-addomain  -Server $sourcedomain -credential $sourcecred -ea stop | % {
					$sourcepdc = $_.pdcemulator
					$sourcedomainsid = $_.domainsid.value
					$sourcenbdomain = $_.netbiosname.tostring()
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting domain information for source domain '$sourcedomain'"
			}

			$smeg = $null; $smeg = get-adgroup -server $sourcepdc -filter {mailnickname -like "*" -and samaccountname -eq $samaccountname} -properties * -credential $sourcecred -ea stop 
		} catch {
			write-Slog "$samaccountname" "ERR" "Issue getting mail enabled group from '$sourcedomain'"
		}

		if (!($smeg)) {
			write-Slog "$samaccountname" "ERR" "No mail enabled group object found in source domain '$sourcedomain'"
		} else {
			try {
				$SourceType = $null; $SourceType = Get-EMRecipientDisplayType -type $smeg.msexchrecipientdisplaytype
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting source type from '$sourcedomain'"
			}
		}

		if ((($smeg | measure).count) -gt 1) {
			write-Slog "$samaccountname" "ERR" "Duplicate samaccountnames detected in source domain '$($sourcedomain)'"
		}

		#get target data
		try {
			try {
				$targetpdc = $null; $targetdomainsid = $null; $targetNBdomain = $null
				get-addomain  -Server $targetdomain -credential $targetcred -ea stop | % {
					$targetpdc = $_.pdcemulator
					$targetdomainsid = $_.domainsid.value
					$targetnbdomain = $_.netbiosname.tostring()
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting domain information for target domain '$targetdomain'"
			}
			$tmeg = $null; $tmeg = get-adgroup -server $targetpdc -filter {samaccountname -eq $samaccountname} -properties * -credential $targetcred -ea stop 
		} catch {
			write-Slog "$samaccountname" "ERR" "Issues getting group from target domain '$targetdomain'"
		}

		if ((($tmeg | measure).count) -gt 1) {
			write-Slog "$samaccountname" "ERR" "Duplicate samaccountnames detected in target domain '$($targetdomain)'"
		}

		if ($tmeg.msexchrecipientdisplaytype) {
			try {
				$TargetType = $null; $TargetType = Get-EMRecipientDisplayType -type $tmeg.msexchrecipientdisplaytype
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue getting target type from '$targetdomain'"
			}
		}

		try {
			$detected = $null; $detected = Get-EMConflict -samaccountname $samaccountname -Source $smeg -sourcepdc $sourcepdc -targetpdc $targetpdc -sourcedomain $sourcedomain -targetdomain $targetdomain -SourceCred $SourceCred -TargetCred $TargetCred -Targetendpoint $TargetEndPoint
		} catch {
			write-Slog "$samaccountname" "ERR" "Issue detecting conflict in target domain '$($targetdomain)'"
		}

		if ($detected) {
			$detected | select samaccountname,distinguishedname,mailnickname,proxyaddresses | % {
				write-slog "$samaccountname" "WARN" "Conflict $($_ | convertto-json -compress)"
			}
			write-Slog "$samaccountname" "ERR" "SMTP, X500, or Alias conflict detected in target domain '$($targetdomain)'"
		}

		$meg = [pscustomobject]@{
			SamAccountName = $samaccountname
			Activity = $Activity
			Source = $smeg
			SourceType = $SourceType
			SourceDomain = $SourceDomain.toupper()
			SourceNBDomain = $sourcenbdomain
			SourcePDC = $SourcePDC.toupper()
			SourceDomainSID = $sourcedomainsid
			Target = $tmeg
			TargetType = $TargetType
			TargetDomain = $TargetDomain
			TargetNBDomain = $targetnbdomain
			TargetPDC = $TargetPDC.toupper()
			TargetDomainSID = $targetdomainsid
			TargetCred = $TargetCred
			SourceCred = $SourceCred
			Mode = $Mode
			SourceEndPoint = $SourceEndPoint
			TargetEndPoint = $TargetEndPoint
			Separate = $Separate
		}

		write-Slog "$samaccountname" "LOG" "SourceType: $($sourcetype); SourcePDC: $($meg.sourcepdc); TargetType: $($targettype); TargetPDC: $($targetpdc)"
		$meg | Start-EMDistributionGroupPrep
	}
}

function Start-EMDistributionGroupPrep() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$SourceType,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourcePDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomainSID,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetType,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomainSID,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate
	)
	Process {
		#determine action
		$next = $null
		$primary = $null
		if ($source -eq $null) {
			write-Slog "$samaccountname" "ERR" "Not found in source domain '$sourcedomain'. Unable to continue"
			$next = "Stop"
		} else {

			#Migration activity handling
			if ($Activity -eq "migrate" -and !($target)) {
				write-Slog "$samaccountname" "ERR" "MIGRATE requires a target group object. Unable to continue"
			}

			if ($Activity -eq "migrate" -and $target) {
				if ($target.distinguishedname -match $Script:ModuleTargetGALSyncOU) {
					write-Slog "$samaccountname" "WARN" "MIGRATE target group object located in '$Script:ModuleTargetGALSyncOU'"
				}
			}

			#GALsync activity handling
			if ($activity -eq "galsync" -and !($target)) {
				write-Slog "$samaccountname" "AR" "Target group object to be created in '$Script:ModuleTargetGALSyncOU'"
				$next = "CreateTargetGALGroup"
			}

			if ($activity -eq "galsync" -and $target) {
				if ($target.distinguishedname -notmatch $Script:ModuleTargetGALSyncOU) {
					write-Slog "$samaccountname" "WARN" "GALSync target group object not located in '$Script:ModuleTargetGALSyncOU'"
				}
			}

			#other
			if (!($next) -AND ($SourceType -match "^MailUniversalDistributionGroup$|^MailNonUniversalGroup$|^MailUniversalSecurityGroup$" -and !($TargetType))) {
				write-Slog "$samaccountname" "AR" "Target to be mail enabled"
				$next = "MailEnableTargetGroup"
			}

			if (!($next) -AND ($SourceType -match "^MailUniversalDistributionGroup$|^MailNonUniversalGroup$|^MailUniversalSecurityGroup$"  -and ($TargetType -match "^MailUniversalDistributionGroup$|^MailNonUniversalGroup$|^MailUniversalSecurityGroup$"))) {
				$next = "PrepareSourceAndTarget"
			}


		}
		
		#calculate source SMTP addresses
		$sourcePrimarySMTP = $null; $sourcePrimarySMTP = ($source.proxyaddresses | ? {$_ -cmatch "^SMTP:"}) -replace "SMTP:",""
		if (($sourcePrimarySMTP | measure).count -gt 1) {
			write-Slog "$samaccountname" "ERR" "Source has multiple primary SMTP addresses. Unable to continue"
			$next = "Stop"
		}
		if (($sourcePrimarySMTP | measure).count -eq 0) {
			write-Slog "$samaccountname" "ERR" "Source has no primary SMTP address. Unable to continue"
			$next = "Stop"
		}
		
		$SourceRoutingSMTP = $null; $SourceRoutingSMTP = $("$($Source.mailnickname)@mail.on$($sourcedomain)").tolower()

		#prepare mode object
		$Modeobj = [pscustomobject]@{
			Samaccountname = $samaccountname
			Source = $source
			SourceDomain = $SourceDomain
			SourceNBDomain = $SourceNBDomain
			SourcePDC = $SourcePDC
			Target = $target
			TargetDomain = $TargetDomain
			TargetNBDomain = $TargetNBDomain
			TargetPDC = $TargetPDC
			Mode = $Mode
			SourcePrimarySMTP = $SourcePrimarySMTP
			SourceRoutingSMTP = $SourceRoutingSMTP
			TargetCred = $TargetCred
			SourceCred = $SourceCred
			Activity = $Activity
			SourceEndPoint = $SourceEndPoint
			TargetEndPoint = $TargetEndPoint
			Sourcetype = $sourcetype
			Targettype = $targettype
			SourceDomainSID = $SourceDomainSID
			TargetDomainSID = $TargetDomainSID
			Separate = $Separate
		}

		if ($mode -eq "logonly"){
			$next = "Stop"
		}

		#apply action
		if ($next -eq "MailEnableTargetGroup") {
			if ($mode -eq "prepare") {
				$Modeobj | Start-EMMailEnableTargetGroup
			} else {
				write-Slog "$samaccountname" "LOG" "Not mail enabling target group due to mode"
			}
		}

		if ($next -eq "CreateTargetGALGroup") {
			if ($mode -eq "prepare") {
				$Modeobj | New-EMTargetGALGroup
			} else {
				write-Slog "$samaccountname" "LOG" "Not creating target GAL group due to mode"				
			}
		}

		if ($next -eq "PrepareSourceAndTarget") {
			$Modeobj | Start-EMPrepareGroupObjects 
		}

		if ($next -eq "stop") {
			write-Slog "$samaccountname" "LOG" "Ready"
		}
		
	}	
}

function New-EMTargetGALGroup() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate
	)
	Process {
		try {
			$t = 300
			$path = $Script:ModuleTargetGALSyncOU
			New-ADGroup -SamAccountName $samaccountname -Path $path -Name $samaccountname -groupcategory distribution -groupscope universal -Server $targetpdc -credential $targetcred -ea stop 
			write-Slog "$samaccountname" "OK" "GAL group object created in target domain '$targetdomain'"
			write-Slog "$samaccountname" "LOG" "Waiting for group object to be ready in target domain '$targetdomain'. Waiting up to $t seconds"
			$n = 0
			
			while ($n -lt $t) {
				$eguid = $null; $eguid = $(try{(get-adgroup -server $targetpdc -filter {samaccountname -eq $samaccountname} -properties objectguid -credential $targetcred).objectguid.guid}catch{}) 
				if ($eguid) {
					if ($($eguid | measure).count -gt 1) {write-Slog "$samaccountname" "WARN" "Multiple objects found in target domain '$targetdomain'";throw}		
					if ($(try {invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-group $eguid -domaincontroller $targetpdc"}catch{})) { 
						Start-EMProcessDistributionGroup -SourceDomain $sourcedomain -TargetDomain $targetdomain -Samaccountname $samaccountname -SourceCred $SourceCred -TargetCred $TargetCred  -Mode $Mode -Activity $activity -SourceEndPoint $SourceEndPoint -TargetEndPoint $TargetEndPoint -Separate $Separate
						break
					} else {				
						sleep -s 1; $n++
					}
				} else {
					sleep -s 1; $n++
				}
			}
				
			if ($n -ge $t) {
				throw
			}
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem creating GAL group object in target domain '$targetdomain'"
		}
	}
}

function Start-EMMailEnableTargetGroup() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceRoutingSMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourcePrimarySMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate
	)
	Process {

		#check group type
		if ($target.groupscope -ne "universal") {
			write-Slog "$samaccountname" "AR" "Group is not universal in target domain '$targetdomain'. Converting"
			try {
				$target | set-adgroup -groupscope universal -server $targetpdc -credential $targetcred -ea stop | out-null 
				write-Slog "$samaccountname" "OK" "Converted group scope to universal"		
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem converting group scope to universal"
			}
		}

		$completed = $null
		$secondsmax = $null; $secondsmax = 300
		$secondsinc = $null; $secondsinc = 30
		$start = $null; $start = get-date

		write-Slog "$samaccountname" "LOG" "Waiting for object to be ready in target domain '$targetdomain'. Waiting up to $secondsmax seconds"
		Do {						
			try {
				$eguid = $null; $eguid = $target.objectguid.guid
				$group = $null; $group = invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-group $eguid -domaincontroller $($targetpdc) -ea stop" 
				if ($($group | measure).count -gt 1) {write-Slog "$samaccountname" "WARN" "Multiple objects found in target domain '$targetdomain'. Unable to continue"}
				if ($group.grouptype -match "universal") {
					$completed = $true
				}
			} catch{sleep -s $secondsinc}

			if ((new-timespan -Start $start -End (get-date)).seconds -ge $secondsmax) {
				write-Slog "$samaccountname" "ERR" "Timeout. Unable to continue"
			}

			write-Slog "$samaccountname" "LOG" "Waited $([math]::round((new-timespan -Start $start -End (get-date)).totalseconds)) seconds"				

		} while (!($completed))
	

		#mail enable
		try {
			$eguid = $null; $eguid = $target.objectguid.guid
			if (($eguid | measure).count -eq 1) {
				invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "enable-distributiongroup -identity $eguid -domaincontroller $($targetpdc) -ea stop" | out-null 
			} else {
				throw
			}
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem mail enabling in target domain '$targetdomain'"
		}

		$completed = $null
		$start = $null; $start = get-date

		write-Slog "$samaccountname" "LOG" "Waiting for mail enabled object to be ready in target domain '$targetdomain'. Waiting up to $secondsmax seconds"
		Do {				
			$invresult = $null	
			try {
				$invresult = invoke-emexchangecommand -endpoint $targetendpoint -domaincontroller $targetpdc -credential $targetcred -command "get-distributiongroup -identity $eguid -domaincontroller $($targetpdc) -ea stop" | out-null 
				$completed = $true
			} catch{sleep -s $secondsinc}

			if ($($invresult | measure).count -gt 1) {write-Slog "$samaccountname" "ERR" "Multiple objects found in target domain '$targetdomain'. Unable to continue"}

			if ((new-timespan -Start $start -End (get-date)).seconds -ge $secondsmax) {
				write-Slog "$samaccountname" "ERR" "Timeout mail enabling. Unable to continue"
			}
			write-Slog "$samaccountname" "LOG" "Waited $([math]::round((new-timespan -Start $start -End (get-date)).totalseconds)) seconds"				

		} while (!($completed))

		if ($completed) {
			write-Slog "$samaccountname" "LOG" "mail enabled OK in target domain '$targetdomain'"
			Start-EMProcessDistributionGroup -SourceDomain $sourcedomain -TargetDomain $targetdomain -Samaccountname $samaccountname -SourceCred $SourceCred -TargetCred $TargetCred  -Mode $Mode -Activity $activity -SourceEndPoint $SourceEndPoint -TargetEndPoint $TargetEndPoint -Separate $Separate
		}
	}
}

function Start-EMPrepareGroupObjects() { 
#===============================================================================================================
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SamAccountName,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceDomainSID,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceType,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetType,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetNBDomain,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetDomainSID,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetPDC,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceRoutingSMTP,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Source,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][Microsoft.ActiveDirectory.Management.ADEntity]$Target,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$TargetCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][system.management.automation.pscredential]$SourceCred,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Prepare','LogOnly')][string]$Mode,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$SourceEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][string]$TargetEndPoint,
		[Parameter(mandatory=$true,valuefrompipelinebypropertyname=$true)][ValidateSet('Migrate','GALSync')][string]$Activity,
		[Parameter(mandatory=$false,valuefrompipelinebypropertyname=$true)][boolean]$Separate= $Script:ModuleSeparate
	)
	Process {	

		#calcs
		#calculate target routing SMTP address
		try {
			$targetRoutingSMTP = $null; $targetRoutingSMTP = $("$($target.mailnickname)@mail.on$($targetdomain)").tolower()
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem preparing target routing SMTP address"
		}

		#calculate source routing X500 address
		try {
			$sourceRoutingX500 = $null; $sourceRoutingX500 = $("X500:" + $source.legacyexchangedn)
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem preparing source routing X500 address"
		}

		#calculate target routing X500 address
		try {
			$targetRoutingX500 = $null; $targetRoutingX500 = $("X500:" + $target.legacyexchangedn)
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem preparing target routing X500 address"
		}

		#direction	
		$primaryobj = $source
		$secondaryobj = $target	
		$primarynbdomain = $null; $primarynbdomain = $sourcenbdomain
		$secondarynbdomain = $null; $secondarynbdomain = $targetnbdomain
		$primarydomain = $null; $primarydomain = $sourcedomain
		$secondarydomain = $null; $secondarydomain = $targetdomain
		$primaryendpoint = $null; $primaryendpoint = $sourceendpoint
		$secondaryendpoint = $null; $secondaryendpoint = $targetendpoint
		$primarypdc = $null; $primarypdc = $sourcepdc
		$secondarypdc = $null; $secondarypdc = $targetpdc
		$primarycred = $null; $primarycred = $sourcecred
		$secondarycred = $null; $secondarycred = $targetcred
		$primaryroutingsmtp = $null; $primaryroutingsmtp = $sourceroutingsmtp
		$secondaryroutingsmtp = $null; $secondaryroutingsmtp = $targetroutingsmtp
		$primaryroutingx500 = $null; $primaryroutingx500 = $sourceRoutingX500
		$secondaryroutingx500 = $null; $secondaryroutingx500 = $targetRoutingX500
		$primarytype = $null; $primarytype = $sourcetype
		$secondarytype = $null; $secondarytype = $targettype
		$PrimaryGALSyncOU = $null; $PrimaryGALSyncOU = $Script:ModuleSourceGALSyncOU
		$SecondaryGALSyncOU = $null; $SecondaryGALSyncOU = $Script:ModuleTargetGALSyncOU

		$pupdate = $false
		$supdate = $false

		#displayname
		if ($($primaryobj.displayname) -ne $($secondaryobj.displayname)) {
			write-Slog "$samaccountname" "AR" "Secondary displayname attr update required: $($primaryobj.displayname)"
			$secondaryobj.displayname = $primaryobj.displayname
			$supdate = $true
		}

		#mail
		if ($($primaryobj.mail) -ne $($secondaryobj.mail)) {
			write-Slog "$samaccountname" "AR" "Secondary mail attr update required: $($primaryobj.mail)"
			$secondaryobj.mail = $primaryobj.mail
			$supdate = $true
		}

		#mailnickname
		if ($($primaryobj.mailnickname) -ne $($secondaryobj.mailnickname)) {
			write-Slog "$samaccountname" "AR" "Secondary mailnickname attr update required: $($primaryobj.mailnickname)"
			$secondaryobj.mailnickname = $primaryobj.mailnickname
			$supdate = $true
		}

		#textEncodedORAddress
		if ($($primaryobj.textEncodedORAddress) -ne $($secondaryobj.textEncodedORAddress)) {
			write-Slog "$samaccountname" "AR" "Secondary textEncodedORAddress attr update required"
			$secondaryobj.textEncodedORAddress = $primaryobj.textEncodedORAddress
			$supdate = $true
		}

		#disable sender auth requirement
		if ($($primaryobj.msExchRequireAuthToSendTo) -eq $true) {
			write-Slog "$samaccountname" "AR" "Primary msExchRequireAuthToSendTo attr update required"
			$primaryobj.msExchRequireAuthToSendTo = $false
			$pupdate = $true
		}

		if ($($secondaryobj.msExchRequireAuthToSendTo) -eq $true) {
			write-Slog "$samaccountname" "AR" "Secondary msExchRequireAuthToSendTo attr update required"
			$secondaryobj.msExchRequireAuthToSendTo = $false
			$supdate = $true
		}

		#msExchHideFromAddressLists and msExchSenderHintTranslations
		if ($activity -eq "migrate") {
			if ($($primaryobj.msExchHideFromAddressLists) -ne $($secondaryobj.msExchHideFromAddressLists)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchHideFromAddressLists attr update required"
				$secondaryobj.msExchHideFromAddressLists = $primaryobj.msExchHideFromAddressLists
				$supdate = $true
			}
			if ($($primaryobj.msExchSenderHintTranslations) -ne $($secondaryobj.msExchSenderHintTranslations)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchSenderHintTranslations attr update required"
				$secondaryobj.msExchSenderHintTranslations = $primaryobj.msExchSenderHintTranslations
				$supdate = $true
			}
		}

		if ($activity -eq "galsync") {
			if ($($secondaryobj.msExchHideFromAddressLists) -ne $true) {
				write-Slog "$samaccountname" "AR" "Secondary msExchHideFromAddressLists attr update required"
				$secondaryobj.msExchHideFromAddressLists = $true
				$supdate = $true
			}
			$tip = $null; $tip = "default:<html>`n<body>`nPlease be aware this is a distribution group for external recipients.`n</body>`n</html>`n"
			if (($($secondaryobj.msExchSenderHintTranslations) -ne $tip) -or ($($secondaryobj.msExchSenderHintTranslations) -eq $null)) {
				write-Slog "$samaccountname" "AR" "Secondary msExchSenderHintTranslations attr update required"
				$secondaryobj.msExchSenderHintTranslations = $tip
				$supdate = $true
			}
		}

		#extensionAttribute1
		if ($($primaryobj.extensionAttribute1) -ne $($secondaryobj.extensionAttribute1)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute1 attr update required"
			$secondaryobj.extensionAttribute1 = $primaryobj.extensionAttribute1
			$supdate = $true
		}

		#extensionAttribute2
		if ($($primaryobj.extensionAttribute2) -ne $($secondaryobj.extensionAttribute2)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute2 attr update required"
			$secondaryobj.extensionAttribute2 = $primaryobj.extensionAttribute2
			$supdate = $true
		}

		#extensionAttribute3
		if ($($primaryobj.extensionAttribute3) -ne $($secondaryobj.extensionAttribute3)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute3 attr update required"
			$secondaryobj.extensionAttribute3 = $primaryobj.extensionAttribute3
			$supdate = $true
		}

		#extensionAttribute4
		if ($($primaryobj.extensionAttribute4) -ne $($secondaryobj.extensionAttribute4)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute4 attr update required"
			$secondaryobj.extensionAttribute4 = $primaryobj.extensionAttribute4
			$supdate = $true
		}

		#extensionAttribute5
		if ($($primaryobj.extensionAttribute5) -ne $($secondaryobj.extensionAttribute5)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute5 attr update required"
			$secondaryobj.extensionAttribute5 = $primaryobj.extensionAttribute5
			$supdate = $true
		}

		#extensionAttribute6
		if ($($primaryobj.extensionAttribute6) -ne $($secondaryobj.extensionAttribute6)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute6 attr update required"
			$secondaryobj.extensionAttribute6 = $primaryobj.extensionAttribute6
			$supdate = $true
		}

		#extensionAttribute7
		if ($($primaryobj.extensionAttribute7) -ne $($secondaryobj.extensionAttribute7)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute7 attr update required"
			$secondaryobj.extensionAttribute7 = $primaryobj.extensionAttribute7
			$supdate = $true
		}

		#extensionAttribute8
		if ($($primaryobj.extensionAttribute8) -ne $($secondaryobj.extensionAttribute8)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute8 attr update required"
			$secondaryobj.extensionAttribute8 = $primaryobj.extensionAttribute8
			$supdate = $true
		}

		#extensionAttribute9
		if ($($primaryobj.extensionAttribute9) -ne $($secondaryobj.extensionAttribute9)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute9 attr update required"
			$secondaryobj.extensionAttribute9 = $primaryobj.extensionAttribute9
			$supdate = $true
		}

		#extensionAttribute10
		if ($($primaryobj.extensionAttribute10) -ne $($secondaryobj.extensionAttribute10)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute10 attr update required"
			$secondaryobj.extensionAttribute10 = $primaryobj.extensionAttribute10
			$supdate = $true
		}

		#extensionAttribute11
		if ($($primaryobj.extensionAttribute11) -ne $($secondaryobj.extensionAttribute11)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute11 attr update required"
			$secondaryobj.extensionAttribute11 = $primaryobj.extensionAttribute11
			$supdate = $true
		}

		#extensionAttribute12
		if ($($primaryobj.extensionAttribute12) -ne $($secondaryobj.extensionAttribute12)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute12 attr update required"
			$secondaryobj.extensionAttribute12 = $primaryobj.extensionAttribute12
			$supdate = $true
		}

		#extensionAttribute13
		if ($($primaryobj.extensionAttribute13) -ne $($secondaryobj.extensionAttribute13)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute13 attr update required"
			$secondaryobj.extensionAttribute13 = $primaryobj.extensionAttribute13
			$supdate = $true
		}

		#extensionAttribute14
		if ($($primaryobj.extensionAttribute14) -ne $($secondaryobj.extensionAttribute14)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute14 attr update required"
			$secondaryobj.extensionAttribute14 = $primaryobj.extensionAttribute14
			$supdate = $true
		}

		#extensionAttribute15
		if ($($primaryobj.extensionAttribute15) -ne $($secondaryobj.extensionAttribute15)) {
			write-Slog "$samaccountname" "AR" "extensionAttribute15 attr update required"
			$secondaryobj.extensionAttribute15 = $primaryobj.extensionAttribute15
			$supdate = $true
		}

		#authOrig (users allowed to send to distribution group)	
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute authOrig -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.authOrig -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc 
		if (($(try{compare-object $($secondaryobj.authOrig) $($sdns)}catch{})) -or ($($secondaryobj.authOrig) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary authOrig attr update required"
				$secondaryobj.authOrig = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary $Attribute attr"
			}
		}	

		#unauthOrig (users not allowed to send to the distribution group)
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute unauthOrig -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.unauthOrig -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
		if (($(try{compare-object $($secondaryobj.unauthOrig) $($sdns)}catch{})) -or ($($secondaryobj.unauthOrig) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary unauthOrig attr update required"
				$secondaryobj.unauthOrig = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary $Attribute attr"
			}
		}

		#dLMemSubmitPerms (groups allowed to send to distribution group)
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute dLMemSubmitPerms -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.dLMemSubmitPerms -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc 
		if (($(try{compare-object $($secondaryobj.dLMemSubmitPerms) $($sdns)}catch{})) -or ($($secondaryobj.dLMemSubmitPerms) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary dLMemSubmitPerms attr update required"
				$secondaryobj.dLMemSubmitPerms = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary $Attribute attr"
			}
		}	

		#dLMemRejectPerms (groups not allowed to send to distribution group)
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute dLMemRejectPerms -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.dLMemRejectPerms -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
		if (($(try{compare-object $($secondaryobj.dLMemRejectPerms) $($sdns)}catch{})) -or ($($secondaryobj.dLMemRejectPerms) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary dLMemRejectPerms attr update required"
				$secondaryobj.dLMemRejectPerms = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary $Attribute attr"
			}
		}	

		#managedby and msExchCoManagedByLink
		$primaryallmanagers = @()
		$primaryobj.managedby | % {$primaryallmanagers += $_}
		$primaryobj.msExchCoManagedByLink | % {$primaryallmanagers += $_}
		$primaryallmanagers = $primaryallmanagers | sort | get-unique

		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute 'managedBy msExchCoManagedByLink'-PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryallmanagers -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc

		try {
			if (($sdns | measure).count -eq 0) {
				if ($($secondaryobj.managedBy) -ne $null) {
					write-Slog "$samaccountname" "AR" "Secondary managedBy attr update required"
					$secondaryobj.managedBy = $null
					$supdate = $true
				}
				if ($($secondaryobj.msExchCoManagedByLink) -ne $null) {
					write-Slog "$samaccountname" "AR" "Secondary msExchCoManagedByLink attr update required"
					$secondaryobj.msExchCoManagedByLink = $null
					$supdate = $true
				}	
			}

			if (($sdns | measure).count -eq 1) {
				if ($($secondaryobj.managedBy) -ne $sdns) {
					write-Slog "$samaccountname" "AR" "Secondary managedBy attr update required"
					$secondaryobj.managedBy = $sdns
					$supdate = $true
				}
				if ($($secondaryobj.msExchCoManagedByLink) -ne $null) {
					write-Slog "$samaccountname" "AR" "Secondary msExchCoManagedByLink attr update required"
					$secondaryobj.msExchCoManagedByLink = $null
					$supdate = $true
				}	
			}

			if (($sdns | measure).count -gt 1) {
				if ($($secondaryobj.managedBy) -ne $sdns[0]) {
					write-Slog "$samaccountname" "AR" "Secondary managedBy attr update required"
					$secondaryobj.managedBy = $sdns[0]
					$supdate = $true
				}
				$sdns = $sdns | ? {$_ -ne $sdns[0]} | % {$_.tostring()}
				if (($(try{compare-object $($secondaryobj.msExchCoManagedByLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchCoManagedByLink) -xor $($sdns))) {		
					write-Slog "$samaccountname" "AR" "Secondary msExchCoManagedByLink attr update required"
					$secondaryobj.msExchCoManagedByLink = $sdns
					$supdate = $true			
				}					
			}
		} catch {
			write-Slog "$samaccountname" "ERR" "Problem preparing secondary managedBy or msExchCoManagedByLink attr"
		}		

		#msExchGroupJoinRestriction
		if ($($primaryobj.msExchGroupJoinRestriction) -ne $($secondaryobj.msExchGroupJoinRestriction)) {
			write-Slog "$samaccountname" "AR" "Secondary msExchGroupJoinRestriction attr update required"
			$secondaryobj.msExchGroupJoinRestriction = $primaryobj.msExchGroupJoinRestriction
			$supdate = $true
		}

		#msExchGroupDepartRestriction
		if ($($primaryobj.msExchGroupDepartRestriction) -ne $($secondaryobj.msExchGroupDepartRestriction)) {
			write-Slog "$samaccountname" "AR" "Secondary msExchGroupDepartRestriction attr update required"
			$secondaryobj.msExchGroupDepartRestriction = $primaryobj.msExchGroupDepartRestriction
			$supdate = $true
		}

		#msExchEnableModeration
		if ($($primaryobj.msExchEnableModeration) -ne $($secondaryobj.msExchEnableModeration)) {
			write-Slog "$samaccountname" "AR" "Secondary msExchEnableModeration attr update required"
			$secondaryobj.msExchEnableModeration = $primaryobj.msExchEnableModeration
			$supdate = $true
		}

		#msExchModerationFlags
		if ($($primaryobj.msExchModerationFlags) -ne $($secondaryobj.msExchModerationFlags)) {
			write-Slog "$samaccountname" "AR" "Secondary msExchModerationFlags attr update required"
			$secondaryobj.msExchModerationFlags = $primaryobj.msExchModerationFlags
			$supdate = $true
		}	

		#msExchModeratedByLink
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute msExchModeratedByLink -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.msExchModeratedByLink -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
		if (($(try{compare-object $($secondaryobj.msExchModeratedByLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchModeratedByLink) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary msExchModeratedByLink attr update required"
				$secondaryobj.msExchModeratedByLink = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary msExchModeratedByLink attr"
			}
		}

		#msExchBypassModerationLink	
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute msExchBypassModerationLink -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.msExchBypassModerationLink -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
		if (($(try{compare-object $($secondaryobj.msExchBypassModerationLink) $($sdns)}catch{})) -or ($($secondaryobj.msExchBypassModerationLink) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary msExchBypassModerationLink attr update required"
				$secondaryobj.msExchBypassModerationLink = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary msExchBypassModerationLink attr"
			}
		}	

		#publicdelegates
		$sdns = $null; $sdns = @(); $sdns = Get-EMSecondaryDistinguishedNames -Attribute publicdelegates -PrimaryCred $PrimaryCred -PrimaryPDC $primarypdc -PrimaryDNs $primaryobj.publicdelegates -SecondaryCred $secondarycred -SecondaryPDC $secondarypdc
		if (($(try{compare-object $($secondaryobj.publicdelegates) $($sdns)}catch{})) -or ($($secondaryobj.publicdelegates) -xor $($sdns))) {
			try {				
				write-Slog "$samaccountname" "AR" "Secondary publicdelegates attr update required"
				$secondaryobj.publicdelegates = $sdns
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary publicdelegates attr"
			}
		}		

		#proxyaddresses
		$pproxsticky = $null; $pproxsticky = $primaryobj.proxyaddresses -notmatch "^smtp:|^x500:"
		$sproxsticky = $null; $sproxsticky = $secondaryobj.proxyaddresses -notmatch "^smtp:|^x500"
		$pprox = $primaryobj.proxyaddresses -match "^smtp:|^x500"
		$sprox = $pprox

		#primary
		#smtp
		if ($pprox -notcontains $("smtp:" + $primaryRoutingSMTP)) {
			$pprox += $("smtp:" + $primaryRoutingSMTP)
		}

		#nonsmtp
		$pproxsticky | % {$pprox += $_}
		if ($pprox -notcontains $secondaryRoutingX500) {
			$pprox += $secondaryRoutingX500
		}

		#remove unwanted
		$pprox = $pprox -notmatch "mail\.on$($secondarydomain)$"
		$pprox = $pprox -notmatch [regex]::escape($primaryRoutingX500)

		#formatting
		$pproxarray = $null; $pproxarray = @(); $pprox | % {$pproxarray += ($_.tostring())}	

		if ($(try{compare-object $($primaryobj.proxyaddresses) $($pproxarray)}catch{}) -or ($($primaryobj.proxyaddresses) -xor $($pproxarray))) {
			try {
				write-Slog "$samaccountname" "AR" "Primary proxyaddresses attr update required"
				$primaryobj.proxyaddresses = $pproxarray
				$pupdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing primary proxyaddresses attr"
			}
		}

		#secondary
		#smtp
		if ($sprox -notcontains $("smtp:" + $secondaryRoutingSMTP)) {
			$sprox += $("smtp:" + $secondaryRoutingSMTP)
		}

		#nonsmtp
		$sproxsticky | % {$sprox += $_}
		if ($sprox -notcontains $primaryRoutingX500) {
			$sprox += $primaryRoutingX500
		}

		#remove unwanted
		$sprox = $sprox -notmatch "mail\.on$($primarydomain)$"
		$sprox = $sprox -notmatch [regex]::escape($secondaryRoutingX500)

		#formatting
		$sproxarray = $null; $sproxarray = @(); $sprox | % {$sproxarray += ($_.tostring())}

		if ($(try{compare-object $($secondaryobj.proxyaddresses) $($sproxarray)}catch{}) -or ($($secondaryobj.proxyaddresses) -xor $($sproxarray))) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary proxyaddresses attr update required"
				$secondaryobj.proxyaddresses = $sproxarray
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary proxyaddresses attr"
			}
		}

		#groupscope
		if ($($secondaryobj.groupscope) -ne "universal") {			
			try {
				write-Slog "$samaccountname" "AR" "Secondary groupscope attr update required"
				$secondaryobj.groupscope = "Universal"
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary group scope to universal"
			}
		}

		#groupcategory
		if ($($primaryobj.groupcategory) -ne $secondaryobj.groupcategory) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary groupcategory attr update required"
				$secondaryobj.groupcategory = $primaryobj.groupcategory
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting group category"
			}
		}

		#types
		if ($($primaryobj.msexchrecipienttypedetails) -ne $($secondaryobj.msexchrecipienttypedetails)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary msExchRecipientTypeDetails attr update required"
				$secondaryobj.msexchrecipienttypedetails = $primaryobj.msexchrecipienttypedetails
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchRecipientTypeDetails attr"
			}
		}

		if ($($primaryobj.msexchrecipientdisplaytype) -ne $($secondaryobj.msexchrecipientdisplaytype)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary msExchRecipientDisplayType attr update required"
				$secondaryobj.msexchrecipientdisplaytype = $primaryobj.msexchrecipientdisplaytype
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchRecipientDisplayType attr"
			}
		}

		if ($($primaryobj.msExchRemoteRecipientType) -ne $($secondaryobj.msExchRemoteRecipientType)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary msExchRemoteRecipientType attr update required"
				$secondaryobj.msExchRemoteRecipientType = $primaryobj.msExchRemoteRecipientType
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchRemoteRecipientType attr"
			}
		}

		#maximum size restrictions
		if ($($primaryobj.delivContLength) -ne $($secondaryobj.delivContLength)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary delivContLength attr update required"
				$secondaryobj.delivContLength = $primaryobj.delivContLength
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary delivContLength attr"
			}
		}

		#membership approval
		if ($($primaryobj.msExchGroupJoinRestriction) -ne $($secondaryobj.msExchGroupJoinRestriction)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary msExchGroupJoinRestriction attr update required"
				$secondaryobj.msExchGroupJoinRestriction = $primaryobj.msExchGroupJoinRestriction
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchGroupJoinRestriction attr"
			}
		}

		if ($($primaryobj.msExchGroupDepartRestriction) -ne $($secondaryobj.msExchGroupDepartRestriction)) {
			try {
				write-Slog "$samaccountname" "AR" "Secondary msExchGroupDepartRestriction attr update required"
				$secondaryobj.msExchGroupDepartRestriction = $primaryobj.msExchGroupDepartRestriction
				$supdate = $true
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem setting secondary msExchGroupDepartRestriction attr"
			}
		}	

		#msExchPoliciesExcluded msExchPoliciesIncluded
		if ($mode -eq "prepare") {
			if ($primaryobj.msExchPoliciesExcluded -notcontains '{26491cfc-9e50-4857-861b-0cb8df22b5d7}') {
				write-Slog "$samaccountname" "AR" "Primary msExchPoliciesExcluded attr update required"
				$primaryobj.msExchPoliciesExcluded = '{26491cfc-9e50-4857-861b-0cb8df22b5d7}'
				$pupdate = $true
			}
			if ($primaryobj.msExchPoliciesIncluded -ne $null) {
				write-Slog "$samaccountname" "AR" "Primary msExchPoliciesIncluded attr update required"
				$primaryobj.msExchPoliciesIncluded = $null
				$pupdate = $true
			}
			if ($secondaryobj.msExchPoliciesExcluded -notcontains '{26491cfc-9e50-4857-861b-0cb8df22b5d7}') {
				write-Slog "$samaccountname" "AR" "Secondary msExchPoliciesExcluded attr update required"
				$secondaryobj.msExchPoliciesExcluded = '{26491cfc-9e50-4857-861b-0cb8df22b5d7}'
				$supdate = $true
			}
			if ($secondaryobj.msExchPoliciesIncluded -ne $null) {
				write-Slog "$samaccountname" "AR" "Secondary msExchPoliciesIncluded attr update required"
				$secondaryobj.msExchPoliciesIncluded = $null
				$supdate = $true
			}
		}
		
		#commit changes
		if ($Mode -eq "Prepare") {
			try {
				if ($pupdate -eq $true) {
					set-adgroup -instance $primaryobj -server $primarypdc -Credential $primaryCred -ea stop
					write-Slog "$samaccountname" "OK" "Primary group prepared in domain '$primarydomain'"
				}
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing primary group in domain '$primarydomain'"
			}
		
			try {
				if ($supdate -eq $true) {
					set-adgroup -instance $secondaryobj -server $secondarypdc -Credential $secondaryCred -ea stop
					write-Slog "$samaccountname" "OK" "Secondary group prepared in domain '$secondarydomain'"
				}	
			} catch {
				write-Slog "$samaccountname" "ERR" "Problem preparing secondary group in domain '$secondarydomain'"
			}
		}

		<#
		#membership on GALSync
		if ($Activity -eq "GALSync") {
			if ($secondaryobj.member) {
				try {
					write-Slog "$samaccountname" "AR" "Secondary member attr update required"
					Get-ADGroupMember -identity $($Secondaryobj.objectguid.guid) -Server $($secondarypdc) -Credential $($secondarycred) | % {Remove-ADGroupMember -identity $($Secondaryobj.objectguid.guid) -Members $_ -Server $($secondarypdc) -Credential $($secondarycred) -confirm:$false}
					write-Slog "$samaccountname" "OK" "Secondary member attr updated"
				} catch{
					write-Slog "$samaccountname" "ERR" "Problem updating secondary member attr. Unable to continue"
				}
			}
		}
		#>

		#OU on GALSync
		if ($activity -eq "GalSync"){
			if ($Secondaryobj.distinguishedname -notmatch $SecondaryGALSyncOU ) {
				write-Slog "$samaccountname" "AR" "Moving secondary to GALSync OU '$SecondaryGALSyncOU'"
				try {
					Move-ADObject -Identity $($Secondaryobj.objectguid.guid) -TargetPath $SecondaryGALSyncOU -Server $secondarypdc -Credential $secondarycred -ea Stop
					write-Slog "$samaccountname" "LOG" "Moved secondary to GALSync OU '$SecondaryGALSyncOU'"
				} catch {
					write-Slog "$samaccountname" "ERR" "Problem moving secondary to GALSync OU '$SecondaryGALSyncOU'"
				}
			}
		}

		#send-as permissions
		if ($activity -eq "migrate"){
				write-Slog "$samaccountname" "LOG" "Checking send-as permissions on primary"
				try {
					$primaryperms = $null; $primaryperms =  invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
				} catch {
					write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on primary"
				}
				write-Slog "$samaccountname" "LOG" "Checking send-as permissions on secondary"
				try {
					$secondaryperms = $null; $secondaryperms =  invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command "get-adpermission -identity $($secondaryobj.objectguid.guid) -domaincontroller $($secondarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
				} catch {
					write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on secondary"
				}

				#formatting
				$primaryusers = $null; $primaryusers = @()
				$primaryperms | % {$primaryusers += $_.user.tostring()}

				$secondaryusers = $null; $secondaryusers = @()
				$secondaryperms | % {$secondaryusers += $_.user.tostring()}
				
				#hydrate
				$sendasperms = $null; $sendasperms = @()
				foreach ($user in $primaryusers) {
					if ($user -match  "^($primarynbdomain)\\|^($secondarynbdomain)\\") {
						$sam = $null; $sam = $user -replace ($primarynbdomain + "\\"),""
						$sam = $sam -replace ($secondarynbdomain + "\\"),""
						$sendasperms += $("$primarynbdomain\$sam")
						$sendasperms += $("$secondarynbdomain\$sam")
					}
				}
				$sendasperms = $sendasperms | sort | Get-Unique

				#additions
				foreach ($perm in $sendasperms){
					if ($primaryusers -notcontains $perm) {
						write-Slog "$samaccountname" "AR" "'$($perm)' send-as missing on primary"
						try {
							invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "add-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $("$perm") -accessrights extendedright -extendedrights send-as -WarningAction 0"  | out-null
							write-Slog "$samaccountname" "OK" "'$($perm)' send-as added to primary"
						} catch {
							write-Slog "$samaccountname" "WARN" "'$($perm)' issue adding send-as permission to primary and will be excluded"
						}
					}
					if ($secondaryusers -notcontains $perm) {
						write-Slog "$samaccountname" "AR" "'$($perm)' send-as missing on secondary"
						try {
							invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command "add-adpermission -identity $($secondaryobj.objectguid.guid) -domaincontroller $($secondarypdc) -user $("$perm") -accessrights extendedright -extendedrights send-as -WarningAction 0" | out-null
							write-Slog "$samaccountname" "OK" "'$($perm)' send-as added to secondary"
						} catch {
							write-Slog "$samaccountname" "WARN" "'$($perm)' issue adding send-as permission to secondary and will be excluded"
						}
					}
				}
		}

		#send-as permissions on galsync
		if ($activity -eq "galsync") {
			write-Slog "$samaccountname" "LOG" "Checking send-as permissions on primary"
			try {
				$primaryperms = $null; $primaryperms =  invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command "get-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on primary"
			}
			write-Slog "$samaccountname" "LOG" "Checking send-as permissions on secondary"
			try {
				$secondaryperms = $null; $secondaryperms =  invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command "get-adpermission -identity $($secondaryobj.objectguid.guid) -domaincontroller $($secondarypdc) -ea stop"  | ? {$_.isinherited -eq $false -and $_.user -ne 'NT AUTHORITY\SELF' -and $_.extendedrights -match "send-as" -and $_.deny -eq $false} 
			} catch {
				write-Slog "$samaccountname" "ERR" "Issue checking send-as permissions on secondary"
			}

			#formatting
			$primaryusers = $null; $primaryusers = @()
			$primaryperms | % {$primaryusers += $_.user.tostring()}
			$primaryusers = $primaryusers | sort | get-unique

			$secondaryusers = $null; $secondaryusers = @()
			$secondaryperms | % {$secondaryusers += $_.user.tostring()}
			$secondaryusers = $secondaryusers | sort | get-unique

			#remove opposite permissions
			foreach($perm in $primaryusers) {
				if ($perm -match "^$($secondarynbdomain)\\") {
					write-Slog "$samaccountname" "AR" "'$($perm)' send-as removing from primary"
					try {
						invoke-emexchangecommand -endpoint $primaryendpoint -domaincontroller $primarypdc -credential $primarycred -command $("remove-adpermission -identity $($primaryobj.objectguid.guid) -domaincontroller $($primarypdc) -user $($perm) -accessrights extendedright -extendedrights send-as" + ' -confirm:$false') | out-null 
						write-Slog "$samaccountname" "OK" "'$($perm)' send-as removed from primary"
					} catch {
						write-Slog "$samaccountname" "WARN" "'$($perm)' issue removing send-as permission from primary and will be excluded"
					}
				}
			}

			foreach($perm in $secondaryusers) {
				if ($perm -match "^$($primarynbdomain)\\") {
					write-Slog "$samaccountname" "AR" "'$($perm)' send-as removing from secondary"
					try {
						invoke-emexchangecommand -endpoint $secondaryendpoint -domaincontroller $secondarypdc -credential $secondarycred -command $("remove-adpermission -identity $($secondaryobj.objectguid.guid) -domaincontroller $($secondarypdc) -user $($perm) -accessrights extendedright -extendedrights send-as" + ' -confirm:$false') | out-null 
						write-Slog "$samaccountname" "OK" "'$($perm)' send-as removed from secondary"
					} catch {
						write-Slog "$samaccountname" "WARN" "'$($perm)' issue removing send-as permission from secondary and will be excluded"
					}
				}
			}
		}

		write-Slog "$samaccountname" "LOG" "Ready"
	}
}