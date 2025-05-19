# Install the Exchange Online module if not already installed
# Install-Module -Name ExchangeOnlineManagement

# Import the Exchange Online module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@example.com

# Create a list to store the output
$output = @()

# Get all Microsoft 365 groups
$groups = Get-UnifiedGroup -ResultSize Unlimited

# Loop through each group and get its members
foreach ($group in $groups) {
    try {
        Write-Host "Processing group: $($group.DisplayName)"
        $members = Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Members

        foreach ($member in $members) {
            $output += [PSCustomObject]@{
                GroupName  = $group.DisplayName
                GroupEmail = $group.PrimarySmtpAddress
                MemberName = $member.Name
                MemberEmail = $member.PrimarySmtpAddress
                MemberType = $member.RecipientTypeDetails
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve members for the group: $($group.DisplayName). Error: $_"
    }
}

# Define the path to save the file
$exportPath = "C:\Reports\M365GroupsAndMembers.csv"

# Export the output to a temporary CSV file
$tempPath = "$env:Temp\M365GroupsAndMembers.csv"
$output | Export-Csv -Path $tempPath -NoTypeInformation -Force

# Re-encode the file with UTF-8 BOM
Add-Type -AssemblyName "System.Text.Encoding"
$utf8WithBom = [System.Text.Encoding]::UTF8
$utf8WithBomFileContent = $utf8WithBom.GetPreamble() + [System.IO.File]::ReadAllBytes($tempPath)
[System.IO.File]::WriteAllBytes($exportPath, $utf8WithBomFileContent)

# Clean up the temporary file
Remove-Item -Path $tempPath -Force

Write-Host "Export completed with UTF-8 BOM encoding. Check the file at: $exportPath"

# Disconnect the session
Disconnect-ExchangeOnline -Confirm:$false
