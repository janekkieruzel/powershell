# Set the admin user and output file path
#$AdminUser = "admin@example.com"
$OutputFilePath = "C:\Reports\AllUsersGroupAndForwardingReport.csv"

# Prompt user for scan type
$scanType = Read-Host "Do you want to scan a specific user? (Y/N)"
$targetUser = $null
if ($scanType.ToUpper() -eq 'Y') {
    $targetUser = Read-Host "Enter user's email address"
}

# Connect to Exchange Online (uncomment if needed)
# Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline #-UserPrincipalName $AdminUser -ShowBanner:$false

Write-Output "Collecting mailboxes..."
if ($targetUser) {
    $AllMailboxes = Get-Mailbox -Identity $targetUser -ErrorAction Stop
    if (-not $AllMailboxes) {
        Write-Error "User not found!"
        exit
    }
} else {
    $AllMailboxes = Get-Mailbox -ResultSize Unlimited
}

Write-Output "Collecting distribution groups and their members..."
$AllDistributionGroups = Get-DistributionGroup -ResultSize Unlimited
$AllDistributionGroupMembers = @()

foreach($distro in $AllDistributionGroups) {
    $members = Get-DistributionGroupMember -Identity $distro.Identity -ResultSize Unlimited
    foreach($member in $members) {
        $AllDistributionGroupMembers += [pscustomobject]@{
            GroupType   = "Distribution Group"
            # Remove trailing numbers from GroupName
            GroupName   = ($distro.Name -replace '\d+$', '')
            MemberName  = $member.DisplayName
            MemberEmail = $member.PrimarySmtpAddress
            MemberGuid  = $member.ExternalDirectoryObjectId
        }
    }
}

Write-Output "Collecting Microsoft 365 groups and their members..."
$AllM365Groups = Get-UnifiedGroup -ResultSize Unlimited
$AllM365GroupMembers = @()

foreach($m365Group in $AllM365Groups) {
    $m365Members = Get-UnifiedGroupLinks -Identity $m365Group.Identity -LinkType Members
    foreach($member in $m365Members) {
        $AllM365GroupMembers += [pscustomobject]@{
            GroupType   = "Microsoft 365 Group"
            # Remove trailing numbers from GroupName
            GroupName   = ($m365Group.DisplayName -replace '\d+$', '')
            MemberName  = $member.Name
            MemberEmail = $member.PrimarySmtpAddress
            MemberGuid  = $member.ExternalDirectoryObjectId
        }
    }
}

Write-Output "Collecting forwarding settings for all users..."
$ForwardingUsers = Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, PrimarySmtpAddress, ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward, Guid

$Results = @()

Write-Output "Analyzing each mailbox..."
foreach ($Mailbox in $AllMailboxes) {
    $MailboxEmail = $Mailbox.PrimarySmtpAddress.ToLower()
    $MailboxGuid = $Mailbox.Guid

    # Get all SMTP aliases of the mailbox (including primary)
    $SmtpAliases = ($Mailbox.EmailAddresses | Where-Object {$_ -like "SMTP:*"} | ForEach-Object { $_.ToString().TrimStart("SMTP:").ToLower() })

    # Check Distribution Group memberships by alias or GUID
    $UserDistroGroups = $AllDistributionGroupMembers | Where-Object {
        (
            $SmtpAliases -contains $_.MemberEmail.ToLower()
        ) -or (
            $_.MemberGuid -eq $MailboxGuid
        )
    }

    foreach ($dg in $UserDistroGroups) {
        $Results += [pscustomobject]@{
            TargetUser          = $Mailbox.DisplayName
            TargetUserEmail     = $MailboxEmail
            GroupType           = $dg.GroupType
            GroupName           = $dg.GroupName
            RelatedUserOrGroup  = $dg.MemberName
            RelatedEmailAddress = $dg.MemberEmail
            ForwardingAddress   = $null
            DeliverToMailbox    = $null
            ForwardingType      = $null
        }
    }

    # Check Microsoft 365 Group memberships by alias or GUID
    $UserM365Groups = $AllM365GroupMembers | Where-Object {
        ($SmtpAliases -contains $_.MemberEmail.ToLower()) -or ($_.MemberGuid -eq $MailboxGuid)
    }

    foreach ($m365 in $UserM365Groups) {
        $Results += [pscustomobject]@{
            TargetUser          = $Mailbox.DisplayName
            TargetUserEmail     = $MailboxEmail
            GroupType           = $m365.GroupType
            GroupName           = $m365.GroupName
            RelatedUserOrGroup  = $m365.MemberName
            RelatedEmailAddress = $m365.MemberEmail
            ForwardingAddress   = $null
            DeliverToMailbox    = $null
            ForwardingType      = $null
        }
    }

    # Check who is forwarding to this mailbox by alias or GUID
    $ForwardMatches = $ForwardingUsers | ForEach-Object {
        $user = $_

        # Handle external forwarding
        $externalForward = $null
        if ($user.ForwardingSmtpAddress) {
            $externalForward = $user.ForwardingSmtpAddress.ToString().TrimStart("smtp:").ToLower()
        }

        # Resolve internal forwarding if present
        $internalForwardMailbox = $null
        if ($user.ForwardingAddress) {
            $internalForwardMailbox = Get-Recipient -Identity $user.ForwardingAddress -ErrorAction SilentlyContinue
        }

        # Check external match: if external forwarding address matches current mailbox aliases
        $externalMatch = $externalForward -and ($SmtpAliases -contains $externalForward)

        # Check internal match: if internal forwarding mailbox GUID or SMTP matches the current mailbox
        $internalMatch = $false
        if ($internalForwardMailbox) {
            $forwardMailboxGuid = $internalForwardMailbox.Guid
            $forwardMailboxEmail = $internalForwardMailbox.PrimarySmtpAddress.ToLower()
            $internalMatch = ($forwardMailboxGuid -eq $MailboxGuid) -or ($SmtpAliases -contains $forwardMailboxEmail)
        }

        if ($externalMatch -or $internalMatch) {
            $forwardingAddress = $externalForward
            $forwardingType = "SMTP Address"

            if ($internalMatch -and $internalForwardMailbox) {
                $forwardingAddress = $internalForwardMailbox.PrimarySmtpAddress.ToLower()
                $forwardingType = "Internal Mailbox"
            }

            # Return the object from the if block
            [pscustomobject]@{
                TargetUser          = $Mailbox.DisplayName
                TargetUserEmail     = $MailboxEmail
                GroupType           = "Forwarding User"
                GroupName           = "N/A"
                RelatedUserOrGroup  = $user.DisplayName
                RelatedEmailAddress = $user.PrimarySmtpAddress
                ForwardingAddress   = $forwardingAddress
                DeliverToMailbox    = $user.DeliverToMailboxAndForward
                ForwardingType      = $forwardingType
            }
        } # End of if ($externalMatch -or $internalMatch)
    } # End of ForEach-Object

    if ($ForwardMatches) {
        $Results += $ForwardMatches
    }
}

Write-Output "Exporting results to CSV..."

# Modify the output file name to include user info
if ($targetUser) {
    $OutputFilePath = $OutputFilePath.Replace(".csv", "_${targetUser}.csv")
}

# Export the results to a CSV file with UTF-8 BOM
$tempPath = "$env:TEMP\AllUsersGroupAndForwardingReport3.csv"
$Results | Export-Csv -Path $tempPath -NoTypeInformation -Force

Add-Type -AssemblyName "System.Text.Encoding"
$utf8WithBom = [System.Text.Encoding]::UTF8
$utf8WithBomFileContent = $utf8WithBom.GetPreamble() + [System.IO.File]::ReadAllBytes($tempPath)
[System.IO.File]::WriteAllBytes($OutputFilePath, $utf8WithBomFileContent)

Remove-Item -Path $tempPath -Force

Write-Output "CSV file created at $OutputFilePath"

# If you connected earlier, you can disconnect now
# Disconnect-ExchangeOnline -Confirm:$false
Write-Output "Script execution complete."
