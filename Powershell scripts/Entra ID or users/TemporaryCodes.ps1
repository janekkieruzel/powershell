# If you haven't installed the Microsoft Graph module, uncomment this line:
# Install-Module Microsoft.Graph -Scope CurrentUser

# 1. Connect to Microsoft Graph with the required permissions.
Connect-MgGraph -Scopes "Policy.ReadWrite.AuthenticationMethod, Directory.ReadWrite.All"

# 2. Prepare output file path
$filePath = "C:\Reports\TempAccessPasses.csv"

# 3. List of user principal names (emails).
$users = @(
    "user1@example.com",
    "user2@example.com",
    "user3@example.com"
)

# 4. Create an empty array to store results before exporting to CSV.
$results = @()

# 5. Generate a TAP for each user, valid for 2 days (2880 minutes), store in $results.
foreach ($user in $users) {
    try {
        $tap = New-MgUserAuthenticationTemporaryAccessPassMethod `
            -UserId $user `
            -IsUsableOnce $false `
            -LifetimeInMinutes 2880

        # Add the result (email & code) to our $results collection
        $results += [pscustomobject]@{
            Email = $user
            TAP   = $tap.TemporaryAccessPass
        }

        Write-Host "User: $user -- TAP: $($tap.TemporaryAccessPass)"
    }
    catch {
        Write-Warning "Failed to create TAP for $user. Error: $_"
    }
}

# 6. Export the TAP list to a CSV file (overwrite if exists).
$results | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8

# 7. Disconnect from Microsoft Graph.
Disconnect-MgGraph

Write-Host "`nTemporary Access Passes saved to: $filePath"
Write-Host "Note: Creating TAPs does NOT log users out of existing sessions."
