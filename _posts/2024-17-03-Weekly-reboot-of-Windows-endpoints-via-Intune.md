---
title: "Weekly reboot of Windows endpoints via Intune"
date: 2024-03-17 00:00:00 +0200
categories: 
    - Intune
post-id: 0002
---

## **The requirements for my weekly reboots**

We needed to make sure our endpoints got weekly reboots. The task was “if uptime is more than 7 days, then reboot”.

## **Why Intune, whyyy**

With Intune at the moment, you are not able to say “if uptime is more than X, then reboot”. The only option via the setting catalog is a daily reboot at a specific time, or a reboot at 1 specified date. There is also a setting which allows you to reboot at a specified day and time weekly, however its currently in preview, and does not satisfy the requirement i had.

![](assets\post-content\0002\0002-01.png)

## **Powershell script**

So my solution to the problem, was to build a Powershell script that does it. It works by creating a scheduled task that basically runs every 5 minutes. The action of this scheduled task is to run another Powershell script that checks the uptime, and restarts the computer if its more than 7 days.

### **Powershell script you need to deploy in Intune**

The purpose of this script is to deploy a scheduled task, that makes sure the computers is rebooted weekly.

This is the script you need to deploy to endpoints in the Intune portal.

```plaintext
### Variables
$name = 'Weekly reboot'

### Check if schedule already exists
$currentTasks = Get-ScheduledTask
foreach ($t in $currentTasks) {
    if ($t.TaskName -eq $name) {
        Unregister-ScheduledTask -TaskName $t.TaskName -ErrorAction Stop -Confirm:$false
    }
}

### Create scheduled task
# Decode via base64decode.org UTF16-le
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand IwAjACAARwBlAHQAIAB1AHAAdABpAG0AZQANAAoAJABiAG8AbwB0AHUAcAB0AGkAbQBlACAAPQAgACgARwBlAHQALQBDAGkAbQBJAG4AcwB0AGEAbgBjAGUAIAAtAEMAbABhAHMAcwBOAGEAbQBlACAAVwBpAG4AMwAyAF8ATwBwAGUAcgBhAHQAaQBuAGcAUwB5AHMAdABlAG0AKQAuAEwAYQBzAHQAQgBvAG8AdABVAHAAVABpAG0AZQANAAoAJAB1AHAAdABpAG0AZQAgAD0AIAAoAEcAZQB0AC0ARABhAHQAZQApACAALQAgACQAYgBvAG8AdAB1AHAAdABpAG0AZQANAAoADQAKAGkAZgAgACgAJAB1AHAAdABpAG0AZQAuAFQAbwB0AGEAbABTAGUAYwBvAG4AZABzACAALQBnAHQAIAA2ADAANAA4ADAAMAApACAAewANAAoAIAAgACAAIAAjACAAVQBwAHQAaQBtAGUAIABpAHMAIABtAG8AcgBlACAAdABoAGEAbgAgADcAIABkAGEAeQBzAA0ACgAgACAAIAAgAHMAaAB1AHQAZABvAHcAbgAgAC8AcgAgAC8AdAAgADMAMAAwACAALwBjACAAIgBZAG8AdQByACAAYwBvAG0AcAB1AHQAZQByACAAdwBpAGwAbAAgAHIAZQBiAG8AbwB0ACAAaQBuACAANQAgAG0AaQBuAHUAdABlAHMALgAgAGAAbgAgAGAAbgAgAFIAZQBtAGUAbQBiAGUAcgAgAHQAbwAgAHMAYQB2AGUAIAB5AG8AdQByACAAdwBvAHIAawAhACAAYABuACAAYABuACAASQBmACAAeQBvAHUAIABoAGEAdgBlACAAYQBuAHkAIABxAHUAZQBzAHQAaQBvAG4AcwAsACAAcABsAGUAYQBzAGUAIABjAG8AbgB0AGEAYwB0ACAASQBUACAAaABlAGwAcABkAGUAcwBrACIADQAKAH0A'
$trigger = New-ScheduledTaskTrigger -Once -At ([datetime]"2024-01-01") -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 9999)
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM'
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
$taskRegister = Register-ScheduledTask $name -InputObject $task
```

### **The scheduled task Powershell script**

This is the script thats being run via the scheduled task. It actually does the rebooting part.

If you want to make changes to this script:

*   Insert the script into base64encode.org.
*   Choose UTF16-LE as “Destination character set”.
*   CRLF (Windows) as “Destination newline seperator”.
*   Click encode.
*   You will then see the encoded script. This needs to be pasted into the script thats deployed in Intune, aka the first script in this post. Its the $action variable and you are looking for.

```plaintext
## Get uptime
$bootuptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $bootuptime

if ($uptime.TotalSeconds -gt 604800) {
    # Uptime is more than 7 days
    shutdown /r /t 300 /c "Your computer will reboot in 5 minutes. `n `n Remember to save your work! `n `n If you have any questions, please contact IT helpdesk"
}
```

## **Fast startup**

If you are using fast startup, then the uptime would be misleading, and you cannot use my script as it currently is. You would need to get the actual real uptime in the script. I did not research this, since have turned off fast startup.