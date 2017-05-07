<#
  .SYNOPSIS
    Run workflow as command

  .DESCRIPTION
    This command runs a workflow as a command.
    This command could also be embedded in a workflow.
  
  .FUNCTIONALITY
    Workflow
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: liuj@vmware.com
#>

Param (
  [parameter(
    Mandatory=$true,
    HelpMessage="Name of the workflow"
  )]
  [string]
    $name,
    
  [parameter(
    HelpMessage="Type of the workflow. Default is 'serial'"
  )]
  [validateSet(
    "serial",
    "parallel"
  )]
  [string]
    $type="serial",  
    
  [parameter(
    HelpMessage="Action upon error. Default is 'stop'"
  )]
  [validateSet(
    "stop",
    "continue"
  )]
  [string]
    $actionOnError="stop",

  [parameter(
    HelpMessage="Workflow in form of JSON. If content is too long, save it in a file and use workflowUrl or file to load it."
  )]
  [string]
    $workflow,
  
  [parameter(
    HelpMessage="Workflow files on webcommander server or online. Each file per line."
  )]
  [string]
    $workflowOnServer
)

. .\utils.ps1

function replaceVar {
  param ($varName, $varValue, $definedVar)
  if ($varValue) {
    $newValue = $varValue
    if ($definedVar) {
      foreach ($dv in $definedVar) {
        if ($dv.value.gettype().name -eq "string") {
          $newValue = $newValue -ireplace $dv.name, $dv.value
        }
      }
      $regex = [regex]"(\['[(\w)\-]*'\])+"
      $squareText = $regex.matches($newValue).value
      foreach ($s in $squareText) {
        $k = $s.replace('][','.').replace("['",'$').trim(']').replace("JSON'",'JSON')
        $k = invoke-expression $k
        if ($k) {
          $newValue = $newValue.replace($s,$k)
        }
      }
    }
  } else {
    $newValue = (get-variable -scope global -name $varName -ea silentlycontinue).value
  }
  return $newValue
}

function getJsonObj {
  param ($jsonStr)
  try {
    $jsonObj = $jsonStr | convertFrom-Json
    return $jsonObj
  } catch {
    addToResult "Fail - read workflow JSON"
    endError
  }
}

function runCmd {
  param ($cmd, $i)
  addToResult "Info - start command $i"
  $definedVar = get-variable -scope global -exclude $existVar.name
  if ($cmd.disabled) {
    addToResult "Info - skip disabled command"
  } elseif ($cmd.script -eq "sleep") { 
    $second = if ($cmd.second) { $cmd.second } else { $cmd.parameters[0].value }
    $second = replaceVar "second" $second $definedVar
    if ($second -lt 1){$second = 1}
    elseif ($second -gt 3600) {$second = 3600}
    start-sleep $second
    addToResult "Info - sleep $second seconds"
  } elseif ($cmd.script -eq "defineVariable") {
    $varList = $cmd.parameters[0].value.split("`n") | %{$_.trim()}
    foreach ($var in $varList) {
      $varName = $var.split('=',2)[0]
      $varValue = replaceVar "variableList" $var.split('=',2)[1] $definedVar
      Set-Variable -Name $varName -Value $varValue -Scope global -force
    }
    addToResult "Info - define global variables"
  } else {
    $hash = @{script=$cmd.script; method=$cmd.method}
    foreach ($param in $cmd.parameters){
      if (!$param.parametersets -or ($param.parametersets -contains $cmd.method)) {
        if ($param.value) {
          $value = replaceVar $param.name $param.value $definedVar
          $hash.add($param.name, $value)
        }
      }
    }
    
    if ($type -eq "parallel") {
      start-job -ScriptBlock {
        invoke-webRequest -timeoutsec 86400 -uri $args[0] -body $args[1]
      } -argumentList $url,$hash -name "command $i"
    } else {
     
      $s = Invoke-WebRequest -timeoutsec 86400 -uri $url -body $hash
      $s = $s.content | convertfrom-json
      if ($s.returncode -ne '4488') { 
        $cmdResult = "Fail"
      } else {
        $cmdResult = "Success"
        if ($cmd.variables) {
          $varList = $cmd.variables.split("`n") | %{$_.trim()}
          foreach ($var in $varList) {
            $varName = $var.split('=',2)[0]
            $varValue = invoke-expression ('$s.' + $var.split('=',2)[1])
            Set-Variable -Name $varName -Value $varValue -Scope global
          }
        }
      }
      
      addToResult "$cmdResult - execute command $i"
      $global:result += $s.output
    }
  }
  addToResult "Info - end command $i"
  return $cmdResult
}

$allFlow = @()
if ($workflow) {$allFlow += getJsonObj $workflow}
if ($workflowOnServer) {
  $jsonFiles = @()
  $fileList = @($workflowOnServer.split("`n") | %{$_.trim()})
  $fileList | % {
    $f = "..\www\" + $_
    if (test-path $f) {
      $jsonFiles += $f
    } else {
      addToResult "Fail - find $_ on server"
    }
  } 
}
foreach ($jf in $jsonFiles) {
  $allFlow += getJsonObj ((get-content $jf) -join "`n")
}

if (!$allFlow) {
  addToResult "Fail - find workflow definition"
  endExec
}

addToResult "Info - Start workflow $name" 
addSeparator

$url = "http://localhost/exec.php"
$existVar = get-variable -scope global
$result = "Success"
$i = 1

foreach ($cmd in $allFlow) {
  if ($cmd.script -eq $null) {continue}
  if ($i -gt 1) {addSeparator}
  $cmdResult = runCmd $cmd $i
  if (($cmdResult -eq "Fail") -and ($actionOnError -eq "stop")) {
    $result = "Fail"
    break
  }
  $i++
}

if ($type -eq "parallel") {
  addToResult "Info - wait parallel commands execution"
  get-job | wait-job
  foreach ($job in (get-job)) {
    addSeparator
    $s = (receive-job $job).content | convertfrom-json
    if ($s.returncode -ne '4488') {
      $result = "Fail"
      $cmdResult = "Fail"
    } else {
      $cmdResult = "Success"
    }
    addToResult "$cmdResult - execute $($job.name)"
    $global:result += $s.output
  }
}
addSeparator
addToResult "$result - run workflow $name in $type"
