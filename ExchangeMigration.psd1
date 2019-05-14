@{
RootModule = 'ExchangeMigration.psm1'
Description ='The EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross-forest migration.'
ModuleVersion = '0.5.0'
Author = 'Pietro Ciaccio'
FunctionsToExport = @( 
'Clear-EMData'
'Get-EMConfiguration'
'Read-EMLogs'
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
EM was written to support a Microsoft Exchange Server 2010 to Microsoft Exchange Server 2016 cross-forest migration. Other scenarios may be supported, however at this stage untested.

GitHub is used for development, documentation, and reporting issues. Please refer to the GitHub project URI for guidance.
https://GitHub.com/PietroCiaccio/ExchangeMigration

Please use the latest version available on PowerShell Gallery.

## 0.5.0

* Alpha
* Improved configuration management.

## 0.4.1

* Alpha
* Small changes to psd1.

## 0.4.0

* Alpha.
* GALSync now less restrictive for mailboxes and distribution groups.
* Bug fix with calculating targetaddress attribute on mailbox separation.
* Improvements to room and equipment mailbox migrations.
* Added post mailbox migration settings feature. Supports settings not stored in AD and are not migrated by the new-moverequest cmdlet. 
* Added single item recovery settings migration process.
* Changes to logging.

## 0.3.1

* Alpha.
* Bug fix.

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

