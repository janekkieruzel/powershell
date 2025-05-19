<#
.SYNOPSIS
Removes a specified user from all Microsoft 365 Groups, Distribution Lists,
and Security Groups they are directly a member of.

.DESCRIPTION
This script uses the Microsoft Graph PowerShell SDK to find all group
memberships for a given user principal name (UPN) and then attempts
to remove the user from each of those groups.

.PARAMETER UserPrincipalName
The email address (User Principal Name) of the user to remove from groups.

.EXAMPLE
.\Remove-UserFromAllGroups.ps1 -UserPrincipalName "user@example.com"

.NOTES
- Requires the Microsoft.Graph PowerShell module. Install with:
  Install-Module Microsoft.Graph -Scope CurrentUser
- Requires appropriate administrative permissions (e.g., Groups Administrator,
  User Administrator, Global Administrator).
- This action is potentially disruptive and irreversible for direct memberships.
- Does not affect dynamic group memberships directly.
- Ensure you are logged into the correct tenant when prompted by Connect-MgGraph.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName
)

#region Connect and Verify User
Write-Host "Attempting to connect to Microsoft Graph..." -ForegroundColor Cyan

# Define required permissions scopes
# User.Read.All: To find the user object by UPN.
# GroupMember.ReadWrite.All: To read group memberships and remove members.
# Group.Read.All: To get group display names for better logging.
$requiredScopes = @("User.Read.All", "GroupMember.ReadWrite.All", "Group.Read.All")

# Connect to Microsoft Graph - Will prompt for login if not already connected
# Using -NoWelcome suppresses the welcome message
try {
    Connect-MgGraph -Scopes $requiredScopes -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Please ensure the module is installed and you have internet connectivity. Error: $_"
    return # Exit script if connection fails
}

# Add Exchange Online connection
Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
try {
    Connect-ExchangeOnline -ShowBanner:$false
    Write-Host "Successfully connected to Exchange Online." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Exchange Online. Error: $_"
    Disconnect-MgGraph
    return
}

# Get the User Object ID - necessary for removal operations
Write-Host "Verifying user '$UserPrincipalName' and retrieving Object ID..."
try {
    $userObject = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop -Select Id, UserPrincipalName, DisplayName
    $userId = $userObject.Id
    Write-Host "Found user '$($userObject.DisplayName)' (ID: $userId)." -ForegroundColor Green
} catch {
    Write-Error "Failed to find user '$UserPrincipalName'. Please check the UPN. Error: $_"
    Disconnect-MgGraph # Disconnect before exiting
    return # Exit script if user not found
}
#endregion

#region Get Group Memberships
Write-Host "Retrieving group memberships for '$($userObject.DisplayName)'..."
try {
    # Get-MgUserMemberOf returns directoryObject objects representing groups. The ID is the group's ID.
    # Use -All to handle potential pagination if the user is in many groups.
    $groupMemberships = Get-MgUserMemberOf -UserId $userId -All -ErrorAction Stop
    $groupCount = $groupMemberships.Count
    Write-Host "User is a member of $groupCount group(s)." -ForegroundColor Yellow
} catch {
    Write-Error "Failed to retrieve group memberships for '$UserPrincipalName'. Error: $_"
    Disconnect-MgGraph
    return # Exit script on error
}
#endregion

#region Remove User from Groups
if ($groupCount -gt 0) {
    Write-Host "Starting removal process..." -ForegroundColor Cyan
    $graphSuccessCount = 0
    $exchangeSuccessCount = 0
    $failCount = 0

    foreach ($groupMembership in $groupMemberships) {
        $groupId = $groupMembership.Id
        $groupDisplayName = "<Fetching Name...>" # Placeholder

        # Attempt to get group display name for better logging
        try {
            $groupDetail = Get-MgGroup -GroupId $groupId -ErrorAction SilentlyContinue -Select DisplayName
            if ($groupDetail) {
                $groupDisplayName = $groupDetail.DisplayName
            } else {
                 $groupDisplayName = "<Name Unavailable or Group Hidden>"
            }
        } catch {
             $groupDisplayName = "<Error fetching name>"
        }

        Write-Host "Attempting to remove user from group '$groupDisplayName' (ID: $groupId)..."

        try {
            # Try Graph API first
            Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $userId -ErrorAction Stop
            Write-Host "Successfully removed user from '$groupDisplayName' using Graph API." -ForegroundColor Green
            $graphSuccessCount++
        } catch {
            if ($_.Exception.Message -like "*Cannot Update a mail-enabled security groups and or distribution list*") {
                Write-Warning "Group '$groupDisplayName' is a mail-enabled group. Attempting removal via Exchange Online..."
                try {
                    Remove-DistributionGroupMember -Identity $groupId -Member $UserPrincipalName -Confirm:$false -ErrorAction Stop
                    Write-Host "Successfully removed user from '$groupDisplayName' using Exchange Online." -ForegroundColor Green
                    $exchangeSuccessCount++
                } catch {
                    Write-Warning "FAILED to remove user from '$groupDisplayName' using Exchange Online. Error: $_"
                    $failCount++
                }
            } else {
                Write-Warning "FAILED to remove user from group '$groupDisplayName' (ID: $groupId). Error: $_"
                $failCount++
            }
        }
    }

    Write-Host "`nRemoval process finished." -ForegroundColor Cyan
    Write-Host "Successfully removed using Graph API: $graphSuccessCount group(s)" -ForegroundColor Green
    Write-Host "Successfully removed using Exchange Online: $exchangeSuccessCount group(s)" -ForegroundColor Green
    Write-Host "Failed to remove from: $failCount group(s)" -ForegroundColor Yellow
    
    if ($failCount -gt 0) {
        Write-Warning "Review any failure messages above. Manual removal might be required for failed groups."
    }

} else {
    Write-Host "User '$($userObject.DisplayName)' was not found to be a member of any groups requiring removal." -ForegroundColor Green
}
#endregion

#region Disconnect
Write-Host "`nDisconnecting from services..."
Disconnect-MgGraph
Disconnect-ExchangeOnline -Confirm:$false
#endregion

Write-Host "Script finished."