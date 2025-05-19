<#
=============================================================================================
Name:           Export Microsoft 365 Inactive Users Report using MS Graph PowerShell
Version:        1.0

Script Highlights:
~~~~~~~~~~~~~~~~~
1.The single script allows you to generate 10+ different inactive user reports.
2.The script can be executed with an MFA-enabled account too. 
3.The script supports Certificate-based authentication (CBA). 
4.Provides details about non-interactive sign-ins too. 
5.You can generate reports based on inactive days.
6.Helps to filter never logged-in users alone. 
7.Generates report for sign-in enabled users alone. 
8.Supports filtering licensed users alone. 
9.Gets inactive external users report. 
10.Export results to CSV file. 
11.The assigned licenses column will show you the user-friendly-name like ‘Office 365 Enterprise E3’ rather than ‘ENTERPRISEPACK’. 
12.Automatically installs the MS Graph PowerShell module (if not installed already) upon your confirmation. 
13.The script is scheduler friendly.
=============================================================================================
#>

Param
(
    [int]$InactiveDays,
    [int]$InactiveDays_NonInteractive,
    [switch]$ReturnNeverLoggedInUser,
    [switch]$EnabledUsersOnly,
    [switch]$DisabledUsersOnly,
    [switch]$LicensedUsersOnly,
    [switch]$ExternalUsersOnly,
    [switch]$CreateSession,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [switch]$NoMenu
)

Function Show-Menu {
    Clear-Host
    Write-Host "=== Microsoft 365 Inactive User Report Options ==="
    Write-Host "1. All Users (No Filters)"
    Write-Host "2. Licensed Users Only"
    Write-Host "3. Enabled Users Only"
    Write-Host "4. Disabled Users Only"
    Write-Host "5. External Users Only"
    Write-Host "6. Never Logged In Users"
    Write-Host "7. Custom Inactive Days Filter"
    Write-Host "Q: Quit"
    Write-Host
}

Function Get-UserMenuSelection {
    # Skip menu if NoMenu switch is provided or if any filter parameters are specified directly
    if ($NoMenu -or 
        $InactiveDays -gt 0 -or 
        $InactiveDays_NonInteractive -gt 0 -or 
        $ReturnNeverLoggedInUser -or 
        $EnabledUsersOnly -or 
        $DisabledUsersOnly -or 
        $LicensedUsersOnly -or 
        $ExternalUsersOnly) {
        return
    }
    
    do {
        Show-Menu
        $choice = Read-Host "Please choose an option"
        
        switch ($choice) {
            '1' { 
                # All Users (No Filters)
                break
            }
            '2' { 
                # Licensed Users Only
                $script:LicensedUsersOnly = $true
                break
            }
            '3' { 
                # Enabled Users Only
                $script:EnabledUsersOnly = $true
                break
            }
            '4' { 
                # Disabled Users Only
                $script:DisabledUsersOnly = $true
                break
            }
            '5' { 
                # External Users Only
                $script:ExternalUsersOnly = $true
                break
            }
            '6' { 
                # Never Logged In Users
                $script:ReturnNeverLoggedInUser = $true
                break
            }
            '7' { 
                # Custom Inactive Days Filter
                $interactiveDays = Read-Host "Enter minimum inactive days for interactive logins (leave blank for no filter)"
                if ($interactiveDays -match "^\d+$") {
                    $script:InactiveDays = [int]$interactiveDays
                }
                
                $nonInteractiveDays = Read-Host "Enter minimum inactive days for non-interactive logins (leave blank for no filter)"
                if ($nonInteractiveDays -match "^\d+$") {
                    $script:InactiveDays_NonInteractive = [int]$nonInteractiveDays
                }
                break
            }
            'Q' { 
                Write-Host "Exiting..."
                exit
            }
            default {
                Write-Host "Invalid option, please try again." -ForegroundColor Red
                continue
            }
        }
    } while ($choice -notin '1','2','3','4','5','6','7','Q')

    Write-Host "Selected Options:"
    if ($script:LicensedUsersOnly) { Write-Host "- Licensed Users Only" -ForegroundColor Cyan }
    if ($script:EnabledUsersOnly) { Write-Host "- Enabled Users Only" -ForegroundColor Cyan }
    if ($script:DisabledUsersOnly) { Write-Host "- Disabled Users Only" -ForegroundColor Cyan }
    if ($script:ExternalUsersOnly) { Write-Host "- External Users Only" -ForegroundColor Cyan }
    if ($script:ReturnNeverLoggedInUser) { Write-Host "- Never Logged In Users Only" -ForegroundColor Cyan }
    if ($script:InactiveDays -gt 0) { Write-Host "- Inactive for at least $($script:InactiveDays) days (interactive logins)" -ForegroundColor Cyan }
    if ($script:InactiveDays_NonInteractive -gt 0) { Write-Host "- Inactive for at least $($script:InactiveDays_NonInteractive) days (non-interactive logins)" -ForegroundColor Cyan }
}

Function Connect_MgGraph
{
 $MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta -ListAvailable
 if($null -eq $MsGraphBetaModule)
 { 
    Write-host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
    $confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
    if($confirm -match "[yY]") 
    { 
        Write-host "Installing Microsoft Graph Beta module..."
        Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
        Write-host "Microsoft Graph Beta module is installed in the machine successfully" -ForegroundColor Magenta 
    } 
    else
    { 
        Write-host "Exiting. `nNote: Microsoft Graph Beta module must be available in your system to run the script" -ForegroundColor Red
        Exit 
    } 
 }
 #Disconnect Existing MgGraph session
 if($CreateSession.IsPresent)
 {
  Disconnect-MgGraph
 }

 #Connecting to MgGraph beta
 Write-Host Connecting to Microsoft Graph...
 if(($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
 {  
  Connect-MgGraph  -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint 
 }
 else
 {
  Connect-MgGraph -Scopes "User.Read.All","AuditLog.read.All"  
 }
}
# Main script execution starts here
Get-UserMenuSelection

Connect_MgGraph
Write-Host "`nNote: If you encounter module related conflicts, run the script in a fresh PowerShell window."

$ExportCSV = ".\InactiveM365UserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult=""   
$ExportResults=[System.Collections.ArrayList]@()  

# Get friendly name of license plan from external file
$LicenseFriendlyNamePath = "C:\Users\User\Powershell scripts\LicenseFriendlyName.txt"
$FriendlyNameHash=Get-Content -Raw -Path $LicenseFriendlyNamePath -ErrorAction Stop | ConvertFrom-StringData

$Count=0
$PrintedUser=0
#retrieve users
$RequiredProperties=@('DisplayName','UserPrincipalName','EmployeeId','CreatedDateTime','AccountEnabled','Department','JobTitle','RefreshTokensValidFromDateTime','SigninActivity')
Get-MgBetaUser -All -Property $RequiredProperties | Select-Object $RequiredProperties | ForEach-Object {
 $Count++
 $DisplayName=$_.DisplayName
 $UPN=$_.UserPrincipalName
 Write-Progress -Activity "`n     Processing user: $Count - $UPN"
 $EmployeeId=$_.EmployeeId
 $LastInteractiveSignIn=$_.SignInActivity.LastSignInDateTime
 $LastNon_InteractiveSignIn=$_.SignInActivity.LastNonInteractiveSignInDateTime
 $CreatedDate=$_.CreatedDateTime
 $AccountEnabled=$_.AccountEnabled
 $Department=$_.Department
 $JobTitle=$_.JobTitle
 $RefreshTokenValidFrom=$_.RefreshTokensValidFromDateTime
 #Calculate Inactive days
 if($LastInteractiveSignIn -eq $null)
 {
  $LastInteractiveSignIn = "Never Logged In"
  $InactiveDays_InteractiveSignIn = "-"
 }
 else
 {
  $InactiveDays_InteractiveSignIn = (New-TimeSpan -Start $LastInteractiveSignIn).Days
 }
 if($LastNon_InteractiveSignIn -eq $null)
 {
  $LastNon_InteractiveSignIn = "Never Logged In"
  $InactiveDays_NonInteractiveSignIn = "-"
 }
 else
 {
  $InactiveDays_NonInteractiveSignIn = (New-TimeSpan -Start $LastNon_InteractiveSignIn).Days
 }
 if($AccountEnabled -eq $true)
 {
  $AccountStatus='Enabled'
 }
 else
 {
  $AccountStatus='Disabled'
 }

 #Get licenses assigned to mailboxes
 $Licenses = (Get-MgBetaUserLicenseDetail -UserId $UPN).SkuPartNumber
 $AssignedLicense = @()

 #Convert license plan to friendly name
 if($Licenses.count -eq 0)
 {
  $LicenseDetails = "No License Assigned"
 }
 else
 {
  foreach($License in $Licenses)
  {
   $EasyName = $FriendlyNameHash[$License]
   if(!($EasyName))
   {$NamePrint = $License}
   else
   {$NamePrint = $EasyName}
   $AssignedLicense += $NamePrint
  }
  $LicenseDetails = $AssignedLicense -join ", "
 }
 $Print=1


 #Inactive days based on interactive signins filter
 if($InactiveDays_InteractiveSignIn -ne "-")
 {
  if(($InactiveDays -ne "") -and ($InactiveDays -gt $InactiveDays_InteractiveSignIn))
  {
   $Print=0
  }
 }
    
 #Inactive days based on non-interactive signins filter
 if($InactiveDays_NonInteractiveSignIn -ne "-")
 {
  if(($InactiveDays_NonInteractive -ne "") -and ($InactiveDays_NonInteractive -gt $InactiveDays_NonInteractiveSignIn))
  {
   $Print=0
  }
 }

 #Never Logged In user
 if(($ReturnNeverLoggedInUser.IsPresent) -and ($LastInteractiveSignIn -ne "Never Logged In"))
 {
  $Print=0
 }

 #Filter for external users
 if(($ExternalUsersOnly.IsPresent) -and ($UPN -notmatch '#EXT#'))
 {
   $Print=0
 }
 
 #Signin Allowed Users
 if($EnabledUsersOnly.IsPresent -and $AccountStatus -eq 'Disabled')
 {      
  $Print=0
 }

 #Signin disabled users
 if($DisabledUsersOnly.IsPresent -and $AccountStatus -eq 'Enabled')
 {
  $Print=0
 }

 #Licensed Users ony
 if($LicensedUsersOnly -and $Licenses.Count -eq 0)
 {
  $Print=0
 }

 #Export users to output file
 if($Print -eq 1)
 {
  $PrintedUser++
  $ExportResult=[PSCustomObject]@{'Display Name'=$DisplayName;'UPN'=$UPN;'Creation Date'=$CreatedDate;'Last Interactive SignIn Date'=$LastInteractiveSignIn;'Last Non Interactive SignIn Date'=$LastNon_InteractiveSignIn;'Inactive Days(Interactive SignIn)'=$InactiveDays_InteractiveSignIn;'Inactive Days(Non-Interactive Signin)'=$InactiveDays_NonInteractiveSignin;'Refresh Token Valid From'=$RefreshTokenValidFrom;'Emp id'=$EmployeeId;'License Details'=$LicenseDetails;'Account Status'=$AccountStatus;'Department'=$Department;'Job Title'=$JobTitle}
  $ExportResults.Add($ExportResult) | Out-Null
 }
}

# Create UTF-8 encoding without BOM for subsequent writes
$utf8NoBOM = New-Object System.Text.UTF8Encoding $false

# First write header with BOM
$headerRow = 'Display Name,"UPN","Creation Date","Last Interactive SignIn Date","Last Non Interactive SignIn Date","Inactive Days(Interactive SignIn)","Inactive Days(Non-Interactive Signin)","Refresh Token Valid From","Emp id","License Details","Account Status","Department","Job Title"'
[System.IO.File]::WriteAllText($ExportCSV, [char]0xFEFF + $headerRow + "`r`n", [System.Text.Encoding]::UTF8)

# Then append each data row without BOM
$ExportResults | ForEach-Object {
    $line = ($_ | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1) -join ""
    [System.IO.File]::AppendAllText($ExportCSV, $line + "`r`n", $utf8NoBOM)
}

#Open output file after execution
Write-Host `nScript executed successfully.
if((Test-Path -Path $ExportCSV) -eq "True")
{
    Write-Host "Exported report has $PrintedUser user(s)." 
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?",` 0,"Open Output File",4)
    if ($UserInput -eq 6)
    {
        Invoke-Item "$ExportCSV"
    }
    Write-Host "Detailed report available in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV"
}
else
{
    Write-Host "No user found" -ForegroundColor Red
}