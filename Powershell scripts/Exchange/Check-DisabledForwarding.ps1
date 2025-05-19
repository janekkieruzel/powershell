# Check-DisabledForwarding.ps1
# This script checks who disabled email forwarding for a specific user in Microsoft Exchange Online
# It searches the Unified Audit Log for Set-Mailbox operations that removed forwarding settings

# Connect to Exchange Online if not already connected
$exchangeSession = Get-PSSession | Where-Object {$_.ConfigurationName -eq "Microsoft.Exchange" -and $_.State -eq "Opened"}
if ($null -eq $exchangeSession) {
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
    try {
        Connect-ExchangeOnline -ErrorAction Stop
        Write-Host "Successfully connected to Exchange Online." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to connect to Exchange Online. Error: $_" -ForegroundColor Red
        exit
    }
}

# Define parameters
$userEmailAddress = "user1@example.com" # Placeholder email
$startDate = (Get-Date).AddDays(-7) # Search last 7 days (adjust as needed)
$endDate = Get-Date
$operations = "Set-Mailbox"

Write-Host "Searching audit logs for disabled forwarding for user: $userEmailAddress" -ForegroundColor Cyan
Write-Host "Timeframe: $startDate to $endDate" -ForegroundColor Cyan
Write-Host "This might take some time depending on the amount of audit data..." -ForegroundColor Yellow

# Search patterns for forwarding being disabled
$forwardingDisabledPatterns = @(
    '*"ForwardingSmtpAddress":null*',
    '*"ForwardingSmtpAddress":""*',
    '*"ForwardingAddress":null*',
    '*"ForwardingAddress":""*',
    '*"DeliverToMailboxAndForward":false*'
)

# Search the audit log
$results = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations $operations -ObjectIds $userEmailAddress -ResultSize 2000

# Filter for forwarding-related changes that indicate forwarding was disabled
$forwardingDisabledEvents = @()
foreach ($event in $results) {
    $auditData = $event.AuditData | ConvertFrom-Json
    
    # Check if any of the patterns for disabling forwarding are found
    foreach ($pattern in $forwardingDisabledPatterns) {
        if ($event.AuditData -like $pattern) {
            # Extract the important information
            $forwardingDisabledEvents += [PSCustomObject]@{
                'Date'                = $event.CreationDate
                'User Who Performed'  = $auditData.UserId
                'Action'              = $auditData.Operation
                'Target User'         = $userEmailAddress
                'Client IP'           = $auditData.ClientIP
                'Client Info'         = $auditData.ClientInfoString
                'Parameters'          = ($auditData.Parameters | ForEach-Object { "$($_.Name): $($_.Value)" }) -join '; '
                'AuditData'           = $event.AuditData
            }
            break  # Found a match, no need to check other patterns
        }
    }
}

# Display results
if ($forwardingDisabledEvents.Count -gt 0) {
    Write-Host "Found $($forwardingDisabledEvents.Count) events where forwarding was disabled:" -ForegroundColor Green
    $forwardingDisabledEvents | Format-Table Date, 'User Who Performed', Action, 'Target User', 'Client IP' -AutoSize
    
    # Export to CSV
    $csvPath = "$PSScriptRoot\ForwardingDisabledEvents_$(Get-Date -Format 'yyyy-MMM-dd-HH-mm-ss').csv"
    $forwardingDisabledEvents | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results exported to: $csvPath" -ForegroundColor Green
    
    # Show detailed information for each event
    Write-Host "`nDetailed Information:" -ForegroundColor Cyan
    foreach ($event in $forwardingDisabledEvents) {
        Write-Host "`n----------------------------------------" -ForegroundColor Yellow
        Write-Host "Date: $($event.Date)" -ForegroundColor Yellow
        Write-Host "User Who Performed: $($event.'User Who Performed')" -ForegroundColor Yellow
        Write-Host "Parameters Changed: $($event.Parameters)" -ForegroundColor Gray
    }
} 
else {
    Write-Host "No events found where forwarding was disabled for $userEmailAddress in the specified time period." -ForegroundColor Red
    Write-Host "Try extending the search period by modifying the `$startDate variable." -ForegroundColor Yellow
}