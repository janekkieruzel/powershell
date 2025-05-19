# Define the top-level folder and export target
$topLevelFolder = "C:\Users\Username\Documents\DataFolder"
$exportTarget = "C:\Users\Username\Downloads\FolderPermissions.csv"

# Initialize the CSV file with a header
"Path,IdentityReference,FileSystemRights" | Out-File -FilePath $exportTarget -Encoding UTF8

# Loop through directories
foreach ($folder in Get-ChildItem $topLevelFolder -Directory -Recurse) {
    try {
        # Check if ACLs are protected
        $acl = Get-Acl $folder.FullName
        if ($acl.AreAccessRulesProtected) {
            # Export ACL details
            $acl.Access | ForEach-Object {
                [PSCustomObject]@{
                    Path              = $folder.FullName
                    IdentityReference = $_.IdentityReference
                    FileSystemRights  = $_.FileSystemRights
                }
            } | Export-Csv -Path $exportTarget -Append -NoTypeInformation -Encoding UTF8
        }
    } catch {
        Write-Warning "Failed to process folder: $($folder.FullName). Error: $_"
    }
}

Write-Host "Export completed. Results saved to: $exportTarget"
