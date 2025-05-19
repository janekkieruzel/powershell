# Script to enable archive mailboxes and assign retention policies
# Created: April 23, 2025

# Parameters - you can modify these values manually
$UsersToProcess = @(
    "user1@example.com",
    "user2@example.com"
)

$RetentionPolicyName = "Mail Archive 1 year - Junk 30 days - Deleted 90 days" # Enter the name of your retention policy here

# Function to check if we're connected to Exchange Online
function Test-ExchangeOnlineConnection {
    try {
        $null = Get-EXOMailbox -ResultSize 1 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to connect to Exchange Online if not already connected
function Connect-ToExchangeOnline {
    try {
        if (-not (Test-ExchangeOnlineConnection)) {
            Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
            Connect-ExchangeOnline -ErrorAction Stop
            Write-Host "Connected successfully to Exchange Online." -ForegroundColor Green
        }
        else {
            Write-Host "Already connected to Exchange Online." -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Host "Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to enable archive and set retention policy for a user
function Set-UserArchiveAndRetention {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$RetentionPolicy
    )
    
    try {
        # Check if the user exists
        $mailbox = Get-EXOMailbox -Identity $UserEmail -ErrorAction Stop
        
        # Check if archive needs to be enabled
        if (-not $mailbox.ArchiveStatus -or $mailbox.ArchiveStatus -eq "None") {
            Write-Host "Enabling archive for $UserEmail..." -ForegroundColor Yellow
            try {
                Enable-Mailbox -Identity $UserEmail -Archive -ErrorAction Stop
                Write-Host "Archive mailbox enabled successfully for $UserEmail." -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*already has an archive*") {
                    Write-Host "Archive mailbox is already enabled for $UserEmail." -ForegroundColor Yellow
                }
                else {
                    throw # Re-throw exception if it's not the "already has archive" error
                }
            }
        }
        else {
            Write-Host "Archive mailbox is already enabled for $UserEmail (Status: $($mailbox.ArchiveStatus))." -ForegroundColor Cyan
        }
        
        # Check current retention policy and update if needed
        $currentPolicy = $mailbox.RetentionPolicy
        if ($currentPolicy -eq "Default MRM Policy") {
            Write-Host "User $UserEmail has 'Default MRM Policy' assigned. Will replace with '$RetentionPolicy'." -ForegroundColor Yellow
        }
        elseif ($currentPolicy -eq $RetentionPolicy) {
            Write-Host "User $UserEmail already has the requested policy '$RetentionPolicy' assigned." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "User $UserEmail has a different policy assigned: '$currentPolicy'." -ForegroundColor Yellow
        }
        
        # Set retention policy
        Write-Host "Assigning retention policy '$RetentionPolicy' to $UserEmail..." -ForegroundColor Yellow
        Set-Mailbox -Identity $UserEmail -RetentionPolicy $RetentionPolicy -ErrorAction Stop
        Write-Host "Retention policy '$RetentionPolicy' assigned successfully." -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "Error processing user $UserEmail`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main script execution
$results = @{
    Successful = @()
    Failed = @()
}

# Validate inputs
if ($UsersToProcess.Count -eq 0) {
    Write-Host "No users specified. Please add users to the `$UsersToProcess array." -ForegroundColor Red
    exit
}

if ([string]::IsNullOrWhiteSpace($RetentionPolicyName)) {
    Write-Host "No retention policy specified. Please set the `$RetentionPolicyName variable." -ForegroundColor Red
    exit
}

# Connect to Exchange Online
if (-not (Connect-ToExchangeOnline)) {
    Write-Host "Script execution canceled due to connection failure." -ForegroundColor Red
    exit
}

# Process each user
foreach ($user in $UsersToProcess) {
    Write-Host "`nProcessing user: $user" -ForegroundColor Cyan
    
    $success = Set-UserArchiveAndRetention -UserEmail $user -RetentionPolicy $RetentionPolicyName
    
    if ($success) {
        $results.Successful += $user
    }
    else {
        $results.Failed += $user
    }
}

# Output summary
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total users processed: $($UsersToProcess.Count)" -ForegroundColor White
Write-Host "Successful: $($results.Successful.Count)" -ForegroundColor Green
Write-Host "Failed: $($results.Failed.Count)" -ForegroundColor $(if ($results.Failed.Count -gt 0) { "Red" } else { "Green" })

if ($results.Failed.Count -gt 0) {
    Write-Host "`nFailed users:" -ForegroundColor Red
    $results.Failed | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
}
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "`nScript completed at $(Get-Date)" -ForegroundColor Cyan