*To be completed.*

## Usage

If you explore the cmdlets available with the EM Powershell Module you will see there are many but as a user you should only be executing a few. These are as follows -

**Setting Up**

- Write-EMConfiguration
- Read-EMConfiguration
- Get-EMConfiguration
- Test-EMConfiguration

**Logs Management**

- Get-EMLogs
- Clear-EMLogs
- Start-EMLogsArchive

**Processing Individual Objects**

- Start-EMProcessMailbox
- Start-EMProcessDistributionGroup

**Processing Batches**

- Start-EMProcessMailboxBatch
- Start-EMProcessDistributionGroupBatch

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


**Write-EMConfiguration** [-SourceDomain] <string> [-SourceEndPoint] <string> [-SourceGALSyncOU] <string> [-TargetDomain] <string> [-TargetEndPoint] <string> [-TargetGALSyncOU] <string> [[-LogPath] <string>]
 
This cmdlet is used to create the configuration file. This will overwrite any configuration file that exists.


**Read-EMConfiguration**

This cmdlet is used to read the configuration file.


**Get-EMConfiguration**

This cmdlet is used to display the configuration that has been loaded for the module to use. This is slightly different to Read-EMConfiguration.


**Test-EMConfiguration**

This cmdlet will test your configuration. An example result is below.

> Source credential 'domainA\userA' [OK]  
> Source domain 'domainA.net' [OK]  
> Source end point 'endpoint.domainA.net' [OK]  
> Source GAL OU 'OU=GAL,DC=DOMAINA,DC=NET' [OK]  
> Target credential 'domainB\userB' [OK]  
> Target domain 'domainB.net' [OK]  
> Target end point 'endpoint.domainB.net' [OK]  
> Target GAL OU 'OU=GAL,DC=DOMAINB,DC=NET' [OK]  

### Module Defaults

The module uses the following defaults unless overwritten by Write-EMConfiguration or parameters of other cmdlets discussed later in this document -

 - Activity = "Migrate"  
 - Mode = "LogOnly"  
 - MoveMailbox = "No"  
 - Link = $false  
 - Separate = $false  
 - LogPath = "C:\Temp\EM"  
 - Threads = 10  
 - Wait = $false  
 
## Logs Management

**Get-EMLogs** [-Identity] <string> [[-Type] <string>] [[-Ref] <string>]  [<CommonParameters>]
 
This cmdlet will get the logs for a samaccountname or batch.

**Start-EMLogsArchive**

This cmdlet will package up all the log files into a single zip with a naming convension based on the timestamp, e.g. 201905022011915.zip
 
**Clear-EMLogs**

This cmdlet will delete all logs and log archives from the logs directory.

Logging terminology -

 - GO: Start of cmdlet execution.
 - LOG: A log of information.
 - AR: Action required.
 - OK: Applied successfully or healthy state.
 - WARN: Issue detected but error action will be to continue.
 - ERR: Critical issue detected and an error has been thrown. Unable to continue. 

## Preparing Mailboxes

Please note, all user objects should have been created in the target domain before mailbox preparation is implemented.

To prepare a single mailbox you would use the following cmdlet -

**Start-EMProcessMailbox**

Start-EMProcessMailbox [-Samaccountname] <string> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}] [[-MoveMailbox] {Yes | No | Suspend}] [[-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Link] <bool>] [[-Separate] <bool>] [[-Wait] <bool>]  [<CommonParameters>]
 
At a minimum you must specify the *samaccountname* of the source object to be migrated.
 
The below example will provide a log only result of the mailbox in scope. Please note, the example has thrown an error because a user object in the target domain does not exist with the samaccountname of miguser1. The *migrate* activity requires a target user object to exist.
 
> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1  
> 20190502104602563 MIGUSER1 MIGRATE mailbox  
> 20190502104602588 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mo ...  
> 20190502104606856 MIGUSER1 Target not found in target domain 'DOMAINB.NET' and is required for activity 'MIGRATE' [ERR]  
> Target not found in target domain 'DOMAINB.NET' and is required for activity 'MIGRATE'  
> At C:\_work\migration\ExchangeMigration.psm1:96 char:4  
> \+             throw $comment  
> \+             ~~~~~~~~~~~~~~  
>     + CategoryInfo          : OperationStopped: (Target not foun...ivity 'MIGRATE':String) [], RuntimeException  
>     + FullyQualifiedErrorId : Target not found in target domain 'DOMAINB.NET' and is required for activity 'MIGRATE'   

The below example is the same command as above however it has completed successfully because the target user object exists. We can see that the *targettype* is null and therefore no preparation of this target has been completed at all.

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1  
> 20190502105334170 MIGUSER1 MIGRATE mailbox  
> 20190502105334184 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: LOGONLY; Mo...  
> 20190502105337920 MIGUSER1 SourceType: UserMailbox; SourcePDC: ENDPOINT.DOMAINA.NET; TargetType: ; TargetPDC: MPR...  
> 20190502105337958 MIGUSER1 Source is primary. Target to be mail enabled [AR]  
> 20190502105337990 MIGUSER1 Ready 

The below example takes things further. We are now instructing the mode to *prepare* rather than *logonly*. You can see a number of actions we taken on both the source and target objects. There were also some warnings where an action couldn't be completed because a target object did not exist yet. It did complete successfully however. 

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1 -Mode Prepare
> 20190502112256485 MIGUSER1 MIGRATE mailbox  
> 20190502112256495 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: PREPARE; Mo...  
> 20190502112302237 MIGUSER1 SourceType: UserMailbox; SourcePDC: ENDPOINT.DOMAINA.NET; TargetType: ; TargetPDC: MPR...  
> 20190502112302258 MIGUSER1 Source is primary. Target to be mail enabled [AR]  
> 20190502112306637 MIGUSER1 Waiting for mail enabled object to be ready in target domain 'DOMAINB.NET'. Waiting 300 ...  
> 20190502112309920 MIGUSER1 Waited 8 seconds  
> 20190502112309929 MIGUSER1 mail enabled OK in target domain 'DOMAINB.NET'  
> 20190502112309939 MIGUSER1 MIGRATE mailbox  
> 20190502112309948 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: PREPARE; Mo...  
> 20190502112313760 MIGUSER1 SourceType: UserMailbox; SourcePDC: ENDPOINT.DOMAINA.NET; TargetType: MailUser; Target...  
> 20190502112313785 MIGUSER1 Primary: SOURCE  
> 20190502112313863 MIGUSER1 Secondary msExchMailboxGuid attr update required [AR]  
> 20190502112314086 MIGUSER1 Secondary textEncodedORAddress attr update required [AR]  
> 20190502112314117 MIGUSER1 Secondary msExchHideFromAddressLists attr update required [AR]  
> 20190502112314128 MIGUSER1 Primary msExchRequireAuthToSendTo attr update required [AR]  
> 20190502112314360 MIGUSER1 Secondary targetaddress attr update required [AR]  
> 20190502112314372 MIGUSER1 Secondary mDBOverHardQuotaLimit attr update required [AR]  
> 20190502112314390 MIGUSER1 Secondary mDBOverQuotaLimit attr update required [AR]  
> 20190502112314412 MIGUSER1 Secondary mDBStorageQuota attr update required [AR]  
> 20190502112314430 MIGUSER1 Secondary mDBUseDefaults attr update required [AR]  
> 20190502112314442 MIGUSER1 Secondary delivContLength attr update required [AR]  
> 20190502112314456 MIGUSER1 Secondary submissionContLength attr update required [AR]  
> 20190502112315398 MIGUSER1 'miguser2' altRecipient no object found in secondary domain and will be excluded [WARN]  
> 20190502112315431 MIGUSER1 Primary proxyaddresses attr update required [AR]  
> 20190502112315457 MIGUSER1 Secondary proxyaddresses attr update required [AR]  
> 20190502112315475 MIGUSER1 Converting secondary to remote user mailbox [AR]  
> 20190502112315494 MIGUSER1 Secondary msExchModerationFlags attr update required [AR]  
> 20190502112316460 MIGUSER1 'miguser2' publicdelegates no object found in secondary domain and will be excluded [WARN]  
> 20190502112317399 MIGUSER1 'miguser2' msExchDelegateListLink no object found in secondary domain and will be exc... [WARN]  
> 20190502112317424 MIGUSER1 Primary msExchPoliciesExcluded attr update required [AR]  
> 20190502112317441 MIGUSER1 Primary msExchPoliciesIncluded attr update required [AR]  
> 20190502112317746 MIGUSER1 Primary user prepared in domain 'DOMAINA.NET' [OK]  
> 20190502112318041 MIGUSER1 Secondary user prepared in domain 'DOMAINB.NET' [OK]  
> 20190502112318072 MIGUSER1 Waiting for secondary AD changes to be ready. Waiting 300 seconds max  
> 20190502112321027 MIGUSER1 Waited 3 seconds  
> 20190502112324004 MIGUSER1 Checking full access permissions on primary  
> 20190502112328819 MIGUSER1 'DOMAINB\miguser2' full access missing [AR]  
> 20190502112329239 MIGUSER1 'DOMAINB\miguser2' does not exist in domain 'DOMAINB.NET' [WARN]  
> 20190502112329267 MIGUSER1 Checking send-as permissions on primary  
> 20190502112335434 MIGUSER1 'DOMAINB\miguser2' send-as missing [AR]  
> 20190502112335884 MIGUSER1 'DOMAINB\miguser2' does not exist in domain 'DOMAINB.NET' [WARN]  
> 20190502112335901 MIGUSER1 Ready [OK] 








