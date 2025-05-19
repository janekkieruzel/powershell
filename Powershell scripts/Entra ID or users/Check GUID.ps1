#Connect-ExchangeOnline
$guids = @(
    "00000000-0000-0000-0000-000000000000"
)

$guids | ForEach-Object {
    Get-Mailbox -Filter "ExternalDirectoryObjectId -eq '$_'" | Select-Object DisplayName, ExternalDirectoryObjectId
}

