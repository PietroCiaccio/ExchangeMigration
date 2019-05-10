## Usage

If you explore the cmdlets available with the EM Powershell Module you will see there are many but as a user you should only be executing a few. These are as follows -

**Setting Up**

- Write-EMConfiguration
- Get-EMConfiguration
- Test-EMConfiguration

**Logs Management**

- Get-EMLogs
- Clear-EMLogs
- Start-EMLogsArchive

**Processing Individual Objects**

- Start-EMProcessMailbox
- Start-EMProcessDistributionGroup
- Start-EMCleanActiveDirectoryObject

**Processing Batches**

- Start-EMProcessMailboxBatch
- Start-EMProcessDistributionGroupBatch

## Importing the Module and Setup

Run the following -

 - import-module .\ExchangeMigration.psm1

On the first run you will be presented with the following -

> Exchange Migration Powershell Module / *n.n.n*
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

> Exchange Migration Powershell Module / *n.n.n*  
>   
> Configuration detected. [OK]  
> Configuration successfully enabled. [OK]  
>  
> Use 'Read-EMConfiguration' to review.  
> To create a new configuration use the 'Write-EMConfiguration' cmdlet.  
> To test configuration data settings use 'Test-EMConfiguraion'  

**Write-EMConfiguration** [-SourceDomain] <string> [-SourceEndPoint] <string> [-SourceGALSyncOU] <string> [-TargetDomain] <string> [-TargetEndPoint] <string> [-TargetGALSyncOU] <string> [[-LogPath] <string>]
 
This cmdlet is used to create the configuration file. This will overwrite any configuration file that exists. The configuration file is created in the following location.

C:\Users\samaccountname\AppData\Local\EM\ExchangeMigration.config

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
 - Threads = 8 
 - Wait = $false  
 
## Logs Management

**Read-EMLogs** [-Identity] <string> [[-Type] <string>] [[-Ref] <string>]  [<CommonParameters>]
 
This cmdlet will get the logs for a samaccountname or batch.

**Start-EMLogsArchive**

This cmdlet will package up all the log files into a single zip with a naming convension based on the timestamp, e.g. 201905022011915.zip
 
**Clear-EMData**

This cmdlet will delete all logs, log archives, and data from the logs directory.

Logging terminology -

 - GO: Start of cmdlet execution.
 - LOG: A log of information.
 - AR: Action required.
 - OK: Applied successfully or healthy state.
 - WARN: Issue detected but error action will be to continue.
 - ERR: Critical issue detected and an error has been thrown. Unable to continue. 

## Preparing Mailboxes

Please note, all user objects should have been created in the target domain before mailbox preparation is implemented.

To remove all Exchange attributes from a user or group AD object use the following cmdlet -

**Start-EMCleanActiveDirectoryObject** [-Samaccountname] <String> [-SourceOrTarget] <String> [[-SourceDomain] <String>] [[-SourceCred] <PSCredential>] [[-TargetDomain] <String>] [[-TargetCred] <PSCredential>] [[-Confirm] <Boolean>] [<CommonParameters>]
 
Example use -

> PS C:\> Start-EMCleanActiveDirectoryObject -Samaccountname miguser1 -SourceOrTarget Source  
> 20190508084333857 MIGUSER1 Cleaning AD object in domain 'DOMAIN1.NET'  
> This will remove all Exchange attributes! Are you sure? [Y] Yes [N] No (default is "Y") :  
> 20190508084338467 MIGUSER1 Cleaned object [OK]  
> 20190508084338486 MIGUSER1 Ready  

To prepare a single mailbox you would use the following cmdlet -

**Start-EMProcessMailbox** [-Samaccountname] <string> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}] [[-MoveMailbox] {Yes | No | Suspend}] [[-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Link] <bool>] [[-Separate] <bool>] [[-Wait] <bool>]  [<CommonParameters>]
 
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
> 20190502105337920 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: ; TargetPDC: MPR...  
> 20190502105337958 MIGUSER1 Source is primary. Target to be mail enabled [AR]  
> 20190502105337990 MIGUSER1 Ready 

The below example takes things further. We are now instructing the mode to *prepare* rather than *logonly*. You can see a number of actions are taken on both the source and target objects. There were also some warnings where an action couldn't be completed because a target object did not exist yet. It did complete successfully however. 

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1 -Mode Prepare  
> 20190502112256485 MIGUSER1 MIGRATE mailbox  
> 20190502112256495 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: PREPARE; Mo...  
> 20190502112302237 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: ; TargetPDC: MPR...  
> 20190502112302258 MIGUSER1 Source is primary. Target to be mail enabled [AR]  
> 20190502112306637 MIGUSER1 Waiting for mail enabled object to be ready in target domain 'DOMAINB.NET'. Waiting 300 ...  
> 20190502112309920 MIGUSER1 Waited 8 seconds  
> 20190502112309929 MIGUSER1 mail enabled OK in target domain 'DOMAINB.NET'  
> 20190502112309939 MIGUSER1 MIGRATE mailbox  
> 20190502112309948 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: PREPARE; Mo...  
> 20190502112313760 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: MailUser; Target...  
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

The same command has been run again but this time it has been more successful because all user objects were present in the target domain.

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1 -Mode Prepare  
> 20190502115454173 MIGUSER1 MIGRATE mailbox  
> 20190502115454184 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: P...  
> 20190502115500028 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: Remote...  
> 20190502115500037 MIGUSER1 Primary: SOURCE  
> 20190502115501025 MIGUSER1 Secondary altRecipient attr update required [AR]  
> 20190502115501256 MIGUSER1 Secondary deliverAndRedirect attr update required [AR]  
> 20190502115501294 MIGUSER1 Secondary proxyaddresses attr update required [AR]  
> 20190502115502349 MIGUSER1 Secondary publicdelegates attr update required [AR]  
> 20190502115503338 MIGUSER1 Secondary msExchDelegateListLink attr update required [AR]  
> 20190502115503633 MIGUSER1 Secondary user prepared in domain 'DOMAINB.NET' [OK]  
> 20190502115506610 MIGUSER1 Checking full access permissions on primary  
> 20190502115508764 MIGUSER1 'DOMAINB\miguser2' full access missing [AR]  
> 20190502115517699 MIGUSER1 'DOMAINB\miguser2' full access added [OK]  
> 20190502115517714 MIGUSER1 Checking send-as permissions on primary  
> 20190502115523355 MIGUSER1 'DOMAINB\miguser2' send-as missing [AR]  
> 20190502115526012 MIGUSER1 'DOMAINB\miguser2' send-as added [OK]  
> 20190502115526025 MIGUSER1 Ready [OK]  

## Migrating Mailboxes

***Make sure all objects are prepared before moving any mailboxes. The GAL needs to be prepared in both Exchange Organizations otherwise there may be coexistence and / or mail flow issues.***

The following command will create a move request in the target Exchange Organization but will set it to not complete. This will pre-stage the mail data in the target up to 95%. This is useful because it means only a small amount of mail data will need to be synchronised at actual migration time.

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1 -Mode Prepare -MoveMailbox Suspend  
> 20190502115843968 MIGUSER1 MIGRATE mailbox  
> 20190502115843981 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: P...  
> 20190502115848443 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: Remote...  
> 20190502115848450 MIGUSER1 Primary: SOURCE  
> 20190502115857083 MIGUSER1 Creating move request. Move request state: None [AR]  
> 20190502115903127 MIGUSER1 Move request created and set to suspend. [OK]  
> 20190502115903139 MIGUSER1 Not waiting for move request to complete.  
> 20190502115903146 MIGUSER1 Ready [OK]  

The following command completes the migration. Note that this time the *wait* parameter has been set to TRUE. This means the cmdlet will wait for the mailbox to be migrated (up to 12 hours) and will then complete the post migration tasks. Also note that the *link* parameter has been set to TRUE. This will link the mailbox back to the source domain user object. This is useful if you need to migrate mailboxes before you can actually migrate the users to a new AD forest.

> PS C:\> Start-EMProcessMailbox -Samaccountname miguser1 -Mode Prepare -MoveMailbox Yes -Wait $true -Link $true  
> 20190502120823746 MIGUSER1 MIGRATE mailbox  
> 20190502120823758 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: P...  
> 20190502120828358 MIGUSER1 SourceType: UserMailbox; SourcePDC: SERVER.DOMAINA.NET; TargetType: Remote...  
> 20190502120828376 MIGUSER1 Primary: SOURCE  
> 20190502120834395 MIGUSER1 Resuming move request. Move request state: AutoSuspended [AR]  
> 20190502120837332 MIGUSER1 Resumed move request and set to complete. Waiting 43200 seconds to complete [OK]  
> 20190502120910273 MIGUSER1 Waited 36 seconds. State: InProgress  
> 20190502120943188 MIGUSER1 Waited 69 seconds. State: InProgress  
> 20190502121016189 MIGUSER1 Waited 102 seconds. State: InProgress  
> 20190502121049219 MIGUSER1 Waited 135 seconds. State: InProgress  
> 20190502121122339 MIGUSER1 Waited 168 seconds. State: InProgress  
> 20190502121155905 MIGUSER1 Waited 201 seconds. State: Completed  
> 20190502121155944 MIGUSER1 Move mailbox request [OK]  
> 20190502121155978 MIGUSER1 MIGRATE mailbox  
> 20190502121155997 MIGUSER1 SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activity: MIGRATE; Mode: P...  
> 20190502121200742 MIGUSER1 SourceType: MailUser; SourcePDC: SERVER.DOMAINA.NET; TargetType: UserMailb...  
> 20190502121200774 MIGUSER1 Primary: TARGET  
> 20190502121200796 MIGUSER1 Secondary targetaddress attr update required [AR]  
> 20190502121201021 MIGUSER1 Secondary mDBOverHardQuotaLimit attr update required [AR]  
> 20190502121201032 MIGUSER1 Secondary mDBOverQuotaLimit attr update required [AR]  
> 20190502121201041 MIGUSER1 Secondary mDBStorageQuota attr update required [AR]  
> 20190502121201050 MIGUSER1 Secondary mDBUseDefaults attr update required [AR]  
> 20190502121202028 MIGUSER1 Converting secondary to remote user mailbox [AR]  
> 20190502121204278 MIGUSER1 Secondary user prepared in domain 'DOMAINA.NET' [OK]  
> 20190502121207651 MIGUSER1 Move request state: Completed  
> 20190502121210840 MIGUSER1 Primary SIR attrs update required [AR]  
> 20190502121214334 MIGUSER1 Primary SIR attrs updated [OK]  
> 20190502121214382 MIGUSER1 Checking full access permissions on primary  
> 20190502121217642 MIGUSER1 Checking send-as permissions on primary  
> 20190502121224695 MIGUSER1 Converting primary to linked mailbox [AR]  
> 20190502121228475 MIGUSER1 Primary converted to linked mailbox [OK]  
> 20190502121228489 MIGUSER1 Ready [OK]  

At this point the following is true -

 - The mailbox has been migrated.
 - The mailbox has been linked to the source domain user object.
 - The source mailbox has been converted to a remote user mailbox.

## Batch Handling Mailboxes

EM includes a cmdlet for handling a large number of mailboxes.

**Start-EMProcessMailboxBatch** [-Samaccountnames] <array> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}] [[-MoveMailbox] {Yes | No | Suspend}] [[-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Link] <bool>] [[-Separate] <bool>] [[-Threads] <int>] [[-wait] <bool>] [[-ReportSMTP] <string>] [[-SMTPServer] <string>] [<CommonParameters>]
 
This is used in a similar way to Start-EMProcessMailbox with the exception of providing an array of samaccountname strings to the *samaccountname* parameter. The cmdlet will then invoke the Start-EMProcessMailbox cmdlet is a controlled way to automate the action across many mailboxes.

This example will show how to setup a couple of mailboxes.

> PS C:\> $sams = @()  
> PS C:\> $sams += "miguser1"  
> PS C:\> $sams += "miguser2"  

The follow command will prepare all samaccountnames in the array.

> PS C:\> Start-EMProcessMailboxBatch -Samaccountnames $sams -Mode Prepare  

You will see a progress bar and on completion you will see the following overview -

> PS C:\> Start-EMProcessMailboxBatch -Samaccountnames $sams -Mode Prepare  
> 
> Job:            EMProcessMailboxBatch20190502145445  
> Started:        05/02/2019 14:54:45  
> Completing:     05/02/2019 14:54:49  
> Completed:      05/02/2019 14:56:19  
> Duration:       2 minutes  
> Summary:        Total 2 ERR 0  

The following command gets more information on the job -

> PS C:\> Get-EMLogs -Identity EMProcessMailboxBatch20190502145445 | ft  
> Ref               Timestamp           Identity                            Type Comment  
> 20190502145445753 02/05/2019 14:54:45 EMPROCESSMAILBOXBATCH20190502145445 LOG  Samaccountname: miguser1 Sou ...  
> 20190502145447240 02/05/2019 14:54:47 EMPROCESSMAILBOXBATCH20190502145445 LOG  Samaccountname: miguser2 Sou ...  
> 20190502145619711 02/05/2019 14:56:19 EMPROCESSMAILBOXBATCH20190502145445 LOG  Total 2 ERR 0  

The following command gets detailed information for a single mailbox -

> PS C:\> Get-EMLogs -Identity miguser1 | ft  
> Ref               Timestamp           Identity                            Type Comment  
> 20190502145300219 02/05/2019 14:53:00 MIGUSER1 LOG  'EMProcessMailboxBatch20190502145234' started  
> 20190502145300311 02/05/2019 14:53:00 MIGUSER1 GO   MIGRATE mailbox  
> 20190502145300331 02/05/2019 14:53:00 MIGUSER1 LOG  SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activ ...  
> 20190502145301792 02/05/2019 14:53:01 MIGUSER1 ERR  Issue getting domain information for source domain 'DOMAINA.NET'  
> 20190502145301832 02/05/2019 14:53:01 MIGUSER1 ERR  Issue getting mail enabled user from source domain 'DOMAINA.NET'  
> 20190502145543088 02/05/2019 14:55:43 MIGUSER1 LOG  'EMProcessMailboxBatch20190502145445' started  
> 20190502145543147 02/05/2019 14:55:43 MIGUSER1 GO   MIGRATE mailbox  
> 20190502145543163 02/05/2019 14:55:43 MIGUSER1 LOG  SourceDomain: DOMAINA.NET; TargetDomain: DOMAINB.NET; Activ ...  
> 20190502145549958 02/05/2019 14:55:49 MIGUSER1 LOG  SourceType: RemoteUserMailbox; SourcePDC: SERVER ...  
> 20190502145550018 02/05/2019 14:55:50 MIGUSER1 LOG  Primary: TARGET  
> 20190502145551246 02/05/2019 14:55:51 MIGUSER1 WARN Secondary enabled attr does not match primary  
> 20190502145556485 02/05/2019 14:55:56 MIGUSER1 LOG  Move request state: Completed  
> 20190502145559633 02/05/2019 14:55:59 MIGUSER1 LOG  Checking full access permissions on primary  
> 20190502145602825 02/05/2019 14:56:02 MIGUSER1 LOG  Checking send-as permissions on primary  
> 20190502145615789 02/05/2019 14:56:15 MIGUSER1 OK   Ready  
> 20190502145615801 02/05/2019 14:56:15 MIGUSER1 LOG  'EMProcessMailboxBatch20190502145445' ended  

If you have access to an SMTP relay you can instruct the batch cmdlets to email you when the jobs is done by populating the *ReportSMTP* and *SMTPServer* parameters, where ReportSMTP is the recipient email address.

## Distribution Groups

Distribution groups are managed in the same way as mailboxes but with their associated cmdlets.

**Start-EMProcessDistributionGroup** [-Samaccountname] <string> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}]  [-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Separate] <bool>]  [<CommonParameters>]
 
**Start-EMProcessDistributionGroupBatch** [-Samaccountnames] <array> [[-SourceCred] <pscredential>] [[-TargetCred] <pscredential>] [[-SourceDomain] <string>] [[-TargetDomain] <string>] [[-Activity] {Migrate | GALSync}] [[-Mode] {Prepare | LogOnly}] [[-SourceEndPoint] <string>] [[-TargetEndPoint] <string>] [[-Separate] <bool>] [[-Threads] <int>] [[-ReportSMTP] <string>] [[-SMTPServer] <string>]  [<CommonParameters>]

## GALSync Activity

If you choose GALSYNC as an option for the *activity* parameter for either mailboxes or distribution groups then the following actions will be performed -

**Mailboxes**

 - If the user object is missing from the target domain then one will be created in the GALSync OU defined in the EM configuration file.
 - If the secondary object exists it will be moved to the GALSync OU if needed.
 - The secondary object will be hidden from the GAL.
 - The object will have a mailtip populated advising the sender that the recipient is external.
 - Cross forest settings will be removed (if they exist).
 - The user object will be disabled.
 
It should be noted that GALSync should only be used for objects you do not wish to fully migrate but are needed for the purposes of managing the coexistence experience.
 
 **Distribution Groups**
 
  - If the group object is missing from the target domain then one will be created in the GALSync OU defined in the EM configuration file.
 - If the secondary object exists it will be moved to the GALSync OU if needed.
 - The secondary object will be hidden from the GAL.
 - The object will have a mailtip populated advising the sender that the recipients are external.
 - Cross forest settings and permissions will be removed (if they exist).
 
 ## Separation
 
 This is an option with the mailbox cmdlets only. The *separate* parameter when set to TRUE will perform the following -
 
  - The secondary object will be hidden from the GAL.
  - The secondary object targetaddress attribute will be updated to use the primary SMTP address.
  - The secondary user object will be disabled.
  - Cross forest settings and permissions will be removed (if they exist).
  
So in separation coexistence support is removed but the secondary object exists and can be used to meet the purpose of the project.

## Final Notes

The majority of users interested in using this module will most likely just want to use the *migrate* activity to meet their requirements.

The author needed to include *GALSync* and *Separate* to meet the project requirements where the organization was being separated into two separate organizations but needed to work in a coexistence state until a set time. 

**Guidance**

It is advised to use EM as follows -

 - Use *Start-EMProcessMailboxBatch* to prepare all objects in the source and target Exchange Organizations.
 - Use *Start-EMProcessDistributionGroupBatch* to prepare all group objects in the source and target Exchange Organizations.

At this point the Exchange Organizations are prepared for coexistence and migration. Then continue as follows -

 - Use either *Start-EMProcessMailbox* or *Start-EMProcessMailboxBatch* to migrate mailboxes.
 - For the best migration experience mailboxes that have relationships should be migrated together.
 - Start with smaller numbers and then increase until the migration has been completed.
 
Once all mailboxes have been migrated you will need to perform Exchange Organizational level post migration tasks. This is out of scope of EM.

***Always make sure you test everything in a test environment first and you are happy with the results before using in production.***
