Connect-ExchangeOnline
# Define multiple mailbox-user pairs directly in code
# Each entry is a hashtable with 'Mailbox' and 'User' keys
$entries = @(
    @{ Mailbox = "user1@example.com"; User = "user2@example.com" }
    #@{ Mailbox = "service1@example.org"; User = "user3@example.org" },
    #@{ Mailbox = "service2@example.org"; User = "user3@example.org" }
    #@{ Mailbox = "new.mailbox@example.com"; User = "new.user@example.com" }
)

foreach ($entry in $entries) {
    $Mailbox = $entry.Mailbox
    $User    = $entry.User

    Write-Host "Checking permissions for mailbox: $Mailbox and user: $User..."

    # Check if the user already has FullAccess permission on this mailbox
    $existingPermissions = Get-MailboxPermission -Identity $Mailbox -User $User -ErrorAction SilentlyContinue |
                           Where-Object { $_.AccessRights -contains "FullAccess" }

    if ($null -eq $existingPermissions) {
        # User does not have FullAccess yet, so we add it
        Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -AutoMapping $false -ErrorAction Stop
        Write-Host "FullAccess permission has been granted to $User on $Mailbox."
    } else {
        # User already has FullAccess, so we skip applying again
        Write-Host "FullAccess permission already exists for $User on $Mailbox. Skipping..."
    }
}

Write-Host "Processing complete."
Disconnect-ExchangeOnline -Confirm:$false