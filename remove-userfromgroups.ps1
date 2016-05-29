
<#
.SYNOPSIS
 Removes all groups from a disabled user  account

. DESCRIPTION
 Actually - it removes the disabled user from all group objects. There's a check to make sure that the user is disabled. If its not then it skips and writes a warning. A log is kept as a csv file 
 "\\dnvfile03\infosys$\powershell\logs\remove-userfromgroups.csv"

 This script supports -whatif and has a ConfirmImpact of High. This means that it will force a confirmation unless you explicitly turn it off (see examples).

 The script accepts VERBOSE to give more output.


.PARAMETER Usernames
 The Samid of the user. The formal parameter is called UserNameS, there's also an alias for it of SamID (because my fingers like typing that) and SamAccountName (so that it can take that field piped from get-aduser without needing to rename it). 

.PARAMETER nopause
 Causes the script to pause after warning that the user was either enabled or doesn't exist. This is needed when run from Hyena, otherwise the screen vanishes before the warning can be read.

.EXAMPLE
 remove-userfromgroups alicea
 Will prompt for confirmation then (if confirmed) remove the user alicea from all groups IF alicea is disabled - and then log the action. 

 If the user object is enabled it will return a warning and prompt to hit enter to continue

.EXAMPLE
 remove-userfromgroups bobb

 Will prompt for confirmation then (if confirmed) remove the user bobb from all groups IF bobb is disabled - and then log the action.

 If the user object is enabled it will return a warning and prompt to hit enter to continue

.EXAMPLE
 remove-userfromgroups carolc -confirm:false
 Will NOT prompt for confirmation 
 Will remove the user carolc from all groups IF carolc is disabled - and then log the action.

 If the user object is enabled it will return a warning and prompt to hit enter to continue

.EXAMPLE
 remove-userfromgroups daved -confirm:false -verbose
 Will NOT prompt for confirmation 
 Will remove the user daved from all groups IF daved is disabled - and then log the action.
 Will provide two sets of verbose output (if confirm is turned off, the confirm statement becomes a verbose statement)

 If the user object is enabled it will return a warning and prompt to hit enter to continue

.Example
 get-aduser -Identity erine | select samaccountname| G:\PowerShell\Scripts\remove-userfromgroups.ps1 -Confirm:$false -Verbose

 This example shows the way you can use the output of get-aduser. In the example only a single user-object is selected. It would work the same if a number of users was returned from get-aduser (such as all disabled objects).

 Will NOT prompt for confirmation 
 Will remove the user erine from all groups IF erine is disabled - and then log the action.
 Will provide two sets of verbose output (if confirm is turned off, the confirm statement becomes a verbose statement)

 If the user object is enabled it will return a warning and prompt to hit enter to continue

.EXAMPLE
 remove-userfromgroups noobjectexists

 An error message is displayed stating that the object can't be found followed by a warning and a prompt to continue (suppress that with -nopause)

 Will act the same as if the object exists and is enabled - it will return a warning that the object is not disabled and prompt to hit enter to continue.


.EXAMPLE
 remove-userfromgroups noobjectexists -nopause

 The nopause flag suppresses the prompt to hit enter if an object exists or is missing.


.NOTES
 Author: Dave Bremer
 Date: 7/4/2015


#>
[cmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='High')]
    Param ([Parameter (
                Mandatory = $TRUE, 
                ValueFromPipeLine = $TRUE,
                ValueFromPipelineByPropertyName = $TRUE
                )]
            [Alias('SamId')] #because my fingers like this
            [Alias('SamAccountName')] #this allows you to pipe from get-aduser (after selecting the samaccountname) without renaming
            [string[]] $UserNames,
            [switch] $nopause
        )

BEGIN {}

PROCESS{            
    foreach ($user in $usernames) {
       
       
       $userobj = get-aduser -Identity $User -properties memberof
       write-verbose ("User: {0} {1}  Enabled:{2}" -f $user,$userobj.name,$userobj.enabled)
       if ($userobj.Enabled -eq $false) { 
           $groupnames =  $userobj | select -expand memberof
           foreach ($group in $groupnames) {
                write-verbose ("Removing {0} from {1}" -f $user,$group) #comment this out if you lower the ConfirmImpact - otherwise you get double the verbosity

               if ($pscmdlet.ShouldProcess(("user:{0} Group:{1}" -f $user,$group))) {
                   Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
                   $LogAction = @{"Date" = get-date;
                                    "User" = $user;
                                    "Group" = $group;
                                    "RemovedBy" = $env:username
                                    }
                    $obj = New-Object -TypeName PSObject -Property $LogAction
                    $obj.psobject.typenames.insert(0, 'sdhb.script.remove-userfromgroups')
                    Export-Csv -Path "\\dnvfile03\infosys$\powershell\logs\remove-userfromgroups.csv" -InputObject $Obj -NoTypeInformation   -Append # requires powershell 3 for append
            }# whatif check
           } #foreach group
          
       } ELSE {
        Write-Warning "$User is NOT disabled (or doesn't exist) - skipping"
        if (-not $nopause) { Read-Host "Hit Enter to Continue"}
       }
    }
}

END{}
