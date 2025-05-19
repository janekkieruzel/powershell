#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Authentication

<#
.SYNOPSIS
Exports Job Title, Department, Display Name, and Manager UPN for users specified by UPN in an input file.
Targets Azure Active Directory / Microsoft Entra ID using Microsoft Graph.

.DESCRIPTION
Reads a list of User Principal Names (UPNs) from a text file, queries Microsoft Graph
for each user, and exports their Display Name, Job Title, Department, and Manager UPN to a CSV file.

.NOTES
- Requires the Microsoft.Graph.Users and Microsoft.Graph.Authentication PowerShell modules.
- You must connect to Graph first using Connect-MgGraph with appropriate permissions (e.g., User.Read.All).
- Ensure the input file contains one UPN per line.
#>

# --- Configuration ---
# Specify the path to your input text file (one UPN per line)
$inputFile = "C:\Reports\upn_list.txt" 
# Specify the path for the output CSV file
$outputFile = "C:\Reports\EntraID_UserDetails.csv" 
# --- End Configuration ---

# --- Connect to Microsoft Graph ---
# Define required permissions (scopes)
$requiredScopes = @("User.Read.All") 

# Check current connection state and scopes
$currentContext = Get-MgContext -ErrorAction SilentlyContinue
$connected = $false
if ($currentContext) {
    # Check if all required scopes are present in the current connection
    $grantedScopes = $currentContext.Scopes
    $missingScopes = $requiredScopes | Where-Object { $grantedScopes -notcontains $_ }
    if ($missingScopes.Count -eq 0) {
        Write-Host "Already connected to Microsoft Graph with required permissions." -ForegroundColor Cyan
        $connected = $true
    } else {
        Write-Warning "Connected to Microsoft Graph, but missing required scope(s): $($missingScopes -join ', ')"
        Write-Warning "Attempting to reconnect with required scopes..."
        Disconnect-MgGraph # Disconnect existing session if scopes are insufficient
    }
}

# Connect if not already connected with the right permissions
if (-not $connected) {
    Write-Host "Connecting to Microsoft Graph. Please authenticate in the browser." -ForegroundColor Yellow
    try {
        Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
        Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
        $connected = $true
    } catch {
        Write-Error "Failed to connect to Microsoft Graph. Error: $($_.Exception.Message)"
        Write-Error "Please ensure you have the necessary permissions and try again."
        # Exit the script if connection fails
        Exit
    }
}
# --- End Connect to Microsoft Graph ---

# Check if input file exists
if (-not (Test-Path $inputFile)) {
    Write-Error "Input file not found at '$inputFile'. Please check the path."
    # Exit the script if the file doesn't exist
    Exit
}

# Read UPNs from the input file
$upns = Get-Content -Path $inputFile

# Array to hold the results
$results = @()

Write-Host "Processing UPNs from '$inputFile'..."

# Loop through each UPN
foreach ($upn in $upns) {
    # Trim potential whitespace
    $trimmedUpn = $upn.Trim() 
    
    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($trimmedUpn)) {
        Write-Warning "Skipping empty line in input file."
        continue
    }
    
    Write-Host "Querying Graph for: $trimmedUpn"
    
    try {
        # Get the MgUser, selecting only the necessary properties for efficiency
        $mgUser = Get-MgUser -UserId $trimmedUpn -Property Id, DisplayName, JobTitle, Department -ErrorAction Stop
        
        # Try to get the manager's UPN (if any)
        $managerUpn = $null
        try {
            $manager = Get-MgUserManager -UserId $trimmedUpn -ErrorAction Stop
            if ($manager -and $manager.UserPrincipalName) {
                $managerUpn = $manager.UserPrincipalName
            } elseif ($manager -and $manager.AdditionalProperties["userPrincipalName"]) {
                $managerUpn = $manager.AdditionalProperties["userPrincipalName"]
            }
        } catch {
            $managerUpn = $null # No manager or error
        }

        if ($mgUser) {
            # Add user details to the results array
            $results += [PSCustomObject]@{
                UserPrincipalName = $trimmedUpn # Use the input UPN for consistency
                DisplayName       = $mgUser.DisplayName
                JobTitle          = $mgUser.JobTitle    # Graph attribute for Job Title
                Department        = $mgUser.Department
                ManagerUPN        = $managerUpn
                Status            = "Found"
            }
            Write-Host " -> Found: $($mgUser.DisplayName)"
        } else {
             # Should not happen with -ErrorAction Stop, but as a fallback
             Write-Warning " -> User not found: $trimmedUpn (Get-MgUser returned null)"
             $results += [PSCustomObject]@{
                UserPrincipalName = $trimmedUpn
                DisplayName       = "N/A"
                JobTitle          = "N/A"
                Department        = "N/A"
                ManagerUPN        = $null
                Status            = "Not Found"
            }
        }
    } catch {
        if ($_.Exception.Message -match 'Resource.*does not exist' -or $_.ErrorDetails.Message -match 'Resource.*does not exist') {
             Write-Warning " -> User not found: $trimmedUpn"
             $results += [PSCustomObject]@{
                UserPrincipalName = $trimmedUpn
                DisplayName       = "N/A"
                JobTitle          = "N/A"
                Department        = "N/A"
                ManagerUPN        = $null
                Status            = "Not Found"
            }
        } else {
             # Catch other Graph API errors
             Write-Error " -> Error querying user '$trimmedUpn': $($_.Exception.Message) - $($_.ErrorDetails.Message)"
             $results += [PSCustomObject]@{
                UserPrincipalName = $trimmedUpn
                DisplayName       = "Error"
                JobTitle          = "Error"
                Department        = "Error"
                ManagerUPN        = $null
                Status            = "Error: $($_.Exception.Message) - $($_.ErrorDetails.Message)"
            }
        }
    }
}

# Check if any results were collected
if ($results.Count -gt 0) {
    # Export the results to CSV
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8BOM
    Write-Host "--------------------------------------------------"
    Write-Host "Script finished. Results exported to '$outputFile'." -ForegroundColor Green
} else {
    Write-Warning "--------------------------------------------------"
    Write-Warning "Script finished, but no user data was collected. Check input file, permissions, and connection."
}

# Optional: Disconnect from Graph if you want to clean up the session
# Write-Host "Disconnecting from Microsoft Graph..."
# Disconnect-MgGraph