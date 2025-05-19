# Skrypt do tworzenia i konfiguracji nowych użytkowników w Microsoft Entra ID

# Wymuś załadowanie modułów, aby uniknąć konfliktów wersji
# Import-Module Microsoft.Graph.Authentication -Force  # Moved down
# Import-Module Microsoft.Graph.Users -Force          # Moved down

# Połączenie z Microsoft Graph - zostaniesz poproszony o zalogowanie
# Upewnij się, że masz odpowiednie uprawnienia (np. User Administrator)
# Write-Host "Łączenie z Microsoft Graph..."           # Moved down
# Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" # Moved down

<#
.SYNOPSIS
    Skrypt do tworzenia i konfiguracji nowych użytkowników w Microsoft Entra ID.
.DESCRIPTION
    Skrypt umożliwia tworzenie nowych użytkowników w Microsoft Entra ID (dawniej Azure AD)
    z predefiniowanymi szablonami działów i lokalizacji. Skrypt pozwala na wybór firmy,
    działu i lokalizacji, a następnie uzupełnia odpowiednie dane użytkownika.
    Dodatkowo przypisuje licencje i managera, jeśli są określone.
    
    Skrypt może działać w trybie interaktywnym (domyślnie) lub nieinteraktywnym (z parametrami).
.PARAMETER NonInteractive
    Przełącznik trybu nieinteraktywnego. Jeśli ustawiony, skrypt użyje wartości z innych parametrów zamiast pytań interaktywnych.
.PARAMETER FirstName
    Imię nowego użytkownika (np. Jan).
.PARAMETER LastName
    Nazwisko nowego użytkownika (np. Kowalski).
.PARAMETER Company
    Nazwa firmy dla nowego użytkownika. Dostępne opcje: "Company A", "Company B".
.PARAMETER Department
    Nazwa działu dla nowego użytkownika (np. "Road Freight EU", "IT Department").
.PARAMETER Office
    Nazwa biura dla nowego użytkownika (np. "Warsaw", "Gdynia").
.PARAMETER JobTitle
    Stanowisko nowego użytkownika (np. "Specialist", "Manager").
.PARAMETER ManagerUPN
    UPN managera nowego użytkownika (np. "manager.name@example.com").
.PARAMETER ForceChangePasswordNextSignIn
    Określa, czy użytkownik powinien zmienić hasło przy pierwszym logowaniu. Domyślnie $true.
.PARAMETER AddUserTo2FAGroup
    Określa, czy użytkownik ma być dodany do grupy 2FA. Domyślnie $false.
.EXAMPLE
    .\New_User.ps1
    Uruchamia skrypt w trybie interaktywnym, gdzie wszystkie informacje są pobierane poprzez pytania.
.EXAMPLE
    .\New_User.ps1 -NonInteractive -FirstName "Jan" -LastName "Kowalski" -Company "Company A" -Department "IT Department" -Office "Warsaw" -JobTitle "IT Specialist" -ManagerUPN "another.user@example.com"
    Tworzy użytkownika w trybie nieinteraktywym z podanymi parametrami.
.EXAMPLE
    .\New_User.ps1 -NonInteractive -FirstName "Anna" -LastName "Nowak" -Company "Company B" -Department "Sea & Air Freight" -Office "Gdynia" -ForceChangePasswordNextSignIn $false
    Tworzy użytkownika w trybie nieinteraktywym bez wymogu zmiany hasła przy pierwszym logowaniu.
.NOTES
    Autor: Scripter Name
    Data utworzenia: Maj 2025
    Wersja: 1.1
#>
[CmdletBinding(DefaultParameterSetName = 'InteractiveSet')]
param (
    [Parameter(ParameterSetName = 'NonInteractiveSet')]
    [switch]$NonInteractive,

    [Parameter(ParameterSetName = 'InteractiveSet', Mandatory = $false)]
    [Parameter(ParameterSetName = 'NonInteractiveSet', Mandatory = $true)]
    [string]$FirstName,

    [Parameter(ParameterSetName = 'InteractiveSet', Mandatory = $false)]
    [Parameter(ParameterSetName = 'NonInteractiveSet', Mandatory = $true)]
    [string]$LastName,

    [Parameter(ParameterSetName = 'InteractiveSet', Mandatory = $false)]
    [Parameter(ParameterSetName = 'NonInteractiveSet', Mandatory = $true)]
    [ValidateSet("Company A", "Company B")]
    [string]$Company,

    [Parameter(ParameterSetName = 'InteractiveSet', Mandatory = $false)]
    [Parameter(ParameterSetName = 'NonInteractiveSet', Mandatory = $true)]
    [string]$Department,

    [Parameter(ParameterSetName = 'InteractiveSet', Mandatory = $false)]
    [Parameter(ParameterSetName = 'NonInteractiveSet', Mandatory = $true)]
    [string]$Office,

    [Parameter(Mandatory = $false)] # Common to both sets
    [string]$JobTitle,

    [Parameter(Mandatory = $false)] # Common to both sets
    [string]$ManagerUPN,

    [Parameter(Mandatory = $false)] # Common to both sets
    [bool]$ForceChangePasswordNextSignIn = $true,

    [Parameter(Mandatory = $false)] # Common to both sets, controls 2FA group addition
    [bool]$AddUserTo2FAGroup = $false # Default to false. Set to $true to add, or answer prompt in interactive mode.
)

# Wymuś załadowanie modułów, aby uniknąć konfliktów wersji
Import-Module Microsoft.Graph.Authentication -Force
Import-Module Microsoft.Graph.Users -Force

# Połączenie z Microsoft Graph - zostaniesz poproszony o zalogowanie
# Upewnij się, że masz odpowiednie uprawnienia (np. User Administrator)
Write-Host "Łączenie z Microsoft Graph..."
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "GroupMember.ReadWrite.All" -NoWelcome

# Funkcja do generowania losowego, silnego hasła
function New-RandomPassword {
    <#
    .SYNOPSIS
        Generuje losowe, silne hasło.
    .DESCRIPTION
        Funkcja generuje losowe hasło składające się z małych i wielkich liter, cyfr oraz znaków specjalnych.
    .PARAMETER Length
        Długość generowanego hasła. Domyślnie 16 znaków.
    .EXAMPLE
        New-RandomPassword -Length 20
        Generuje losowe hasło o długości 20 znaków.
    #>
    param (
        [int]$Length = 16
    )
    $Lowercase = "abcdefghijklmnopqrstuvwxyz"
    $Uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $Numbers = "0123456789"
    $SpecialChars = "!@#$%^&*()-_=+[]{};:,.<>?/"

    # Upewnij się, że hasło zawiera co najmniej jeden znak z każdej kategorii
    $Password = @(
        $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
        $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
        $Numbers[(Get-Random -Maximum $Numbers.Length)]
        $SpecialChars[(Get-Random -Maximum $SpecialChars.Length)]
    )

    # Dodaj pozostałe znaki
    $AllChars = $Lowercase + $Uppercase + $Numbers + $SpecialChars
    $RemainingLength = $Length - $Password.Count
    $Password += 1..$RemainingLength | ForEach-Object { $AllChars[(Get-Random -Maximum $AllChars.Length)] }

    # Wymieszaj znaki
    $Password = $Password | Get-Random -Count $Length

    return ($Password -join '')
}

# Funkcja do usuwania polskich znaków
function Remove-PolishChars {
    <#
    .SYNOPSIS
        Usuwa polskie znaki diakrytyczne z tekstu.
    .DESCRIPTION
        Funkcja zamienia polskie znaki diakrytyczne na ich odpowiedniki bez znaków diakrytycznych.
    .PARAMETER Text
        Tekst zawierający polskie znaki diakrytyczne.
    .EXAMPLE
        Remove-PolishChars -Text "Zażółć gęślą jaźń"
        Zwraca: "Zazolc gesla jazn"
    #>
    param (
        [string]$Text
    )
    $Text = $Text -replace 'ą', 'a'
    $Text = $Text -replace 'ć', 'c'
    $Text = $Text -replace 'ę', 'e'
    $Text = $Text -replace 'ł', 'l'
    $Text = $Text -replace 'ń', 'n'
    $Text = $Text -replace 'ó', 'o'
    $Text = $Text -replace 'ś', 's'
    $Text = $Text -replace 'ź', 'z'
    $Text = $Text -replace 'ż', 'z'
    $Text = $Text -replace 'Ą', 'A'
    $Text = $Text -replace 'Ć', 'C'
    $Text = $Text -replace 'Ę', 'E'
    $Text = $Text -replace 'Ł', 'L'
    $Text = $Text -replace 'Ń', 'N'
    $Text = $Text -replace 'Ó', 'O'
    $Text = $Text -replace 'Ś', 'S'
    $Text = $Text -replace 'Ź', 'Z'
    $Text = $Text -replace 'Ż', 'Z'
    return $Text
}

# Funkcja do wczytania wszystkich dostępnych szablonów
function Get-AllTemplates {
    $TemplatesPath = Join-Path -Path $PSScriptRoot -ChildPath "Templates"
    $TemplatesFile = Join-Path -Path $TemplatesPath -ChildPath "Templates.csv"
    
    if (Test-Path -Path $TemplatesFile) {
        return Import-Csv -Path $TemplatesFile
    }
    else {
        Write-Error "Nie znaleziono pliku szablonów: $TemplatesFile"
        exit
    }
}

# Funkcja do wyboru firmy
function Select-Company {
    param (
        [string]$CompanyName = ""
    )
    
    # Jeśli podano nazwę firmy, użyj jej
    if (-not [string]::IsNullOrWhiteSpace($CompanyName)) {
        switch ($CompanyName) {
            "Company A" { return @{Name = "Company A"; Domain = "example.com"} }
            "Company B" { return @{Name = "Company B"; Domain = "example.org"} }
            default {
                Write-Host "Nieprawidłowa nazwa firmy: $CompanyName. Użycie trybu interaktywnego." -ForegroundColor Yellow
                # Kontynuuj z trybem interaktywnym
            }
        }
    }
    
    Write-Host "`nWybierz firmę:" 
    Write-Host "[1] Company A"
    Write-Host "[2] Company B"
    
    $CompanyChoice = Read-Host "`nWybierz numer firmy (1-2)"
    
    switch ($CompanyChoice) {
        "1" { return @{Name = "Company A"; Domain = "example.com"} }
        "2" { return @{Name = "Company B"; Domain = "example.org"} }
        default {
            Write-Host "Nieprawidłowy wybór. Proszę wybrać 1 lub 2" -ForegroundColor Red
            return Select-Company
        }
    }
}

# Funkcja do wyświetlania i wyboru dostępnych działów
function Select-Department {
    param (
        [array]$Templates,
        [string]$DepartmentName = ""
    )
    
    # Wyodrębnij unikalne działy
    $Departments = $Templates | Select-Object -Property Department -Unique
    
    # Jeśli podano nazwę działu, sprawdź, czy istnieje w szablonach
    if (-not [string]::IsNullOrWhiteSpace($DepartmentName)) {
        $FoundDepartment = $Departments | Where-Object { $_.Department -eq $DepartmentName }
        if ($FoundDepartment) {
            return $DepartmentName
        }
        else {
            Write-Host "Nie znaleziono działu: $DepartmentName. Użycie trybu interaktywnego." -ForegroundColor Yellow
            # Kontynuuj z trybem interaktywnym
        }
    }
    
    Write-Host "`nDostępne działy:"
    for ($i = 0; $i -lt $Departments.Count; $i++) {
        Write-Host "[$($i+1)] $($Departments[$i].Department)"
    }
    
    $DepartmentChoice = Read-Host "`nWybierz numer działu (1-$($Departments.Count))"
    $DepartmentIndex = [int]$DepartmentChoice - 1
    
    if ($DepartmentIndex -ge 0 -and $DepartmentIndex -lt $Departments.Count) {
        return $Departments[$DepartmentIndex].Department
    }
    else {
        Write-Host "Nieprawidłowy wybór. Proszę wybrać numer od 1 do $($Departments.Count)" -ForegroundColor Red
        return Select-Department -Templates $Templates
    }
}

# Funkcja do wyświetlania i wyboru dostępnych lokalizacji dla wybranego działu
function Select-Location {
    param (
        [array]$Templates,
        [string]$Department,
        [string]$OfficeName = ""
    )
    
    # Filtruj lokalizacje dla wybranego działu
    $Locations = $Templates | Where-Object { $_.Department -eq $Department } | Select-Object -Property Office, City
    
    # Jeśli podano nazwę biura, sprawdź, czy istnieje w szablonach dla tego działu
    if (-not [string]::IsNullOrWhiteSpace($OfficeName)) {
        $FoundLocation = $Locations | Where-Object { $_.Office -eq $OfficeName }
        if ($FoundLocation) {
            # Zwróć pełny szablon dla wybranego działu i lokalizacji
            return $Templates | Where-Object { $_.Department -eq $Department -and $_.Office -eq $OfficeName } | Select-Object -First 1
        }
        else {
            Write-Host "Nie znaleziono biura: $OfficeName dla działu: $Department. Użycie trybu interaktywnego." -ForegroundColor Yellow
            # Kontynuuj z trybem interaktywnym
        }
    }
    
    Write-Host "`nDostępne lokalizacje dla działu $($Department):"
    for ($i = 0; $i -lt $Locations.Count; $i++) {
        Write-Host "[$($i+1)] $($Locations[$i].Office), $($Locations[$i].City)"
    }
    
    $LocationChoice = Read-Host "`nWybierz numer lokalizacji (1-$($Locations.Count))"
    $LocationIndex = [int]$LocationChoice - 1
    
    if ($LocationIndex -ge 0 -and $LocationIndex -lt $Locations.Count) {
        $SelectedOffice = $Locations[$LocationIndex].Office
        # Zwróć pełny szablon dla wybranego działu i lokalizacji
        return $Templates | Where-Object { $_.Department -eq $Department -and $_.Office -eq $SelectedOffice } | Select-Object -First 1
    }
    else {
        Write-Host "Nieprawidłowy wybór. Proszę wybrać numer od 1 do $($Locations.Count)" -ForegroundColor Red
        return Select-Location -Templates $Templates -Department $Department
    }
}

# Wczytaj wszystkie dostępne szablony
$AvailableTemplates = Get-AllTemplates

# Tryb interaktywny lub nie interaktywny
if ($PSCmdlet.ParameterSetName -eq 'NonInteractiveSet') {
    Write-Host "Uruchomiono w trybie nieinteraktywnym z parametrami." -ForegroundColor Green

    # Wybór firmy
    $SelectedCompanyInfo = Select-Company -CompanyName $Company
    $Domena = $SelectedCompanyInfo.Domain
    $SelectedCompany = $SelectedCompanyInfo.Name
    
    # Wybór działu
    $SelectedDepartment = Select-Department -Templates $AvailableTemplates -DepartmentName $Department
    
    # Wybór lokalizacji
    $SelectedTemplate = Select-Location -Templates $AvailableTemplates -Department $SelectedDepartment -OfficeName $Office
    
    # Przypisanie wartości z parametrów
    $Imie = $FirstName
    $Nazwisko = $LastName
    
    # Sprawdzenie stanowiska
    if ([string]::IsNullOrWhiteSpace($JobTitle)) {
        $JobTitle = $SelectedTemplate.JobTitle
    }
    
    # Nie pytaj o potwierdzenie w trybie nieinteraktywym
    $Potwierdzenie = "T"
}
else {
    # Tryb interaktywny
    # Wybierz firmę
    $SelectedCompanyInfo = Select-Company
    $Domena = $SelectedCompanyInfo.Domain
    $SelectedCompany = $SelectedCompanyInfo.Name
    Write-Host "`nWybrana firma: $SelectedCompany"
    
    # Wybierz dział
    $SelectedDepartment = Select-Department -Templates $AvailableTemplates
    
    # Wybierz lokalizację dla wybranego działu
    $SelectedTemplate = Select-Location -Templates $AvailableTemplates -Department $SelectedDepartment
    
    # Zapytaj o imię użytkownika
    $Imie = Read-Host "Podaj imię użytkownika (np. Jan)"
    
    # Zapytaj o nazwisko użytkownika
    $Nazwisko = Read-Host "Podaj nazwisko użytkownika (np. LastName)"
    
    # Zapytaj o stanowisko (jeśli nie ma w szablonie)
    $JobTitle = $SelectedTemplate.JobTitle
    if ([string]::IsNullOrWhiteSpace($JobTitle)) {
        $JobTitle = Read-Host "Podaj stanowisko użytkownika (np. Specialist, Manager)"
    }

    # Zapytaj o dodanie do grupy 2FA tylko w trybie interaktywnym, jeśli parametr nie został użyty
    if (-not $PSBoundParameters.ContainsKey('AddUserTo2FAGroup')) {
        $PromptUserDisplayNameFor2FA = "$Imie $Nazwisko"
        # Default to current value of $AddUserTo2FAGroup (which is $false unless overridden by param)
        $Current2FADefault = if ($AddUserTo2FAGroup) { "T" } else { "N" }
        $Choice2FA = Read-Host "Czy dodać użytkownika '$PromptUserDisplayNameFor2FA' do grupy 2FA? (T/N) [Domyślnie: $Current2FADefault]"
        if ($Choice2FA -eq 'T' -or $Choice2FA -eq 't') {
            $AddUserTo2FAGroup = $true
        }
        elseif ($Choice2FA -eq 'N' -or $Choice2FA -eq 'n') {
            $AddUserTo2FAGroup = $false
        }
        # If user enters nothing or invalid, $AddUserTo2FAGroup retains its current value (initial default or from param)
    }
    
    # Zapytaj o UPN managera (opcjonalne)
    $ManagerUPN = Read-Host "Podaj UPN managera (np. manager.name@example.com) lub pozostaw puste pole"
    
    # Potwierdzenie $Potwierdzenie zostanie ustawione po wyświetleniu podsumowania, inicjalizujemy na N
    $Potwierdzenie = "N"
}

# Przetwarzanie imienia i nazwiska - usunięcie polskich znaków i zamiana na małe litery
$ImiePrzetworzone = (Remove-PolishChars -Text $Imie).ToLower()
$NazwiskoPrzetworzone = (Remove-PolishChars -Text $Nazwisko).ToLower()

# Tworzenie User Principal Name (UPN)
$PierwszaLiteraImienia = $ImiePrzetworzone.Substring(0, 1)
$UPN = "$PierwszaLiteraImienia$NazwiskoPrzetworzone@$Domena"

# Tworzenie głównego adresu email
$Email = "$ImiePrzetworzone.$NazwiskoPrzetworzone@$Domena"

# Wyświetlanie informacji przed utworzeniem użytkownika
Write-Host "`n--- Informacje o nowym użytkowniku ---"
Write-Host "Imię: $Imie"
Write-Host "Nazwisko: $Nazwisko"
Write-Host "Wyświetlana nazwa: $Imie $Nazwisko"
Write-Host "UPN: $UPN"
Write-Host "Główny email: $Email"
Write-Host "Stanowisko: $JobTitle"
Write-Host "Firma: $SelectedCompany"
Write-Host "Dział: $($SelectedTemplate.Department)"
Write-Host "Biuro: $($SelectedTemplate.Office)"
Write-Host "Adres: $($SelectedTemplate.StreetAddress)"
Write-Host "Miasto: $($SelectedTemplate.City)"
Write-Host "Region: $($SelectedTemplate.State)"
Write-Host "Kod pocztowy: $($SelectedTemplate.PostalCode)"
Write-Host "Kraj: $($SelectedTemplate.Country)"
Write-Host "Lokalizacja: $($SelectedTemplate.Location)"
Write-Host "Licencje: $($SelectedTemplate.Licenses)"
Write-Host "Dodanie do grupy 2FA: $AddUserTo2FAGroup" # Dodano wyświetlanie statusu 2FA
if (-not [string]::IsNullOrWhiteSpace($ManagerUPN)) {
    Write-Host "Manager: $ManagerUPN"
}

# Potwierdzenie przed utworzeniem (tylko w trybie interaktywnym)
if (-not $NonInteractive) {
    $Potwierdzenie = Read-Host "`nCzy chcesz utworzyć tego użytkownika? (T/N)"
    if ($Potwierdzenie -ne 'T' -and $Potwierdzenie -ne 't') {
        Write-Host "Anulowano tworzenie użytkownika." -ForegroundColor Yellow
        exit
    }
} # Dla trybu NonInteractive, $Potwierdzenie jest już ustawione na "T"


if (($Potwierdzenie -eq 'T' -or $Potwierdzenie -eq 't')) { # Sprawdzenie potwierdzenia
    # Generowanie silnego hasła
    $RandomPassword = New-RandomPassword -Length 16
    Write-Host "Wygenerowano silne hasło dla użytkownika."
    
    # Ustawienia hasła
    $PasswordProfile = @{
        ForceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn
        Password = $RandomPassword
    }

    # Tworzenie obiektu adresu
    $OfficeLocation = $SelectedTemplate.Office
    
    # Parametry nowego użytkownika z danymi z szablonu
    $UserParameters = @{
        AccountEnabled = $true
        DisplayName = "$Imie $Nazwisko"
        GivenName = $Imie
        Surname = $Nazwisko
        UserPrincipalName = $UPN
        MailNickname = "$ImiePrzetworzone.$NazwiskoPrzetworzone" # Zazwyczaj bez domeny
        Mail = $Email # Ustawienie głównego adresu email
        JobTitle = $JobTitle
        CompanyName = $SelectedCompany
        Department = $SelectedTemplate.Department
        OfficeLocation = $OfficeLocation
        StreetAddress = $SelectedTemplate.StreetAddress
        City = $SelectedTemplate.City
        State = $SelectedTemplate.State
        PostalCode = $SelectedTemplate.PostalCode
        Country = $SelectedTemplate.Country
        PasswordProfile = $PasswordProfile
        UsageLocation = $SelectedTemplate.Location # Wymagane dla niektórych licencji
        # ProxyAddresses nie jest ustawiane podczas tworzenia użytkownika, zostanie zaktualizowane później
    }

    try {
        Write-Host "`nTworzenie użytkownika $UPN..."
        $NewUser = New-MgUser -BodyParameter $UserParameters -ErrorAction Stop
        Write-Host "Użytkownik $UPN został pomyślnie utworzony." -ForegroundColor Green
        Write-Host "Główny adres email (Mail) został ustawiony na: $Email"
        
        # Zapisz dane logowania do pliku (przeniesione wyżej, aby mieć $NewUser.Id)
        $LogFilePath = Join-Path -Path $PSScriptRoot -ChildPath "UsersCreated"
        
        # Utwórz katalog, jeśli nie istnieje
        if (-not (Test-Path -Path $LogFilePath)) {
            New-Item -Path $LogFilePath -ItemType Directory | Out-Null
        }
        
        $LogFileName = "User_$((Get-Date).ToString('yyyyMMdd_HHmmss'))_$($NewUser.UserPrincipalName.Replace('@','_')).txt"
        $LogFilePath = Join-Path -Path $LogFilePath -ChildPath $LogFileName
        
        # Główny adres email (Mail) jest ustawiany podczas New-MgUser i automatycznie staje się primary SMTP.

        # Przypisanie managera
        if (-not [string]::IsNullOrWhiteSpace($ManagerUPN)) {
            Write-Host "`nPrzypisywanie managera..."
            
            try {
                # Pobranie ID managera na podstawie UPN
                $Manager = Get-MgUser -Filter "userPrincipalName eq '$ManagerUPN'" -ErrorAction Stop
                
                if ($Manager) {
                    # Utwórz referencję do managera
                    $ManagerReference = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($Manager.Id)"
                    }
                    
                    # Przypisz managera do użytkownika
                    Set-MgUserManagerByRef -UserId $NewUser.Id -BodyParameter $ManagerReference -ErrorAction Stop
                    Write-Host "Manager $ManagerUPN został przypisany do użytkownika $($NewUser.UserPrincipalName)" -ForegroundColor Green
                }
                else {
                    Write-Warning "Nie znaleziono managera o UPN: $ManagerUPN"
                }
            }
            catch {
                Write-Error "Wystąpił błąd podczas przypisywania managera $($ManagerUPN) do użytkownika $($NewUser.UserPrincipalName): $($_.Exception.Message)"
            }
        }

        # Przypisanie licencji
        if (-not [string]::IsNullOrWhiteSpace($SelectedTemplate.Licenses)) {
            $LicenseNames = $SelectedTemplate.Licenses -split ';' | ForEach-Object { $_.Trim() }
            if ($LicenseNames.Count -gt 0) {
                Write-Host "Przypisywanie licencji: $($LicenseNames -join ', ')..."
                try {
                    # Pobierz dostępne licencje w tenancie
                    $AvailableTenantSkus = Get-MgSubscribedSku | Select-Object -ExpandProperty SkuPartNumber
                    
                    $LicenseAssignmentPayload = @{
                        AddLicenses = @()
                        RemoveLicenses = @()
                    }

                    foreach ($LicenseName in $LicenseNames) {
                        $TrimmedLicenseName = $LicenseName.Trim()
                        # Sprawdź, czy licencja o tej nazwie (SkuPartNumber) istnieje
                        $FoundSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $TrimmedLicenseName }
                        
                        if ($FoundSku) {
                            $LicenseAssignmentPayload.AddLicenses += @{SkuId = $FoundSku.SkuId}
                            Write-Host "Znaleziono SkuId $($FoundSku.SkuId) dla licencji $TrimmedLicenseName." -ForegroundColor Cyan
                        } else {
                            Write-Warning "Nie znaleziono licencji o nazwie (SkuPartNumber) '$TrimmedLicenseName' w dostępnych licencjach tenanta. Sprawdź nazwę."
                            Write-Host "Dostępne SkuPartNumbers w tenancie: $($AvailableTenantSkus -join ', ')" -ForegroundColor Yellow
                        }
                    }

                    if ($LicenseAssignmentPayload.AddLicenses.Count -gt 0) {
                        Set-MgUserLicense -UserId $NewUser.Id -BodyParameter $LicenseAssignmentPayload | Out-Null
                        Write-Host "Pomyślnie przypisano licencje do użytkownika $($NewUser.UserPrincipalName)." -ForegroundColor Green
                    } else {
                        Write-Host "Nie przypisano żadnych licencji, ponieważ nie znaleziono pasujących SkuId dla podanych nazw." -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Error "Wystąpił błąd podczas przypisywania licencji do użytkownika $($NewUser.UserPrincipalName): $($_.Exception.Message)"
                }
            }
        }

        # Dodanie użytkownika do grupy 2FA (opcjonalne)
        if ($AddUserTo2FAGroup) {
            $GroupId2FA = "YOUR_2FA_GROUP_ID_PLACEHOLDER" # ObjectID grupy 2FA (Zastąp prawdziwym ID jeśli to konieczne, ale zanonimizowane dla przykładu)
            Write-Host "Dodawanie użytkownika $($NewUser.UserPrincipalName) do grupy 2FA ($GroupId2FA)..."
            try {
                New-MgGroupMember -GroupId $GroupId2FA -DirectoryObjectId $NewUser.Id | Out-Null
                Write-Host "Pomyślnie dodano użytkownika $($NewUser.UserPrincipalName) do grupy 2FA." -ForegroundColor Green
            }
            catch {
                Write-Error "Wystąpił błąd podczas dodawania użytkownika do grupy ${GroupId2FA}: $($_.Exception.Message)"
            }
        }

        $LogContent = @"
--- Dane logowania użytkownika ---
Data utworzenia: $(Get-Date)
Imię i nazwisko: $Imie $Nazwisko
UPN: $($NewUser.UserPrincipalName)
Email: $Email
Hasło: $RandomPassword
Zmiana hasła przy pierwszym logowaniu: $ForceChangePasswordNextSignIn
Firma: $SelectedCompany
Dział: $($SelectedTemplate.Department)
Biuro: $($SelectedTemplate.Office)
"@
        
        $LogContent | Out-File -FilePath $LogFilePath -Encoding UTF8
        Write-Host "Dane logowania zostały zapisane w pliku: $LogFilePath"
        
        if ($ForceChangePasswordNextSignIn) {
            Write-Host "Użytkownik będzie musiał zmienić hasło przy pierwszym logowaniu."
        } else {
            Write-Host "Użytkownik NIE będzie musiał zmieniać hasła przy pierwszym logowaniu."
        }
        
        # Przypisanie managera, jeśli podano UPN
        if (-not [string]::IsNullOrWhiteSpace($ManagerUPN)) {
            Write-Host "`nPrzypisywanie managera..."
            
            try {
                # Pobranie ID managera na podstawie UPN
                $Manager = Get-MgUser -Filter "userPrincipalName eq '$ManagerUPN'" -ErrorAction Stop
                
                if ($Manager) {
                    # Utwórz referencję do managera
                    $ManagerReference = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($Manager.Id)"
                    }
                    
                    # Przypisz managera do użytkownika
                    Set-MgUserManagerByRef -UserId $NewUser.Id -BodyParameter $ManagerReference -ErrorAction Stop
                    Write-Host "Manager $ManagerUPN został przypisany do użytkownika $($NewUser.UserPrincipalName)" -ForegroundColor Green
                }
                else {
                    Write-Warning "Nie znaleziono managera o UPN: $ManagerUPN"
                }
            }
            catch {
                Write-Error "Wystąpił błąd podczas przypisywania managera $($ManagerUPN) do użytkownika $($NewUser.UserPrincipalName): $($_.Exception.Message)"
            }
        }

        # Przypisanie licencji
        if (-not [string]::IsNullOrWhiteSpace($SelectedTemplate.Licenses)) {
            $LicenseNames = $SelectedTemplate.Licenses -split ';' | ForEach-Object { $_.Trim() }
            if ($LicenseNames.Count -gt 0) {
                Write-Host "Przypisywanie licencji: $($LicenseNames -join ', ')..."
                try {
                    # Pobierz dostępne licencje w tenancie
                    $AvailableTenantSkus = Get-MgSubscribedSku | Select-Object -ExpandProperty SkuPartNumber
                    
                    $LicenseAssignmentPayload = @{
                        AddLicenses = @()
                        RemoveLicenses = @()
                    }

                    foreach ($LicenseName in $LicenseNames) {
                        $TrimmedLicenseName = $LicenseName.Trim()
                        # Sprawdź, czy licencja o tej nazwie (SkuPartNumber) istnieje
                        $FoundSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $TrimmedLicenseName }
                        
                        if ($FoundSku) {
                            $LicenseAssignmentPayload.AddLicenses += @{SkuId = $FoundSku.SkuId}
                            Write-Host "Znaleziono SkuId $($FoundSku.SkuId) dla licencji $TrimmedLicenseName." -ForegroundColor Cyan
                        } else {
                            Write-Warning "Nie znaleziono licencji o nazwie (SkuPartNumber) '$TrimmedLicenseName' w dostępnych licencjach tenanta. Sprawdź nazwę."
                            Write-Host "Dostępne SkuPartNumbers w tenancie: $($AvailableTenantSkus -join ', ')" -ForegroundColor Yellow
                        }
                    }

                    if ($LicenseAssignmentPayload.AddLicenses.Count -gt 0) {
                        Set-MgUserLicense -UserId $NewUser.Id -BodyParameter $LicenseAssignmentPayload | Out-Null
                        Write-Host "Pomyślnie przypisano licencje do użytkownika $($NewUser.UserPrincipalName)." -ForegroundColor Green
                    } else {
                        Write-Host "Nie przypisano żadnych licencji, ponieważ nie znaleziono pasujących SkuId dla podanych nazw." -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Error "Wystąpił błąd podczas przypisywania licencji do użytkownika $($NewUser.UserPrincipalName): $($_.Exception.Message)"
                }
            }
        }

        # Dodanie użytkownika do grupy 2FA (opcjonalne)
        if ($AddUserTo2FAGroup) {
            $GroupId2FA = "YOUR_2FA_GROUP_ID_PLACEHOLDER" # ObjectID grupy 2FA (Zastąp prawdziwym ID jeśli to konieczne, ale zanonimizowane dla przykładu)
            Write-Host "Dodawanie użytkownika $($NewUser.UserPrincipalName) do grupy 2FA ($GroupId2FA)..."
            try {
                New-MgGroupMember -GroupId $GroupId2FA -DirectoryObjectId $NewUser.Id | Out-Null
                Write-Host "Pomyślnie dodano użytkownika $($NewUser.UserPrincipalName) do grupy 2FA." -ForegroundColor Green
            }
            catch {
                Write-Error "Wystąpił błąd podczas dodawania użytkownika do grupy ${GroupId2FA}: $($_.Exception.Message)"
            }
        }

    } # Koniec głównego bloku try dla tworzenia użytkownika i operacji po utworzeniu
    catch {
        Write-Error "Wystąpił błąd podczas tworzenia użytkownika lub jednej z operacji po utworzeniu: $($_.Exception.Message)"
        if ($_.Exception.ErrorDetails) {
            Write-Error "Szczegóły błędu (główny catch): $($_.Exception.ErrorDetails.Message)"
        }
        if ($_.Exception.Response) {
            Write-Error "Odpowiedź serwera (główny catch): $($_.Exception.Response.StatusCode) - $($_.Exception.Response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 3)"
        }
    } # Koniec głównego bloku catch
}
else {
    Write-Host "Anulowano tworzenie użytkownika."
}

# Rozłączenie z Microsoft Graph (opcjonalne, sesja wygaśnie automatycznie)
# Disconnect-MgGraph