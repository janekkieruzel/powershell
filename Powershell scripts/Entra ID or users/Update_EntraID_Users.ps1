# Script to update users' department, job title and manager in Entra ID
# Author: Developer Name
# Date: 2024-04-18

# Import required modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Define departments and titles
$userDepartments = @{
    # HR Department
    "user1@example.com" = "HR Department"
    
    # US Sales Team
    "user2@example.com" = "US Sales Team"
    "user3@example.com" = "US Sales Team"
    
    # Military Team
    "user17@example.com" = "Military Team"
    "user18@example.com" = "Military Team"
    
    # US Operations Team
    "user21@example.com" = "US Operations Team"
    
    # After Hours
    "user29@example.com" = "After Hours Operations Support"
    "user30@example.com" = "After Hours Operations Support"
}

$userTitles = @{
    # HR Department
    "user1@example.com" = "HR Representative"
    
    # US Sales Team
    "user2@example.com" = "Senior Sales Representative"
    "user3@example.com" = "Senior Sales Representative"
    
    # Military Team
    "user17@example.com" = "Senior Military Freight Specialist"
    "user18@example.com" = "Carrier Representative"
    "user19@example.com" = "ATR Specialist"
    "user20@example.com" = "Government Pricing Specialist"
    
    # US Operations Team
    "user21@example.com" = "Senior Carrier Representative"
    "user22@example.com" = "Senior Carrier Representative"
    
    # After Hours & PL Operations Team
    "user29@example.com" = "Senior After Hours Support"
    "user30@example.com" = "After Hours Support"
}

$users = @(
    # HR Department
    "user1@example.com",
    
    # US Sales Team
    "user2@example.com",
    "user3@example.com"
    
    # Military Team
    "user17@example.com",
    "user18@example.com",
    "user19@example.com",
    "user20@example.com",
    
    # US Operations Team
    "user21@example.com",
    "user22@example.com"
    
    # After Hours & PL Operations Team
    "user29@example.com",
    "user30@example.com",
    "user31@example.com"
)

$managers = @(
    # HR Department
    "ceo@example.com", # CEO dla HR
    
    # US Sales Team - manager: Sales Manager
    "salesmanager@example.com",
    "salesmanager@example.com"
    
    # Military Team - manager: Military Manager
    "militarymanager@example.com",
    "militarymanager@example.com"
    
    # US Operations Team - manager: Operations Manager
    "operationsmanager@example.com",
    "operationsmanager@example.com"
    
    # After Hours & PL Operations Team - manager: PL Manager
    "plmanager@example.com",
    "plmanager@example.com",
    "plmanager@example.com"
)

Write-Host "Starting to update user properties..."
Write-Host "Total users to process: $($users.Count)"

for ($i = 0; $i -lt $users.Count; $i++) {
    $user = $users[$i]
    $manager = $managers[$i]
    $department = $userDepartments[$user]
    $title = $userTitles[$user]
    
    try {
        # Update department and job title
        $params = @{
            Department = $department
            JobTitle = $title
        }
        Update-MgUser -UserId $user -BodyParameter $params
        Write-Host "Updated department and title for $user" -ForegroundColor Green

        # Update manager
        if ($manager -and $manager -ne "") {
            $managerObj = Get-MgUser -UserId $manager -ErrorAction Stop
            $managerId = $managerObj.Id
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$managerId" }
            Set-MgUserManagerByRef -UserId $user -BodyParameter $body
            Write-Host "Updated manager for $user to $manager" -ForegroundColor Green
        } else {
            Write-Host "No manager set for $user (empty value)" -ForegroundColor Yellow
        }
        
        Write-Host "Successfully completed all updates for: $user" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update user: $user. Error details: $_" -ForegroundColor Red
    }
}

Write-Host "Update process completed." -ForegroundColor Green

# Disconnect from Microsoft Graph
Disconnect-MgGraph