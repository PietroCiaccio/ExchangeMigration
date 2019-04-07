# ExchangeMigration
EM (ExchangeMigration) Powershell module is used to assist a Microsoft Exchange cross forest mailbox and distribution group migration.

# Overview
Written specifically to migrate mailboxes and distribution groups from a Microsoft Exchange Server 2010 Organization to a Microsoft Exchange Server 2016 Organization. Other scenarios are not tested however they may be supported.<br> 
<br>
<b>Developed using the following -</b><br>
Powershell Version 5.<br>
Microsoft Exchange Server 2010 SP3 Update Rollup 22 on Microsoft Windows Server 2008 R2.<br>
Microsoft Exchange Server 2016 Cumulative Update 11 on Microsoft Windows Server 2016.<br>
<br>
<b>Written to achieve the following objectives -</b><br>
To provide the best user migration experience.<br>
Global Address List synchronization in both the source and target Exchange Organizations.<br>
Prepare mailbox enabled objects for migration.<br>
Migrate mailboxes.<br>
Convert mailboxes and recipient types.<br>

<b>In Scope</b><br>
Mailboxes (all types).<br>
Distribution Groups, excluding room lists.<br>

<b>Out of Scope</b><br>
Organizational migration preparation tasks.<br>
Contacts.

<b>Pre-requisites</b><br>
The following needs to be configured before using EM.<br>

# Notes
EM will only make the changes explicitly stated in the README.<br>

# Comments from author
This code is being shared as is to help others with their Exchange migration activities.<br>
Please make sure you test in an isolated test environment before using in production.<br>
If you choose to use any code shared in this repository then you are responsible for its execution and outcome.<br>

# Future
Contacts support.<br>
Forwarding support.<br>
Moderation support.<br>
Test<br>
