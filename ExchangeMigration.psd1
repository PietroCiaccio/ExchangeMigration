@{
RootModule = 'ExchangeMigration.psm1'
Description ='The EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross-forest migration.'
ModuleVersion = '0.3.1'
Author = 'Pietro Ciaccio'
FunctionsToExport = @( 
'Clear-EMLogs'
'Get-EMConfiguration'
'Get-EMLogs'
'Start-EMCleanActiveDirectoryObject'
'Start-EMLogsArchive'
'Start-EMProcessDistributionGroup'
'Start-EMProcessDistributionGroupBatch'
'Start-EMProcessMailbox'
'Start-EMProcessMailboxBatch'
'Test-EMConfiguration'
'Write-EMConfiguration'
)
GUID = '9b1866e2-3a1a-448c-8e1c-de696ae0d7bb'
PowerShellVersion = '5.1'
PrivateData = @{
	PSData = @{
        		ProjectUri = 'https://GitHub.com/PietroCiaccio/ExchangeMigration'
		Tags = @('Exchange','Migration','ExchangeMigration','PSEdition_Desktop','Windows','Powershell')
		ReleaseNotes = @'
GitHub is used for development and documentation. Please refer to the GitHub project URI for guidance.
https://GitHub.com/PietroCiaccio/ExchangeMigration

Please use the latest version available on PowerShell Gallery.

## 0.3.1

* Alpha.
* Small changes to console logging.
* GALSync for distribution groups are now less restrictive.

## 0.3.0

* Alpha.
* Added feature to clean Active Directory object Exchange attributes.
* Added help data to cmdlets.

## 0.2

* Alpha.
* Initial release from GitHub.

'@

	}

}

}

