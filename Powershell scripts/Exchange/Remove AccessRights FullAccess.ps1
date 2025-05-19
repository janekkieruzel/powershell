# Define multiple mailbox-user pairs directly in code
$entries = @(
    @{ Mailbox = "user1@example.com"; User = "user2@example.com" }
    # @{ Mailbox = "user3@example.com"; User = "user4@example.com" }
)

foreach ($entry in $entries) {
    $Mailbox = $entry.Mailbox
    $User    = $entry.User

    Write-Host "Checking permissions for mailbox: $Mailbox and user: $User..."

    # Check if the user already has FullAccess permission on this mailbox
    $existingPermissions = Get-MailboxPermission -Identity $Mailbox -User $User -ErrorAction SilentlyContinue |
                           Where-Object { $_.AccessRights -contains "FullAccess" }

    if ($existingPermissions) {
        # User currently has FullAccess; remove it
        Remove-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -Confirm:$false
        Write-Host "FullAccess permission removed for $User on $Mailbox."
    } else {
        # User does not have FullAccess, so no need to remove anything
        Write-Host "$User does not have FullAccess on $Mailbox. Skipping..."
    }
}

Write-Host "Processing complete."
