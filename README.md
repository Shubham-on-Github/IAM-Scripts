# IAM-Scripts
This Scripts are specifically IAM related tasks and daily, monthly, quarterly activities. (I just started so, will be adding more of these scripts in future.)

**Enable PIM Roles Script**
What it is: A tool that lets you turn on multiple admin roles at the same time, saving you from clicking through the Microsoft portal for each individual role.

How it works: You log in, and the script checks which admin roles you are allowed to use. It shows you a numbered list of these roles. You type the numbers of the roles you want, how long you need them, and your reason for needing them. The script then securely turns them all on for you behind the scenes.

Required permissions: The script needs two specific Microsoft Graph permissions to work: User.Read.All (to see who you are) and RoleManagement.ReadWrite.Directory (to actually turn the roles on).

Which account to use: You must use your dedicated admin account for this, not your regular daily email account.

**Disable PIM Roles Script**
What it is: A quick way to turn off your temporary admin roles as soon as you finish your work, which keeps your network secure.

How it works: It logs you in and finds only the roles you currently have turned on temporarily. It ignores any permanent roles you might have. It shows you a list of your active roles, you pick the ones you want to turn off, and the script immediately removes your access.

Required permissions: It uses the exact same permissions as the activation script: User.Read.All and RoleManagement.ReadWrite.Directory.

Which account to use: Use the exact same admin account you used to turn the roles on.
