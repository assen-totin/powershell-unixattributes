#Requires -Modules ActiveDirectory

Import-Module ActiveDirectory

function Add-UnixAttributes {
	param (
		[Parameter(Mandatory=$true)][string]$sAMAccountName,
		[Parameter(Mandatory=$false)][string]$NISDomain,
		[Parameter(Mandatory=$false)][string]$GIDNumber,
		[Parameter(Mandatory=$false)][string]$LoginShell,
		[Parameter(Mandatory=$false)][string]$UnixHomeDirectory
	)

	# Check our permissions - we need Admin
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	if (! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Write-Host "ERROR: I need Administrator privilege to run. Run your PowerShell as Administrator."
		Exit 1
	}

	# Fallback for NISDomain
	if (! $NISDomain) {
		$NISDomain = "int"
	}

	# Fallback for primary group
	if (! $GIDNumber) {
		$GIDNumber = "10000"
	}

	# Fallback for shell
	if (! $LoginShell) {
		$LoginShell = "/bin/bash"
	}

	# Fallback for home
	if (! $UnixHomeDirectory) {
		$UnixHomeDirectory = "/home/$sAMAccountName"
	}

	# Get user properties
	try {
		$AccountUIDNumber = (Get-ADUser -Identity $sAMAccountName -Properties uidNumber).uidNumber
	}
	catch {
		Write-Host "ERROR: Unable to find user $sAMAccountName"
		Exit 1
	}

	# Check if we already have a UID
	if ($AccountUIDNumber ) {
		Write-Host "ERROR: User $sAMAccountName already has UID $AccountUIDNumber"
		Exit 1
	}

	# Figure out all UIDs that were already assigned
	$AllUsersProperties = Get-ADUser -Filter 'uidNumber -like "*"' -Properties uidNumber
	$MaxUIDNumber = 0
	Foreach ($UserUIDNumber in $AllUsersProperties.uidNumber) {
		if ($MaxUIDNumber -lt $UserUIDNumber) {
			$MaxUIDNumber = $UserUIDNumber
		}
	}

	# Choose new UID as max UID plus 1
	$UIDNumber = $MaxUIDNumber + 1

	# Update the user wuth Unix attributes
	try {
		Set-ADUser -Identity $sAMAccountName -Add @{msSFU30Name="$sAMAccountName"; uid="$sAMAccountName"; msSFU30NisDomain="$NISDomain"; uidNumber="$UIDNumber"; gidNumber="$GIDNumber"; loginShell="$LoginShell"; UnixHomeDirectory="$UnixHomeDirectory" } 
	}
	catch {
		Write-Host "ERROR: Unable to set attributes to user $sAMAccountName"
		Exit 1
	}

	Write-Host "User with sAMAccountName $sAMAccountName updated (UID set to $UIDNumber)"
}

Export-ModuleMember -Function Add-UnixAttributes

