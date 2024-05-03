---
title: "Assign Azure SQL Database permissions to Entra users via groups"
date: 2024-03-03 00:00:00 +0200
categories: [Azure SQL Database]
tags: [Azure SQL Database]
identifier: 0001
---

## **Scenario**

Imagine that you have 100 different Azure SQL Databases in your environment.

What are you gonna do, when you get a new employee that needs access? What if an employee no longer needs permissions? How do you do this most effortlessly?

Do you manually login to each database and run the SQL commands? Nooo, that would take a long time. I propose that you do it via a Entra groups instead, then it literally takes 2 seconds to give permissions to a user.

Microsoft already has it documented that its possible, but they don’t really make it obvious (as of March 2024). It took me some time to figure out that it was possible (maybe i’m not the brightest 😄). So i’m making this post to help you out and show you how i think is a great way to do it.

## **Azure RBAC vs SQL permissions**

The first time i had to assign permissions inside an Azure SQL Database to a user, i figured that it could be done via Azure RBAC, that’s how you assign permissions with many of the popular Azure services, but no, that’t not how it works in Azure SQL Database.

Azure RBAC is used to manage the Azure SQL Server and Azure SQL Database resources inside Azure. E.g creating new databases, scaling the Azure SQL Server to get more resources, configuring networking, replicas, etc.

Permissions to read and modify the actual data inside the databases is managed via SQL queries being run on the database server, just like you normally do on-premise.

So in short, permissions inside the database is configured on the database with SQL queries, SSMS etc. Its not done in the Azure portal.

## **So how are we gonna give database permissions to users, without having to login to the databases and do SQL queries?**

I propose that you create groups in Entra. Then login to the databases and give “database-level roles” to those groups.  
Now all you have to do to give access to a new user, is to add them to the Entra group.

### **SQL query**

```plaintext
-- If you are having issues, then remember to specifiy database when connecting;

-- Remember to use an Entra user to run this query, since you cannot add entra uses with a normal SQL account;

-- Statement to see which database you are connnected to;
-- If you don't specifiy database when connecting, then you are probably connected to the master database.
-- SELECT db_name() as DatabaseYouAreConnectedTo;


-- Create Microsoft Entra Group for Azure SQL Database;
CREATE USER [groupName] FROM EXTERNAL PROVIDER;

-- Add the group to a role;
EXEC sp_addrolemember 'paste-database-level-role-here','groupName';
```

## **Example**

### **Prerequisite**

When you create an Azure SQL Server, then you can choose between these 3 authentication methods. I’m gonna assume you already choose either “Only Microsoft Entra-only authentication” or “Both SQL and Microsoft Entra authentication”.

*   Only Microsoft Entra-only authentication.
*   Both SQL and Microsoft Entra authentication.
*   Only SQL authentication.

I’m also gonna assume you can create the Entra groups yourself.

### **1) Permissions i want to delegate.**

<table style="border-width:0px;"><tbody><tr><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;"><strong>Group</strong></td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;"><strong>Permissions</strong></td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;"><strong>Members</strong></td></tr><tr><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">FelixDB – Reader</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">Read</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">Bob</td></tr><tr><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">FelixDB – Writer</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">Read/write</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">Alice</td></tr><tr><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">&nbsp;</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">&nbsp;</td><td style="border:1px solid rgb(240, 240, 240);padding:4px 10px;">&nbsp;</td></tr></tbody></table>

![](https://github.com/danielthorvil/danielthorvil.github.io/blob/e887940056101675484e40ac7b10ecf4121a162f/assets/id0001-pic1.png)

![](https://github.com/danielthorvil/danielthorvil.github.io/blob/e887940056101675484e40ac7b10ecf4121a162f/assets/id0001-pic2.png)

## **2) Logging in**

I’m gonna start by connecting to the database using an Entra account, you cannot use an SQL account for this! You need to use an Entra user.  
If you don’t know who has access to the server, then use the “Microsoft Entra admin” account. This user will always have the db\_owner role.

![](https://github.com/danielthorvil/danielthorvil.github.io/blob/e887940056101675484e40ac7b10ecf4121a162f/assets/id0001-pic3.png)

Remember to specify the correct database when connecting (because contained users). I’m using SQL Server Management Studio to connect.

![](https://cloudwithfelix.com/wp-content/uploads/2024/03/Screenshot-2024-03-12-210036.png)

![](https://cloudwithfelix.com/wp-content/uploads/2024/03/Screenshot-2024-03-12-210041.png)

### **3) Delegating permissions to groups**

```plaintext
-- If you are having issues, then remember to specifiy database when connecting.

-- Remember to use an Entra user to run this query, since you cannot add entra uses with a normal SQL account.

-- Statement to see which database you are connnected to.
-- If you don't specifiy database when connecting, then you are probably connected to the master database.
SELECT db_name() as DatabaseYouAreConnectedTo;


-- Create Microsoft Entra Group for Azure SQL Database.
CREATE USER [FelixDB - Reader] FROM EXTERNAL PROVIDER;

-- Add the group to a role;
EXEC sp_addrolemember 'db_datareader','FelixDB - Reader';

-- Create Microsoft Entra Group for Azure SQL Database.
CREATE USER [FelixDB - Writer] FROM EXTERNAL PROVIDER;

-- Add the group to a role;
EXEC sp_addrolemember 'db_datareader','FelixDB - Writer';
EXEC sp_addrolemember 'db_datawriter','FelixDB - Writer';
```

### **4) Checking your work**

You can use the following SQL query to see if your Entra groups has the correct roles.

```plaintext
SELECT DP1.name AS DatabaseRoleName,   
    isnull (DP2.name, 'No members') AS DatabaseUserName   
FROM sys.database_role_members AS DRM  
RIGHT OUTER JOIN sys.database_principals AS DP1  
    ON DRM.role_principal_id = DP1.principal_id  
LEFT OUTER JOIN sys.database_principals AS DP2  
    ON DRM.member_principal_id = DP2.principal_id  
WHERE DP1.type = 'R'
ORDER BY DP1.name; 
```

Since this is a test environment and i have logins for both Both and Alice, then i’m also gonna login as them, and see if they are able to read, and in the case of Alice also write.

## **Sources**

[https://learn.microsoft.com/en-us/azure/azure-sql/database/logins-create-manage?view=azuresql](https://learn.microsoft.com/en-us/azure/azure-sql/database/logins-create-manage?view=azuresql)

[https://learn.microsoft.com/en-us/azure/azure-sql/database/security-server-roles?view=azuresql](https://learn.microsoft.com/en-us/azure/azure-sql/database/security-server-roles?view=azuresql)

[https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?view=azuresql&tabs=azure-powershell](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?view=azuresql&tabs=azure-powershell)

[https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview?view=azuresql](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview?view=azuresql)

[https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles?view=sql-server-ver16](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles?view=sql-server-ver16)

[https://learn.microsoft.com/en-us/sql/relational-databases/security/contained-database-users-making-your-database-portable?view=sql-server-ver16](https://learn.microsoft.com/en-us/sql/relational-databases/security/contained-database-users-making-your-database-portable?view=sql-server-ver16)

[https://stackoverflow.com/questions/31120912/how-to-view-the-roles-and-permissions-granted-to-any-database-user-in-azure-sql](https://stackoverflow.com/questions/31120912/how-to-view-the-roles-and-permissions-granted-to-any-database-user-in-azure-sql)