#Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = @(
    # Wstaw adresy e-mail użytkowników
)

$managers = @(
    # Wstaw adresy e-mail managerów w tej samej kolejności co $users
)

for ($i = 0; $i -lt $users.Count; $i++) {
    $user = $users[$i]
    $manager = $managers[$i]
    try {
        if ($manager -and $manager -ne "") {
            $managerObj = Get-MgUser -UserId $manager -ErrorAction Stop
            $managerId = $managerObj.Id
            $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$managerId" }
            Set-MgUserManagerByRef -UserId $user -BodyParameter $body
            Write-Host "Successfully set manager for $user to $manager"
        } else {
            Write-Host "No manager set for $user (empty value)"
        }
    }
    catch {
        Write-Host "Failed to set manager for $user. Error details: $_"
    }
}

Disconnect-MgGraph
