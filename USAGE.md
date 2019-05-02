*To be completed.*

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

## Importing the Module and Setup

Run the following -

 - import-module .\ExchangeMigration.psm1

On the first run you will be presented with the following -

> EM (ExchangeMigration) Powershell Module  
> https://github.com/PietroCiaccio/ExchangeMigration  
> 25/04/2019 16:49:33  
>  
> Configuration not detected. Calling 'Write-EMConfiguration' [WARN]  
>  
> cmdlet Write-EMConfiguration at command pipeline position 1  
> Supply values for the following parameters:  
> SourceDomain:  

At this stage the configuration file (ExchangeMigration.config) has never been created. The configuration file stores the following securely -

- SourceUsername
- SourcePassword
- SourceDomain
- SourceEndPoint: This is the Exchange server you wish to use for actions in the source Exchange Organization.
- TargetUsername
- TargetPassword
- TargetDomain
- TargetEndPoint: This is the Exchange server you wish to use for actions in the target Exchange Organization.
- LogPath: Defaults to C:\Temp\EM if not set
- SourceGALSyncOU: This is the DN of the OU where GALSync objects are created in the source domain.
- TargetGALSyncOU: This is the DN of the OU where GALSync objects are created in the target domain.

It is required to create a configuration file so you have a baseline for your tasks.

After you have created the configuration file you will see the following when importing the EM powershell module.

> EM (ExchangeMigration) Powershell Module  
> https://github.com/PietroCiaccio/ExchangeMigration  
> 25/04/2019 17:22:19  
>   
> Configuration detected. [OK]  
> Configuration successfully enabled. [OK]  
>  
> Use 'Read-EMConfiguration' to review.  
> To create a new configuration use the 'Write-EMConfiguration' cmdlet.  
> To test configuration data settings use 'Test-EMConfiguraion'  

### Write-EMConfiguration

This cmdlet is used to create the configuration file. This will overwrite any configuration file that exists.

Write-EMConfiguration [-SourceDomain] <string> [-SourceEndPoint] <string> [-SourceGALSyncOU] <string> [-TargetDomain] <string> [-TargetEndPoint] <string> [-TargetGALSyncOU] <string> [[-LogPath] <string>]
 
### Read-EMConfiguration

This cmdlet is used to read the configuration file.

### Get-EMConfiguration

This cmdlet is used to display the configuration that has been loaded for the module to use. This is slightly different to Read-EMConfiguration.

### Test-EMConfiguration

This cmdlet will test your configuration. An example result is below.

> Source credential 'domainA\userA' [OK]  
> Source domain 'domainA.net' [OK]  
> Source end point 'endpoint.domainA.net' [OK]  
> Source GAL OU 'OU=GAL,DC=DOMAINA,DC=NET' [OK]  
> Target credential 'domainB\userB' [OK]  
> Target domain 'domainB.net' [OK]  
> Target end point 'endpoint.domainB.net' [OK]  
> Target GAL OU 'OU=GAL,DC=DOMAINB,DC=NET' [OK]  

## Migrating a Mailbox

To migrate a single mailbox you would use the following cmdlet -

### Start-EMProcessMailbox

Start-EMProcessMailbox [-Samaccountname] <string> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}] [[-MoveMailbox] {Yes | No | Suspend}] [[-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Link] <bool>] [[-Separate] <bool>] [[-Wait] <bool>]  [<CommonParameters>]
 
 At a minimum you must specify the *samaccountname* of the source object to be migrated







