# ExchangeMigration
The EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross-forest migration.<br> 
<br>
<b>Developed using the following -</b><br>
Powershell Version 5.<br>
Microsoft Exchange Server 2010 SP3 Update Rollup 22 on Microsoft Windows Server 2008 R2.<br>
Microsoft Exchange Server 2016 Cumulative Update 11 on Microsoft Windows Server 2016.<br>
<br>
# Background
Microsoft provides Prepare-MoveRequest.ps1. This will prepare the following attributes of a target AD (Active Directory) object -<br> 
msExchMailboxGUID<br> 
msExchArchiveGUID<br> 
msExchArchiveName<br> 
objectSid / masterAccountSidv
sAMAccountName<br> 
userAccountControlv
userPrincipalName<br> 
<br> 
It will then execute the Update-Recipient cmdlet to prepare the proxyAddresses attribute with the following and mail enable the target object -<br> 
Source SMTP addresses<br> 
X500 with the legacyExchangeDN of the source mail enabled object.<br> 
<br> 
It will also add the X500 with the legacyExchangeDN of the target mail enabled object on the source mailbox enabled object. <br> 
<br> 
Running the above in the target Exchange Organization against all mailbox enabled source objects will prepare the target Exchange Organisation, including GAL (Global Address List) Synchronisation, for migration.<br> 
<br> 
Running New-MoveRequest in the EMS (Exchange Management Shell) against a mailbox in the target Exchange Organization will migrate the mailbox and convert the source type to mail user. New-MoveRequest will also perform others migration tasks, such as full access permissions on the target mailbox.<br> 
<br> 
For full details on Prepare-MoveRequest please refer to Microsoft online documentation.<br> 
<br> 
The above does a lot of work for you but doesn't include many attributes and settings that may impact the experience of the end user. I wanted a toolset that would be simple to use, automated, and do everything, where possible. For this reason I developed the ExchangeMigration Powershell Module and wanted to share it with the community so it can help others.<br> 
<br> 
At the time of writing this document EM was created to meet the migration requirements of a project. The initial release may therefore not include everything you may wish to migrate. Updates and changes will be detailed in future release notes (below titled 'Version n').<br> 
<br> 
<b>In Scope</b><br>
Mailbox enabled objects.<br> 
Mail enabled objects.<br> 
<br> 
<b>Out of Scope</b><br>
Organizational migration preparation tasks.<br>
Object creation.<br> 
<br> 
<b>Pre-requisites</b><br>
The following needs to be configured before using EM -<br>
Cross-forest two way Active Directory trust.<br> 
Two way CA (Certificate Authority) trust.<br> 
Two way internal network connectivity.<br> 
Two way DNS name resolution.<br> 
Accepted domain using the format mail.onADDomain, e.g. mail.onCompany.net (ADDomain is the FQDN of the domain for the mail enabled object).<br> 
Cross-forest availability.<br> 
Cross-forest SMTP routing domains and internal connectors using the format mail.onADDomain (Will be used for routing emails to the correct Exchange Organization hosting the mailbox. Supports cross-forest mail flow and acts as the resource locator for availability and autodiscover services).<br> 
<br> 
EM should only be used to mail enable objects, for GAL synchronization, and to migrate mailboxes. The creation of objects in the target AD should be accomplished using AD migrations tools, such as the Microsoft ADMT (Active Directory Migration Tool) or another third-party AD migration tool, e.g. from Quest. It is important to note that AD migration tools must exclude all Exchange related attributes. All changes made by EM must not be overwritten. <br> 
<br> 
# Comments from author
This code is being shared as is to help others with their Exchange migration activities.<br>
Please make sure you test in an isolated test environment before using in production.<br>
If you choose to use any code shared in this repository then you are responsible for its execution and outcome.<br>
<br> 
# Version 0
<b>Mailboxes</b>

