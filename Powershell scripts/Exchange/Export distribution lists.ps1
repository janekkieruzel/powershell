# Install the Exchange Online module if not already installed
# Install-Module -Name ExchangeOnlineManagement

# Import the Exchange Online module
# Import-Module ExchangeOnlineManagement

# Connect to Exchange Online (no need to store in $Session)
Connect-ExchangeOnline -UserPrincipalName admin@example.com

# Create a list to store the output
$output = @()

# Get all distribution lists
$distributionLists = Get-DistributionGroup -ResultSize Unlimited

# Loop through each distribution list and get its members
foreach ($dl in $distributionLists) {
    try {
        Write-Host "Processing distribution list: $($dl.DisplayName)"
        $members = Get-DistributionGroupMember -Identity $dl.Identity -ResultSize Unlimited

        foreach ($member in $members) {
            $output += [PSCustomObject]@{
                DistributionListName  = $dl.DisplayName
                DistributionListEmail = $dl.PrimarySmtpAddress
                MemberName            = $member.DisplayName
                MemberEmail           = $member.PrimarySmtpAddress
                MemberType            = $member.RecipientTypeDetails
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve members for the distribution list: $($dl.DisplayName). Error: $_"
    }
}

# Define the path to save the file
$exportPath = "C:\Reports\DistributionListsAndMembers.csv"

# Export the output to a temporary CSV file
$tempPath = "$env:Temp\DistributionListsAndMembers.csv"
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
