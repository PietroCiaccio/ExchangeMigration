@{
RootModule = 'ExchangeMigration.psm1'
Description ='The EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross-forest migration.'
ModuleVersion = '0.7.2'
Author = 'Pietro Ciaccio | LinkedIn: https://www.linkedin.com/in/pietrociaccio | Twitter: @PietroCiac'
FunctionsToExport = @( 
'Clear-EMData'
'Get-EMConfiguration'
'Read-EMLogs'
'Start-EMCleanActiveDirectoryObject'
'Start-EMLogsArchive'
'Start-EMProcessContact'
'Start-EMProcessContactBatch'
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

##0.7.2-alpha

* Bug fixes.
* Added support for Quest Migration Manager's use of extensionattribute14 and 15.

##0.7.1-alpha

* Optimization changes.

##0.7.0-alpha

* Added contacts migration support.
* Small changes to support alias/mailnickname lookups.

## 0.6.2-alpha

* Small changes to psd1.

## 0.6.1-alpha

* Small correction in console logging.

## 0.6.0-alpha

* Logging improvements.

## 0.5.2-alpha

* Small bug fix with console logging.

## 0.5.1-alpha

* Bug fix with move request and large items.
* Increased move request bad item limit.

## 0.5.0-alpha

* Improved configuration management.

## 0.4.1-alpha

* Small changes to psd1.

## 0.4.0-alpha

* GALSync now less restrictive for mailboxes and distribution groups.
* Bug fix with calculating targetaddress attribute on mailbox separation.
* Improvements to room and equipment mailbox migrations.
* Added post mailbox migration settings feature. Supports settings not stored in AD and are not migrated by the new-moverequest cmdlet. 
* Added single item recovery settings migration process.
* Changes to logging.

## 0.3.1-alpha

* Bug fix.

## 0.3.0-alpha

* Added feature to clean Active Directory object Exchange attributes.
* Added help data to cmdlets.

## 0.2-alpha

* Initial release from GitHub.

'@

	}

}

}

