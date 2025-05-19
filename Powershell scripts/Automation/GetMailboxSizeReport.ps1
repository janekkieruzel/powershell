Param
(
    [Parameter(Mandatory = $false)]
    [switch]$SharedMBOnly,
    [switch]$UserMBOnly,
    [string]$MBNamesFile,
    [string]$UserName,
    [SecureString]$Password,
    [string]$Organization,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [int]$TestLimit = 0
)

# Modified Get_MailboxSize function
Function Get_MailboxSize {
    try {
        $Stats = Get-MailboxStatistics -Identity $UPN -ErrorAction Stop
        $ItemCount = $Stats.ItemCount
        $TotalItemSizeObject = $Stats.TotalItemSize
        $DeletedItemCount = $Stats.DeletedItemCount
        
        # Get archive size if archive is enabled
        $ArchiveSize = 0
        if ($ArchiveStatus -eq "Active") {
            try {
                $ArchiveStats = Get-MailboxStatistics -Identity $UPN -Archive -ErrorAction Stop
                if ($ArchiveStats.TotalItemSize -match "([0-9,.]+)\s*(B|KB|MB|GB|TB)") {
                    $archSize = [double]($matches[1] -replace ',', '')
                    $archUnit = $matches[2]
                    
                    # Convert archive size to GB
                    switch($archUnit) {
                        "B"  { $archSize = $archSize / 1GB }
                        "KB" { $archSize = $archSize / 1MB }
                        "MB" { $archSize = $archSize / 1024 }
                        "TB" { $archSize = $archSize * 1024 }
                    }
                    $ArchiveSize = [math]::Round($archSize, 2)
                }
            }
            catch {
                Write-Warning "Could not get archive statistics for $UPN : $($_.Exception.Message)"
            }
        }
        
        # Extract mailbox size value and convert to GB
        if ($TotalItemSizeObject.Value -match "([0-9,.]+)\s*(B|KB|MB|GB|TB)") {
            $size = [double]($matches[1] -replace ',', '')
            $unit = $matches[2]
            
            # Convert all sizes to GB
            switch($unit) {
                "B"  { $size = $size / 1GB }
                "KB" { $size = $size / 1MB }
                "MB" { $size = $size / 1024 }
                "TB" { $size = $size * 1024 }
            }
            $TotalSize = [math]::Round($size, 2)  # Store as numeric value
        }
        else {
            $TotalSize = 0
        }

        # Create ordered hashtable with simplified columns
        $Result = [ordered]@{
            'Display Name' = $DisplayName
            'User Principal Name' = $UPN
            'Mailbox Type' = $MailboxType
            'Retention Policy' = $RetentionPolicy
            'Archive Status' = $ArchiveStatus
            'Mailbox Size(GB)' = $TotalSize
            'Archive Size(GB)' = $ArchiveSize
            'Item Count' = [int]$ItemCount
            'Deleted Item Count' = [int]$DeletedItemCount
            'Issue Warning Quota(GB)' = $IssueWarningQuota -replace ' GB',''
            'Prohibit Send Quota(GB)' = $ProhibitSendQuota -replace ' GB',''
            'Prohibit Send Receive Quota(GB)' = $ProhibitSendReceiveQuota -replace ' GB',''
        }
        
        $Results.Add([PSCustomObject]$Result)
        
    } catch {
        Write-Warning "Failed to get statistics for $UPN : $($_.Exception.Message)"
    }
}

Function Show-Menu {
    Clear-Host
    Write-Host "=== Mailbox Size Report Options ==="
    Write-Host "1. Scan All Mailboxes"
    Write-Host "2. User Mailboxes Only"
    Write-Host "3. Shared Mailboxes Only"
    Write-Host "4. Test Run (5 Mailboxes)"
    Write-Host "Q: Quit"
    Write-Host
}

Function main {
    #Check for EXO module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if($Module.count -eq 0) 
    { 
        Write-Host Exchange Online PowerShell module is not available  -ForegroundColor yellow  
        $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
        if($Confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
            Import-Module ExchangeOnlineManagement
        } 
        else 
        { 
            Write-Host EXO module is required to connect Exchange Online.Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
            Exit
        }
    } 

    # Show menu and get user choice
    do {
        Show-Menu
        $choice = Read-Host "Please choose an option"
        
        switch ($choice) {
            '1' { 
                $SharedMBOnly = $false
                $UserMBOnly = $false
                $TestLimit = 0
                break
            }
            '2' { 
                $SharedMBOnly = $false
                $UserMBOnly = $true
                $TestLimit = 0
                break
            }
            '3' { 
                $SharedMBOnly = $true
                $UserMBOnly = $false
                $TestLimit = 0
                break
            }
            '4' { 
                $SharedMBOnly = $false
                $UserMBOnly = $false
                $TestLimit = 5
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
    } while ($choice -notin '1','2','3','4','Q')

    Write-Host "Connecting to Exchange Online..."

    try {
        # Storing credential in script for scheduling purpose/ Passing credential as parameter
        if (($UserName -ne "") -and ($null -ne $Password)) {
            $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
            $Credential = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
            Connect-ExchangeOnline -Credential $Credential
        }
        elseif ($Organization -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "") {
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
        }
        else {
            Connect-ExchangeOnline -ShowBanner:$false
        }
    }
    catch {
        Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
        exit
    }

    #Output file declaration 
    $timestamp = Get-Date -format "yyyy-MMM-dd hh-mm tt"
    $filename = "MailboxSizeReport_$timestamp.csv"
    $ExportCSV = Join-Path $PWD $filename

    # Initialize Results as ArrayList for better performance
    $Results = [System.Collections.ArrayList]@()
    $MBCount=0
    $PrintedMBCount=0
    Write-Host Generating mailbox size report...
    
    #Check for input file
    if([string]$MBNamesFile -ne "") 
    { 
        #We have an input file, read it into memory 
        $Mailboxes=@()
        $Mailboxes=Import-Csv -Header "MBIdentity" $MBNamesFile
        foreach($item in $Mailboxes)
        {
            $MBDetails=Get-Mailbox -Identity $item.MBIdentity
            $UPN=$MBDetails.UserPrincipalName  
            $MailboxType=$MBDetails.RecipientTypeDetails
            $DisplayName=$MBDetails.DisplayName
            $PrimarySMTPAddress=$MBDetails.PrimarySMTPAddress
            $IssueWarningQuota=$MBDetails.IssueWarningQuota -replace "\(.*",""
            $ProhibitSendQuota=$MBDetails.ProhibitSendQuota -replace "\(.*",""
            $ProhibitSendReceiveQuota=$MBDetails.ProhibitSendReceiveQuota -replace "\(.*",""
            $RetentionPolicy=$MBDetails.RetentionPolicy
            #Check for archive enabled mailbox
            if(($null -eq $MBDetails.ArchiveDatabase) -and ($MBDetails.ArchiveDatabaseGuid -eq $MBDetails.ArchiveGuid))
            {
                $ArchiveStatus = "Disabled"
            }
            else
            {
                $ArchiveStatus= "Active"
            }
            $MBCount++
            Write-Progress -Activity "`n     Processed mailbox count: $MBCount "`n"  Currently Processing: $DisplayName"
            Get_MailboxSize
            $PrintedMBCount++
        }
    }

    #Get all mailboxes from Office 365
    else
    {
        $mailboxes = Get-Mailbox -ResultSize Unlimited
        if($TestLimit -gt 0) {
            $mailboxes = $mailboxes | Select-Object -First $TestLimit
        }
        
        $mailboxes | ForEach-Object {
            $UPN=$_.UserPrincipalName
            $Mailboxtype=$_.RecipientTypeDetails
            $DisplayName=$_.DisplayName
            $PrimarySMTPAddress=$_.PrimarySMTPAddress
            $IssueWarningQuota=$_.IssueWarningQuota -replace "\(.*",""
            $ProhibitSendQuota=$_.ProhibitSendQuota -replace "\(.*",""
            $ProhibitSendReceiveQuota=$_.ProhibitSendReceiveQuota -replace "\(.*",""
            $RetentionPolicy=$_.RetentionPolicy
            $MBCount++
            Write-Progress -Activity "`n     Processed mailbox count: $MBCount "`n"  Currently Processing: $DisplayName"
            if($SharedMBOnly.IsPresent -and ($Mailboxtype -ne "SharedMailbox"))
            {
                return
            }
            if($UserMBOnly.IsPresent -and ($MailboxType -ne "UserMailbox"))
            {
                return
            }  
            #Check for archive enabled mailbox
            if(($null -eq $_.ArchiveDatabase) -and ($_.ArchiveDatabaseGuid -eq $_.ArchiveGuid))
            {
                $ArchiveStatus = "Disabled"
            }
            else
            {
                $ArchiveStatus= "Active"
            }
            Get_MailboxSize
            $PrintedMBCount++
        }
    }

    # Export results with proper UTF-8 encoding
    # Create UTF-8 encoding without BOM for subsequent writes
    $utf8NoBOM = New-Object System.Text.UTF8Encoding $false

    # First write header with BOM
    [System.IO.File]::WriteAllText($ExportCSV, [char]0xFEFF + 'Display Name,"User Principal Name","Mailbox Type","Retention Policy","Archive Status","Mailbox Size(GB)","Archive Size(GB)","Item Count","Deleted Item Count","Issue Warning Quota(GB)","Prohibit Send Quota(GB)","Prohibit Send Receive Quota(GB)"' + "`r`n", [System.Text.Encoding]::UTF8)

    # Then append the data without BOM
    $Results | ForEach-Object {
        $line = ($_ | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1) -join ""
        [System.IO.File]::AppendAllText($ExportCSV, $line + "`r`n", $utf8NoBOM)
    }

    #Open output file after execution 
    If($PrintedMBCount -eq 0) {
        Write-Host No mailbox found
    }
    else {
        Write-Host `nThe output file contains $PrintedMBCount mailboxes.
        if((Test-Path -Path $ExportCSV) -eq "True") {
            Write-Host ``n The Output file available in: -NoNewline -ForegroundColor Yellow
            Write-Host $ExportCSV 
            $Prompt = New-Object -ComObject wscript.shell      
            $UserInput = $Prompt.popup("Do you want to open output file?",` 0,"Open Output File",4)   
            If ($UserInput -eq 6) {   
                Invoke-Item "$ExportCSV"   
            }
        }
    }

    #Disconnect Exchange Online session
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
} # End of main function

# Call the main function to start the script
. main
