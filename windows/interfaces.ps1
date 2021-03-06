<#
  .SYNOPSIS
    Windows

  .DESCRIPTION
    This command consists of multiple methods for 
    manipulating remote Windows machines.
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: liuj@vmware.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    Mandatory=$true,
    HelpMessage="IP / FQDN of target Windows machine. Support multiple values separated by comma."
  )]
  [string]
    $winAddress, 
  
  [parameter(
    HelpMessage="User of target Windows machine (default is administrator)"
  )]
  [string]  
    $winUser="administrator", 
    
  [parameter(
    HelpMessage="Password of winUser"
  )]
  [string]  
    $winPassword=$env:defaultPassword,
##################### Start changeHostName parameters #####################    
  [parameter(
    parameterSetName="changeHostname",
    Mandatory=$true,
    HelpMessage="New host name. Support multiple values separated by comma."
  )]
  [string]
    $newHostName,
    
  [parameter(
    parameterSetName="changeHostname"
  )]
  [switch]
    $changeHostname,
##################### Start enableRdp parameters #####################    
  [parameter(
    helpMessage="Enable RDP access to the Windows machine",
    parameterSetName="enableRdp"
  )]
  [Switch]
    $enableRdp,
##################### Start uploadFile parameters #####################    
  [parameter(
    parameterSetName="uploadFile",
    Mandatory=$true,
    HelpMessage="Select a file"
  )]
  [string]
    $file,
    
  [parameter(
    parameterSetName="uploadFile",
    HelpMessage="Destination path. Default is c:\temp\"
  )]
  [string]
    $destination="c:\temp\",
    
  [parameter(
    parameterSetName="uploadFile",
    HelpMessage="Upload file to remote Windows machine"
  )]
  [switch]
    $uploadFile,
##################### Start readFile parameters #####################    
  [parameter(
    parameterSetName="readFile",
    Mandatory=$true,
    HelpMessage="File path"
  )]
  [string]
    $filePath,
    
  [parameter(
    parameterSetName="readFile",
    HelpMessage="Number of lines to read. Count from top if positive; 
      Count from bottom if negative. Read all if not defined."
  )]
  [string]
    $numberOfLine,
    
  [parameter(
    parameterSetName="readFile",
    HelpMessage="Get file content from remote Windows machine"
  )]
  [switch]
    $readFile,
##################### Start listApp parameters #####################    
  [parameter(
    helpMessage="List installed application",
    parameterSetName="listApp"
  )]
  [switch]
    $listApp,
##################### Start restart parameters #####################    
  [parameter(
    parameterSetName="restart"
  )]
  [switch]
    $restart,
##################### Start shutdown parameters #####################    
  [parameter(
    parameterSetName="shutdown"
  )]
  [switch]
    $shutdown,
##################### Start checkWindowsUpdate parameters #####################    
  [parameter(
    parameterSetName="checkWindowsUpdate",
    helpMessage="Search availabe Windows Updates on internet"
  )]
  [switch]
    $checkWindowsUpdate,
##################### Start windowsUpdate parameters #####################    
  [parameter(parameterSetName="windowsUpdate")]
  [parameter(parameterSetName="windowsUpdateSync")]
  [parameter(HelpMessage="Windows update server from which to download updates, default is 'Internal'")]
  [ValidateSet(
    "Internal",
    "External"
  )]
  [string]  
    $updateServer="External",
  
  [parameter(parameterSetName="windowsUpdate")]
  [parameter(parameterSetName="windowsUpdateSync")]
  [parameter(HelpMessage="Severity of the update to install, default is 'Critical'")]
  [ValidateSet(
    "Critical",
    "Important",
    "Moderate",
    "Low",
    "All"
  )]
  [string]  
    $severity="Critical",
  
  [parameter(
    parameterSetName="windowsUpdate",
    helpMessage="Trigger Windows update"
  )]
  [switch]
    $windowsUpdate,
##################### Start windowsUpdateSync parameters #####################    
  [parameter(
    parameterSetName="windowsUpdateSync",
    helpMessage="Run Windows update synchronously"
  )]
  [switch]
    $windowsUpdateSync,
##################### Start runScript parameters #####################    
  [parameter(
    parameterSetName="runScript",
    Mandatory=$true,
    HelpMessage="Script text"
  )]
  [string]
    $scriptText,
    
  [parameter(
    parameterSetName="runScript",
    HelpMessage="Script type.
      Bat: asynchronous, command returns immediately after triggering the script
      Powershell: synchronous, command returns on script completion
      Interactive: synchronous, guestUser must have already logged on
      InteractivePs1: synchronous, guestUser must have already logged on"
  )]
  [ValidateSet(
    "Bat",
    "Powershell",
    "Interactive",
    "InteractivePs1"
  )]
  [string]  
    $scriptType="Bat",
    
  [parameter(
    parameterSetName="runScript"
  )]
  [switch]
    $runScript,
##################### Start autoLogon parameters #####################    
  [parameter(
    parameterSetName="autoLogon",
    HelpMessage="If enable, winUser automatically logon after Windows starts",
    Mandatory=$true
  )]
  [ValidateSet(
    "disable",
    "enable"
  )]
  [string]
    $action,
    
  [parameter(
    parameterSetName="autoLogon"
  )]
  [switch]
    $autoLogon,
##################### Start joinDomain parameters #####################    
  [parameter(
    parameterSetName="joinDomain",
    Mandatory=$true,
    HelpMessage="Name of the domain to join"
  )]
  [string]
    $domainName,
    
  [parameter(
    parameterSetName="joinDomain",
    HelpMessage="User of the domain (default is administrator)"
  )]
  [string]
    $domainUser="administrator",
  
  [parameter(
    parameterSetName="joinDomain",
    HelpMessage="Password of the domain user"
  )]
  [string]
    $domainPassword=$env:defaultPassword,
    
  [parameter(
    parameterSetName="joinDomain",
    HelpMessage="IP address of DNS server"
  )]
  [string]
    $dnsIp,
    
  [parameter(parameterSetName="joinDomain")]
  [switch]
    $joinDomain
)

. .\utils.ps1
$web = new-object net.webclient
iex $web.downloadstring('https://raw.githubusercontent.com/9whirls/webcommander_walnut_remote/master/windows/object.ps1')

$winList = getWinList $winAddress $winUser $winPassword
switch ($pscmdlet.parameterSetName) {
  "changeHostName" { 
    $newNameList = @($newHostName.split(",") | %{$_.trim()})
    if ($winList.count -ne $newNameList.count) {
      addToResult "Fail - machine number and name number don't match"
      endExec
    }
    for ($i=0;$i -lt $winList.count; $i++) {
      $winList[$i].changeHostName($newNameList[$i])
    }
  }
  "enableRdp" {
    $winList | % {
      $_.enableRdp()
    } 
  }
  "uploadFile" {
    $winList | % {
      $_.sendFile("$file","$destination")
    } 
  }
  "readFile" {
    $winList | % {
      $conent = $_.readFile("$filePath","$numberOfLine")
      addToResult $content "raw"
    } 
  }
  "listApp" {
    $winList | % {
      $_.getInstalledApp()
    } 
  }
  "restart" {
    $winList | % {
      $_.restart()
    } 
  }
  "shutdown" {
    $winList | % {
      $_.shutdown()
    } 
  }
  "runScript" {
    $winList | % {
      if ($scriptType -eq "Powershell") {
        $result = $_.executePsTxtRemote($scriptText, "run powershell script in VM")
      } elseif ($scriptType -eq "interactive"){
        $result = $_.runInteractiveCmd($scriptText)
      } elseif ($scriptType -eq "interactivePs1"){
        $result = $_.runInteractivePs1($scriptText)
      } else {
        $scriptText | set-content "..\www\upload\$ip.txt"
        $_.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
        $script = "Invoke-WmiMethod -path win32_process -name create -argumentlist 'c:\temp\script.bat'"
        $result = $_.executePsTxtRemote($script, "trigger batch script in VM")
      }
      # addToResult $result "raw"
      write-output $result 
    } 
  }
  "autoLogon" {
    $winList | % {
      if ($action -eq "enable") {
        $_.autoadminlogon("domain")
      } else {
        $_.noautoadminlogon()
      }
    } 
  }
  "checkWindowsUpdate" {
    $winList | % {
      $_.checkWindowsUpdate()
    } 
  }
  "windowsUpdate" {
    $winList | % {
      $_.windowsUpdate($updateServer, $severity)
    } 
  }
  "windowsUpdateSync" {
    $winList | % {
      $_.windowsUpdateSync($updateServer, $severity)
    }
  }
  "joinDomain" {
    $winList | % {
      $_.joinDomain($domainName, $domainUser, $domainPassword, $dnsIp)
      $_.restart()
    }
  }
}
