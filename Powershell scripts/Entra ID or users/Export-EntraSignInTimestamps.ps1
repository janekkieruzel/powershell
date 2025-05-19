<#
.SYNOPSIS
Exports Last Interactive and Non-Interactive Sign-in timestamps for a specific list of Entra ID users.

.DESCRIPTION
This script connects to Microsoft Graph to retrieve specified users (from a hardcoded file list)
by filtering on their User Principal Name (UPN) and gets their sign-in activity, specifically
the 'LastSignInDateTime' (interactive) and 'LastNonInteractiveSignInDateTime'.
The results (UserPrincipalName, DisplayName, LastSignInDateTime, LastNonInteractiveSignInDateTime)
are exported to a hardcoded CSV file path.

.NOTES
Author: Gemini
Date: 2025-04-28
Requires: Microsoft.Graph PowerShell module (Install-Module Microsoft.Graph)
Permissions: User.Read.All, AuditLog.Read.All (Admin consent may be required)
Input File: Reads UPNs from "C:\Users\User\Downloads\users.txt" (one UPN per line).
Output File: Saves CSV report to "C:\Users\User\Downloads\raport.csv".

.EXAMPLE
.\Export-EntraSignInTimestamps.ps1
Reads UPNs from "C:\Users\User\Downloads\users.txt" and exports the sign-in data to "C:\Users\User\Downloads\raport.csv".
#>

#region Hardcoded File Paths
# Define the input and output file paths here
$UserListPath = "C:\Reports\users.txt"
$FilePath = "C:\Reports\sign_in_report.csv"
#endregion

#region Validate Input File
Write-Host "Using input user list: $UserListPath" -ForegroundColor Cyan
Write-Host "Using output CSV file: $FilePath" -ForegroundColor Cyan

if (-not (Test-Path -Path $UserListPath -PathType Leaf)) {
    Write-Error "User list file not found at '$UserListPath'."
    return
}
#endregion

#region Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
# Define required scopes
$Scopes = @("User.Read.All", "AuditLog.Read.All") # User.Read.All is needed for filtering and reading properties

try {
    # Attempt to connect. This will prompt for login if not already connected.
    Connect-MgGraph -Scopes $Scopes
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Error: $($_.Exception.Message)"
    return # Exit the script if connection fails
}
#endregion

#region Get Users and Sign-in Activity from List
Write-Host "Reading user list from $UserListPath..." -ForegroundColor Yellow
# Use try-catch for reading the file as well
try {
    $targetUsers = Get-Content -Path $UserListPath -ErrorAction Stop
}
catch {
     Write-Error "Failed to read user list file '$UserListPath'. Error: $($_.Exception.Message)"
     Disconnect-MgGraph # Disconnect before exiting
     return
}

$totalUsersInList = $targetUsers.Count
Write-Host "Found $totalUsersInList users in the list. Retrieving sign-in activity..." -ForegroundColor Yellow

$resultsData = @() # Array to store results
$usersProcessed = 0

# Loop through each UPN from the file
foreach ($upn in $targetUsers) {
    $usersProcessed++
    $upn = $upn.Trim() # Remove leading/trailing whitespace
    if ([string]::IsNullOrWhiteSpace($upn)) {
        Write-Warning "Skipping blank line in user list."
        continue # Skip empty lines
    }

    Write-Progress -Activity "Processing Users from List" -Status "Processing $upn ($usersProcessed/$totalUsersInList)" -PercentComplete (($usersProcessed / $totalUsersInList) * 100)

    try {
        # *** MODIFIED LINE: Use -Filter instead of -UserId ***
        # Filter for the user by their UserPrincipalName
        # Note: Using -Top 1 because the filter should ideally return only one user, but Graph might return an array.
        $user = Get-MgUser -Filter "UserPrincipalName eq '$upn'" -Property 'Id', 'UserPrincipalName', 'DisplayName', 'SignInActivity' -Top 1 -ErrorAction Stop

        # Check if a user was actually found (Get-MgUser with -Filter might return $null or empty if not found, without throwing an error sometimes)
        if ($user) {
            # Create a custom object with the desired properties
            $userData = [PSCustomObject]@{
                UserPrincipalName             = $user.UserPrincipalName
                DisplayName                   = $user.DisplayName
                # Access the sign-in activity properties. These might be $null if no recent activity.
                LastSignInDateTime            = $user.SignInActivity.LastSignInDateTime
                LastNonInteractiveSignInDateTime = $user.SignInActivity.LastNonInteractiveSignInDateTime
            }
            # Add the user data to our results array
            $resultsData += $userData
        }
        else {
             # Handle case where filter returns nothing (user not found)
             Write-Warning "User '$upn' not found in Entra ID using filter. Skipping."
        }
    }
    catch { # Catch any error during Get-MgUser or processing
         # Check if the error is a Graph API error and specifically 'NotFound' (might still happen with filters in some cases, or other errors)
         $isNotFoundError = $false
         # Check if the error indicates a general request failure or specific status code
         if ($null -ne $_.Exception -and $null -ne $_.Exception.Response) {
             try {
                 # Enclose in try-catch as StatusCode might not always be present
                 if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
                     $isNotFoundError = $true
                 }
             } catch {
                 # Ignore errors trying to access StatusCode if it doesn't exist
             }
         }

         if ($isNotFoundError) {
              Write-Warning "User '$upn' not found in Entra ID (API Error). Skipping."
         } else {
             # Handle other errors
             $errorMessage = if ($null -ne $_.Exception) { $_.Exception.Message } else { $_.ToString() }
             # Check for common permission errors
             if ($errorMessage -like '*Authorization_RequestDenied*' -or $errorMessage -like '*Insufficient privileges*') {
                Write-Warning "Permission error retrieving data for '$upn'. Ensure the account running the script has User.Read.All and AuditLog.Read.All permissions. Error: $errorMessage Skipping user."
             }
             else {
                Write-Warning "An error occurred while retrieving data for user '$upn'. Error: $errorMessage Skipping."
             }
         }
    }
} # End foreach user UPN

Write-Host "Finished processing sign-in data for users from the list." -ForegroundColor Green
#endregion

#region Export to CSV
if ($resultsData.Count -gt 0) {
    Write-Host "Exporting data for $($resultsData.Count) found users to $FilePath..." -ForegroundColor Yellow
    try {
        # Export the collected data to the specified CSV file
        $resultsData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        Write-Host "Successfully exported data to $FilePath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to export data to CSV. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "No data collected for the users found in the list '$UserListPath'. Check if the UPNs are correct and if users exist/were found."
}
#endregion

#region Disconnect from Microsoft Graph
Write-Host "Disconnecting from Microsoft Graph..."
Disconnect-MgGraph
#endregion

Write-Host "Script finished." -ForegroundColor Cyan
