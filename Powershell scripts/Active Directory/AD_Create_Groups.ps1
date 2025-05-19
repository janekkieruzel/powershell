$Groups = @(
    "Placeholder_Group_Name" # Example Group Name
)

$TargetOU = "OU=Groups,DC=example,DC=local" # Example OU Path

foreach ($GroupName in $Groups) {
    New-ADGroup `
        -Name $GroupName `
        -SamAccountName $GroupName `
        -GroupScope Global `
        -GroupCategory Security `
        -Path $TargetOU `
        -Description "Grupa $GroupName" `
        -ErrorAction Stop

    Write-Host "Utworzono grupę: $GroupName"
}

Add-ADGroupMember -Identity "Placeholder_Group_Name" -Members `
    "useralias1", `
    "useralias2", `
    "useralias3", `
    "useralias4"

Write-Host "Dodano użytkowników do grup."
