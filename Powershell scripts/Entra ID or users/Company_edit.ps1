# Import required modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = @(
    # HR Department
    "hr1@example.com",
    
    # US Sales Team
    "sales1@example.com",
    
    # Military Team
    "military1@example.com",
    
    # US Operations Team
    "operations1@example.com",
    
    # After Hours & PL Operations Team
    "afterhours1@example.com"
)

$companyName = "Company A"

Write-Host "Starting to update company names..."
Write-Host "Total users to process: $($users.Count)"

foreach ($user in $users) {
    try {
        $params = @{
            CompanyName = $companyName
        }
        
        Update-MgUser -UserId $user -BodyParameter $params
        Write-Host "Successfully updated company name for $user" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update company name for $user. Error: $_" -ForegroundColor Red
    }
}

Write-Host "Company name update process completed." -ForegroundColor Green

# Disconnect from Microsoft Graph
Disconnect-MgGraph