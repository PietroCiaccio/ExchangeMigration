## Some Examples

This a short README with some examples on how to use EM.

**Prepare a mailbox**

This will prepare the objects for user1 in the source and target Exchange Organizations for migration and coexistence.

*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare*

**Prepare a mailbox and pre-stage**

This will also copy up to 95% of the mailbox data but will not finish the mailbox migration.

*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare -MoveMailbox Suspend*

**Prepare a mailbox and migrate**

This will prepare and complete a mailbox migration. It should be noted that the cmdlet will not wait for the move request to complete. The cmdlet will need to be run again after the move request has completed in order to complete post migration tasks.

*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare -MoveMailbox Yes*

**Prepare a mailbox, migrate, wait for completion, and perform post migration tasks**

As above, but will wait and perform post migration tasks.

*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare -MoveMailbox Yes -Wait $true*

**Prepare a mailbox and link**
These will link the mailbox to the secondary domain user object.

*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare -MoveMailbox Yes -Wait $true -Link $true*
*Start-EMProcessMailbox -Samaccountname user1 -Mode Prepare -Link $true*
