<#
  .SYNOPSIS
    SSH 

  .DESCRIPTION
    Run commands on SSH servers.
    Copy files to SFTP servers.
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    Mandatory=$true,
    HelpMessage="IP or FQDN of SSH or SFTP server. Support multiple values seperated by comma."
  )]
  [string]
    $serverAddress, 
  
  [parameter(
    HelpMessage="User name to connect to the server (default is root)"
  )]
  [string]
    $serverUser="root", 
  
  [parameter(
    HelpMessage="Password of the user"
  )]
  [string]
    $serverPassword=$env:defaultPassword,  
##################### Start uploadFile parameters #####################  
  [parameter(
    parameterSetName="uploadFile",
    HelpMessage="Files to copy from local server or online. Each file per line."
  )]
  [string]
    $fileUrl,
  
  [parameter(
    parameterSetName="uploadFile",
    HelpMessage="File to upload from client machine"
  )]
  [string]
    $file,
  
  [parameter(
    parameterSetName="uploadFile",
    Mandatory=$true,
    HelpMessage="Destination path, such as /home/temp/"
  )]
  [string]
    $destination,
    
  [parameter(
    parameterSetName="uploadFile",
    HelpMessage="Protocol"
  )]
  [ValidateSet(
    "scp",
    "sftp"
  )]
  [string]
    $protocol="scp",
    
  [parameter(
    parameterSetName="uploadFile",
    helpMessage="Upload file to remote machine"
  )]
  [switch]
    $uploadFile,
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
    HelpMessage="Method to check if specific string could (or could not) be found in output. Default is 'like'."
  )]
  [ValidateSet(
    "like",
    "notlike",
    "match",
    "notmatch"
  )]
  [string]
    $outputCheck="like",
    
  [parameter(
    parameterSetName="runScript",
    HelpMessage="String pattern to find"
  )]
  [string]
    $pattern,
  
  [parameter(
    parameterSetName="runScript"
  )]
  [switch]
    $runScript
)

$web = new-object net.webclient
iex $web.downloadstring('https://raw.githubusercontent.com/9whirls/webcommander_walnut/master/powershell/utils.ps1')
iex $web.downloadstring('https://raw.githubusercontent.com/9whirls/webcommander_walnut_remote/master/ssh/object.ps1')

$serverList = @($serverAddress.split(",") | %{$_.trim()})
switch ($pscmdlet.parameterSetName) {
  "uploadFile" {
    $files = getFileList $fileUrl
    if ($file) {$files += $file}
    if (!$files) {
      addToResult "Fail - find file to copy"
      endExec
    }
    $serverList | % {
      $sshServer = newSshServer $_ $serverUser $serverPassword
      if ($protocol -eq "sftp"){
        $files | % { $sshServer.copyFileSftp($_, $destination) }
      } else {
        $files | % { $sshServer.copyFileScp($_, $destination) }
      }
    }
  }
  "runScript" {
    $serverList | % {
      $sshServer = newSshServer $_ $serverUser $serverPassword
      $sshServer.runCommand($scriptText, $outputCheck, $pattern)
    }
  }
}
