# Calculate the start time (30 days ago)
$startTime = (Get-Date).AddDays(-30)

# Calculate the end time (now)
$endTime = Get-Date

# Get the events
$events = Get-WinEvent -LogName Security | Where-Object {
    $_.Id -in 4624, 4634 -and $_.Properties[8].Value -eq 2 -and $_.TimeCreated -ge $startTime -and $_.TimeCreated -le $endTime
}

# Export the events to a CSV file:
$events | Export-Csv -Path "C:\Users\User\Downloads\security_events.csv" -NoTypeInformation

#Optional output to the console.
#$events | Format-List

Write-Host "Security events exported to C:\Users\User\Downloads\security_events.csv"