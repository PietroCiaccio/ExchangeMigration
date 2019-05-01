## ExchangeMigration (ALPHA)

The EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross-forest migration.

*EM is still in testing and has therefore being marked as an alpha release.*

**Developed using the following**

- Powershell Version 5.
- Microsoft Exchange Server 2010 SP3 Update Rollup 22 on Microsoft Windows Server 2008 R2.
- Microsoft Exchange Server 2016 Cumulative Update 11 on Microsoft Windows Server 2016.

### Background

At the time of writing, Microsoft provides the Prepare-MoveRequest.ps1 powershell script. This will prepare the following attributes of a target AD (Active Directory) object - 

- msExchMailboxGUID 
- msExchArchiveGUID 
- msExchArchiveName
- objectSid / masterAccountSid
- sAMAccountName
- userAccountControl
- userPrincipalName

It will then execute the Update-Recipient cmdlet to prepare the proxyAddresses attribute with the following and mail enable the target object -

- Source SMTP addresses
- X500 with the legacyExchangeDN of the source mail enabled object

It will also add the X500 with the legacyExchangeDN of the target mail enabled object on the source mailbox enabled object.
 
Running the above in the target ExchOrg (Exchange Organization) against all mailbox enabled source objects will prepare the target ExchOrg, including GAL (Global Address List) Synchronization, for migration.

Running New-MoveRequest in the EMS (Exchange Management Shell) against a mailbox in the target ExchOrg will migrate the mailbox and convert the source type to mail user. New-MoveRequest will also perform other migration tasks, such as full access permissions on the target mailbox.

For full details on Prepare-MoveRequest please refer to Microsoft online documentation. 

The above does a lot of work for you but doesn't include many attributes and settings that may impact the experience of the end user. I wanted a toolset that would be simple to use, automated, and do everything, where possible. For this reason I developed the ExchangeMigration Powershell Module and wanted to share it with the community so it can help others.

At the time of writing this document EM was created to meet the migration requirements of a project. The initial release may therefore not include everything you may wish to migrate. 

**In Scope**

- Mailboxes.
- Distribution Groups.

**Out of Scope**

- Organizational migration preparation tasks.
- Object creation.
- Contacts (support to be added in the future)

**Pre-Requisites**

The following needs to be configured before using EM -

- Cross-forest two way Active Directory trust.
- Two way CA (Certificate Authority) trust.<br> 
- Two way internal network connectivity.<br> 
- Two way DNS name resolution.<br> 
- Fully authoritative accepted domain using the format mail.on*Domain* (Domain is the AD domain FQDN for SMTP routing from one Exchange Org to the other. Must be done for both ExchOrgs, e.g. mail.on*domain1.net* in Exchange Org 1 and mail.on*domain2.net* in Exchange Org 2. The format will be used in the targetaddress attributes of mail enabled objects when forwarding to the opposing ExchOrg).
- Cross-forest availability.
- Cross-forest SMTP routing domains and internal connectors using the format mail.onADDomain (Will be used for routing emails to the correct ExchOrg hosting the mailbox. Supports cross-forest mail flow and acts as the resource locator for availability and autodiscover services).
- MRSProxy settings must be enabled in order to cross-forest migrate mailboxes.
- Policies, such as retention policies and retention tags, must be migrated in advance in order for them to be correctly applied to the target ExchOrg mail enabled objects.
 
EM should only be used to mail enable objects, for GAL synchronization, and to migrate mailboxes. The creation of objects in the target AD should be accomplished using AD migrations tools, such as the Microsoft ADMT (Active Directory Migration Tool) or another third-party AD migration tool, e.g. from Quest. It is important to note that AD migration tools must exclude all Exchange related attributes. All changes made by EM must not be overwritten. <br> 

### Comments From The Author

- This code is being shared "*as is*" to help others with their Exchange migration activities.
- Please make sure you test in an isolated test environment before using in production.
- ***If you choose to use any code shared in this repository then you are responsible for its execution and outcome.***

### The STPS Model

Please understand the concept of the STPS (Source Target Primary Secondary) Model used by EM.

**For mailbox enabled objects**

- Source - This refers to where mail enabled enabled objects will be migrated from.
- Target - This refers to where mail enabled enabled objects will be migrated to.
- Primary - This is the mailbox enabled object.
- Secondary - This is the mail enabled object in the opposite ExchOrg that is prepared / sychronized with the mailbox.

The mailbox is considered to be authoritative for attributes, permissions, and settings. Before a migration, the primary is located in the source and the secondary is located in the target. After a mailbox has been migrated to the target ExchOrg, then the primary is located in the target and the secondary is located in the source.

- Synchronization will always flow from primary to secondary, however a mailbox can only be migrated from source to target.
- The source target model supports the direction of the migration.
- The primary secondary model supports the synchronization of changes that can occur before and after the migration, e.g. user first or last name changes, changes to SMTP addresses, permissions etc.<br>

**For mail enabled objects**

This is the same as for mailbox enabled objects except that the source is always the primary and the target is always the secondary.

### Other Concepts

**Activities**

EM performs two activities. These are as follows -

- Migrate
- GALSync

**Migrate**

This is where EM will migrate mail data and settings from the source to the target.

**GALSync**

This is where EM will create an object in the target ExchOrg but it is only created to support coexistence between the two Exchange Organizations. The settings migrated will be limited and only used for GAL synchronization purposes. Objects configured this way are not intended to be fully migrated.
