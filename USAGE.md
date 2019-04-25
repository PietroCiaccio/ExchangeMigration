## Usage

If you explore the cmdlets available with the EM Powershell Module you will see there are many but as a user you should only be executing a few. These are as follows -

**Setting Up**

- Write-EMConfiguration
- Read-EMConfiguration
- Get-EMConfiguration
- Test-EMConfiguration

**Processing Individual Objects**

- Start-EMProcessMailbox
- Start-EMProcessDistributionGroup

**Processing Batches**

- Start-EMProcessMailboxBatch
- Start-EMProcessDistributionGroupBatch

**Logs Management**

- Get-EMLogs
- Clear-EMLogs
- Start-EMLogsArchive

### Importing the Module

Run the following -

 - import-module .\ExchangeMigration.psm1

On the first run you will be presented with the following -

*EM (ExchangeMigration) Powershell Module
*https://github.com/PietroCiaccio/ExchangeMigration
*25/04/2019 16:45:40

*Configuration not detected. You can create a configuration file using 'Write-EMConfiguration' [WARN]

### Write-EMConfiguration

Write-EMConfiguration [-SourceDomain] <string> [-SourceEndPoint] <string> [-SourceGALSyncOU] <string> [-TargetDomain] <string> [-TargetEndPoint] <string> [-TargetGALSyncOU] <string> [[-LogPath] <string>]
