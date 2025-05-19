#Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = @(
    "user1@example.com",
    "user2@example.com",
    "user3@example.com"
)

foreach ($user in $users) {
    try {
        Update-MgUser -UserId $user -Country "India"
        Write-Host "Successfully updated $user"
    }
    catch {
        Write-Host "Failed to update $user. Error details: $_"
    }
}

Disconnect-MgGraph