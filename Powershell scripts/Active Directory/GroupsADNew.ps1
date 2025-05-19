$Groups = @(
    "Department1",
    "Department2",
    "Group1",
    "Group2",
    "Region1",
    "Region2",
    "Team1",
    "Access_All",
    "Access_Limited",
    "Access_Reports",
    "CompanyA",
    "CompanyA-LocalAdmin",
    "Office365",
    "Access_Restricted",
    "VPN_Users",
    "Partner1",
    "Employees",
    "Management",
    "Profiles_Remote",
    "Partner2",
    "Partner2VPN",
    "Team_Region1",
    "Team_Region2",
    "Foreign",
    "Board"
)

$TargetOU = "OU=Groups,DC=example,DC=local"

foreach ($GroupName in $Groups) {
    New-ADGroup `
        -Name $GroupName `
        -SamAccountName $GroupName `
        -GroupScope Global `
        -GroupCategory Security `
        -Path $TargetOU `
        -Description "Grupa zabezpieczeń - Globalna $GroupName" `
        -ErrorAction Stop

    Write-Host "Utworzono grupę: $GroupName"
}
