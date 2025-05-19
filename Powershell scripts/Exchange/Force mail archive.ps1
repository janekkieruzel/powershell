#Connect-ExchangeOnline
#Start-ManagedFolderAssistant -Identity "user1@example.com"
#Get-Mailbox "user1@example.com" | Format-List *HoldEnabled*
# Connect to Exchange Online PowerShell first
# Ensure you are connected to Exchange Online PowerShell first

#$mailboxIdentity = "user2@example.com"
#Get-MailboxFolder -Identity $mailboxIdentity -Recurse | Select-Object Name, FolderPath, PolicyTag, ArchivePolicyTag | Format-Table -AutoSize
# --- Get identifiers for one user ---
$IdentityToTest = "user1@example.com"
Write-Host "Getting identifiers for $IdentityToTest"
$recipient = Get-Recipient -Identity $IdentityToTest

if ($recipient) {
    $dn = $recipient.DistinguishedName
    $guid = $recipient.ExchangeGuid
    Write-Host "Found DN: $dn"
    Write-Host "Found GUID: $guid"

    # --- Try Get-Mailbox with specific identifiers ---
    Write-Host "`nAttempting Get-Mailbox with Distinguished Name..."
    try {
        Get-Mailbox -Identity $dn -ErrorAction Stop | Select-Object Name, PrimarySmtpAddress, RecipientTypeDisplay, RetentionPolicy
    } catch {
        Write-Host "Get-Mailbox failed with DN: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`nAttempting Get-Mailbox with ExchangeGuid..."
    try {
        Get-Mailbox -Identity $guid -ErrorAction Stop | Select-Object Name, PrimarySmtpAddress, RecipientTypeDisplay, RetentionPolicy
    } catch {
        Write-Host "Get-Mailbox failed with GUID: $($_.Exception.Message)" -ForegroundColor Red
    }

} else {
    Write-Host "Get-Recipient failed to find $IdentityToTest" -ForegroundColor Red
}