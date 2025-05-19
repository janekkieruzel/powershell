# Script to update users' department, job title and manager in Entra ID
# Author: Jan Kieruzel
# Date: 2024-04-18

# Import required modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

$users = @(
    # HR Department
    "hr1@example.com",
    
    # US Sales Team
    "sales1@example.com",
    "sales2@example.com"
    
    # Military Team
    "military1@example.com"
    
    # US Operations Team
    "operations1@example.com",
    "operations2@example.com"
    
    # After Hours Operations Support & PL Operations Team
    "afterhours1@example.com",
    "afterhours2@example.com",
    "afterhours3@example.com"
)

$managers = @(
    # HR Department
    "ceo@example.com", # CEO dla HR
    
    # US Sales Team - manager
    "sales_manager@example.com",
    "sales_manager@example.com"
    
    # Military Team - manager
    "military_manager@example.com",
    "military_manager@example.com"
    
    # US Operations Team - manager
    "operations_manager@example.com",
    "operations_manager@example.com"
    
    # After Hours & PL Operations Team - manager
    "afterhours_manager@example.com",
    "afterhours_manager@example.com"
)

# Function to update user properties
function Update-UserProperties {
    param (
        [string]$UserPrincipalName,
        [string]$Department,
        [string]$JobTitle,
        [string]$ManagerUPN
    )

    try {
        # Update department and job title
        $params = @{
            Department = $Department
            JobTitle = $JobTitle
        }

        Update-MgUser -UserId $UserPrincipalName -BodyParameter $params
        Write-Host "Updated department and job title for: $UserPrincipalName" -ForegroundColor Green

        # Update manager using Set-MgUserManagerByRef
        if ($ManagerUPN) {
            $managerObj = Get-MgUser -UserId $ManagerUPN
            $managerId = $managerObj.Id
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$managerId" }
            Set-MgUserManagerByRef -UserId $UserPrincipalName -BodyParameter $body
            Write-Host "Updated manager for: $UserPrincipalName to: $ManagerUPN" -ForegroundColor Green
        }

        Write-Host "Successfully completed all updates for: $UserPrincipalName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update user: $UserPrincipalName. Error: $_"
    }
}

# Update test user
Write-Host "Starting update for test user: $testUser" -ForegroundColor Yellow
Update-UserProperties -UserPrincipalName $testUser `
                    -Department $testUserDepartment `
                    -JobTitle $testUserTitle `
                    -ManagerUPN $testUserManager

Write-Host "Test update completed" -ForegroundColor Green

Write-Host "Starting to update manager assignments..."
Write-Host "Total users to process: $($users.Count)"

for ($i = 0; $i -lt $users.Count; $i++) {
    $user = $users[$i]
    $manager = $managers[$i]
    try {
        if ($manager -and $manager -ne "") {
            $managerObj = Get-MgUser -UserId $manager -ErrorAction Stop
            $managerId = $managerObj.Id
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$managerId" }
            Set-MgUserManagerByRef -UserId $user -BodyParameter $body
            Write-Host "Successfully set manager for $user to $manager" -ForegroundColor Green
        } else {
            Write-Host "No manager set for $user (empty value)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to set manager for $user. Error details: $_" -ForegroundColor Red
    }
}

Write-Host "Manager update process completed." -ForegroundColor Green

# Disconnect from Microsoft Graph
Disconnect-MgGraph