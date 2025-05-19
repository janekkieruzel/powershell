Connect-ExchangeOnline

$AdminUser = "admin@example.com"

# Replace with the mailbox you want to forward from
$SourceMailbox = "user@example.com"

# Replace with the mailbox (or external SMTP) you want to forward to
$ForwardTo = "forwardinguser@example.com"

# Always keep a copy of forwarded emails in the source mailbox
$KeepCopy = $true

# Import the Exchange Online module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName $AdminUser

try {
    # Configure forwarding settings on the specified mailbox
    Set-Mailbox -Identity $SourceMailbox -ForwardingSmtpAddress $ForwardTo -DeliverToMailboxAndForward $KeepCopy
    
    Write-Host "Forwarding configured successfully:"
    Write-Host "From: $SourceMailbox"
    Write-Host "To: $ForwardTo"
    Write-Host "Keep Copy: $KeepCopy"
}
catch {
    Write-Host "Failed to set forwarding on $SourceMailbox. Error: $_"
}

# Disconnect the session
Disconnect-ExchangeOnline -Confirm:$false