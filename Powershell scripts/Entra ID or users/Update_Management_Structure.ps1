# Install required module if not present
#Install-Module Microsoft.Graph -Scope CurrentUser

# Define the management structure with departments and roles
$managerRelationships = @(
    # Level 1 - Department Director - uncommented to ensure Director is set as the top manager
    #[PSCustomObject]@{
    #    User = "director@example.com"       # Director Name
    #    Manager = $null
    #    Level = 1
    #    Department = "Department1"
    #    JobTitle = "Department Director"
    # },

    # Sales Department - Region A
    [PSCustomObject]@{
        User = "manager1@example.com"    # Manager 1
        Manager = "director@example.com"
        Level = 2
        Department = "Sales RegionA"
        JobTitle = "Director - Key Accounts & Sales"
    },
    [PSCustomObject]@{
        User = "manager2@example.com"    # Manager 2
        Manager = "director@example.com"
        Level = 2
        Department = "Sales RegionA"
        JobTitle = "Vice President - Sales"
    },
    [PSCustomObject]@{
        User = "manager3@example.com"    # Manager 3
        Manager = "director@example.com"
        Level = 2
        Department = "Sales RegionA"
        JobTitle = "Manager - Corporate Sales"
    },
    [PSCustomObject]@{
        User = "manager4@example.com"    # Manager 4
        Manager = "director@example.com"
        Level = 2
        Department = "Sales RegionA"
        JobTitle = "Transport Division General Manager"
    },
    [PSCustomObject]@{
        User = "manager5@example.com"    # Manager 5
        Manager = "director@example.com"
        Level = 2
        Department = "Sales RegionA"
        JobTitle = "Manager Sales"
    },
    [PSCustomObject]@{
        User = "salesin1@example.com"     # Sales Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Sales Region2"
        JobTitle = "Sr. Manager Sales"
    },
    [PSCustomObject]@{
        User = "salesin2@example.com"  # VP Sales
        Manager = "region_director@example.com"
        Level = 2
        Department = "Sales Region2"
        JobTitle = "Senior Vice President - Sales"
    },

    # Network Sales Department - Region2
    [PSCustomObject]@{
        User = "networksales1@example.com"  # Network Sales Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Network Sales Region2"
        JobTitle = "Manager - Global Network Sales"
    },

    # Customer Service Department - Region2
    [PSCustomObject]@{
        User = "customerservice1@example.com"  # Customer Service Assistant
        Manager = "region_director@example.com"
        Level = 2
        Department = "Customer Service Region2"
        JobTitle = "Assistant Manager - Customer Service"
    },
    [PSCustomObject]@{
        User = "customerservice2@example.com"  # Operations Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Customer Service Region2"
        JobTitle = "Manager - Operations & Customer Service"
    },
    [PSCustomObject]@{
        User = "customerservice3@example.com"  # Customer Service Executive
        Manager = "region_director@example.com"
        Level = 2
        Department = "Customer Service Region2"
        JobTitle = "Executive - Customer Service"
    },

    # Freight Department - Region2
    [PSCustomObject]@{
        User = "freight1@example.com"  # Freight Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Freight Department Region2"
        JobTitle = "Assisting Manager - Ocean Freight"
    },
    [PSCustomObject]@{
        User = "freight2@example.com"  # Network Pricing Executive
        Manager = "region_director@example.com"
        Level = 2
        Department = "Freight Department Region2"
        JobTitle = "Senior Executive - Global Network Pricing & CS"
    },
    [PSCustomObject]@{
        User = "freight3@example.com"  # Air Freight Executive
        Manager = "region_director@example.com"
        Level = 2
        Department = "Freight Department Region2"
        JobTitle = "Executive - Air"
    },

    # Finance Department - Region2
    [PSCustomObject]@{
        User = "finance1@example.com"  # Finance Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Finance Region2"
        JobTitle = "Senior Manager Finance"
    },
    [PSCustomObject]@{
        User = "finance2@example.com"  # Credit Control Manager
        Manager = "region_director@example.com"
        Level = 2
        Department = "Finance Region2"
        JobTitle = "Assist Manager - Credit Control and Finance"
    }
)

# Connect to Microsoft Graph
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction Stop
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
}
catch {
    Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
    exit 1
}

# Function to validate user existence
function Test-UserExists {
    param(
        [string]$userEmail
    )
    try {
        $null = Get-MgUser -UserId $userEmail -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "User $userEmail not found in Entra ID" -ForegroundColor Yellow
        return $false
    }
}

# Validate all users exist before making any changes
$allUsers = $managerRelationships | ForEach-Object { $_.User, $_.Manager } | Where-Object { $_ -ne $null } | Select-Object -Unique
$invalidUsers = $allUsers | Where-Object { -not (Test-UserExists $_) }

if ($invalidUsers) {
    Write-Host "Found invalid users. Please check these email addresses:" -ForegroundColor Red
    $invalidUsers | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
    Disconnect-MgGraph
    exit 1
}

# Process updates by level to ensure proper hierarchy
$levels = $managerRelationships | Select-Object -ExpandProperty Level | Sort-Object -Unique

foreach ($level in $levels) {
    $levelRelationships = $managerRelationships | Where-Object { $_.Level -eq $level }
    
    Write-Host "`nProcessing Level $level relationships..." -ForegroundColor Cyan
    
    foreach ($relation in $levelRelationships) {
        try {
            Write-Host "`nProcessing user: $($relation.User)"
            Write-Host "Department: $($relation.Department)"
            Write-Host "Job Title: $($relation.JobTitle)"
            Write-Host "Manager: $($relation.Manager)"
            
            # Update user's department and job title
            $updateParams = @{
                Department = $relation.Department
                JobTitle = $relation.JobTitle
            }
            
            Update-MgUser -UserId $relation.User -BodyParameter $updateParams
            Write-Host "Updated department and job title for $($relation.User)" -ForegroundColor Green

            # Skip setting manager for top level (Director)
            if ($null -eq $relation.Manager) {
                Write-Host "Skipping manager assignment for top-level position: $($relation.User)" -ForegroundColor Yellow
                continue
            }

            # Set manager
            $managerObj = Get-MgUser -UserId $relation.Manager -ErrorAction Stop
            if (-not $managerObj) {
                Write-Host "Manager not found: $($relation.Manager)" -ForegroundColor Yellow
                continue
            }
            
            $body = @{
                '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($managerObj.Id)"
            }
            
            Set-MgUserManagerByRef -UserId $relation.User -BodyParameter $body
            Write-Host "Successfully set manager for $($relation.User)" -ForegroundColor Green
            
            # Add small delay to prevent throttling
            Start-Sleep -Milliseconds 500
        }
        catch {
            Write-Host "Error processing user $($relation.User): $_" -ForegroundColor Red
        }
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "`nIT department structure update completed." -ForegroundColor Green