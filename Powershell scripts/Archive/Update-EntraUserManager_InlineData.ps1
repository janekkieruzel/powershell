<#
.SYNOPSIS
Uproszczony skrypt do masowej aktualizacji menedżera użytkowników w Entra ID.
Dane wejściowe (użytkownik i nowy menedżer) są definiowane bezpośrednio w skrypcie.
Nadpisuje poprzednie ustawienie menedżera. Użyj '$null' aby usunąć menedżera.
Wymaga modułu Microsoft.Graph.Users i uprawnień User.ReadWrite.All.
.EXAMPLE
.\Simplified_UpdateManager.ps1
Uruchamia aktualizację na podstawie danych w skrypcie.
.EXAMPLE
.\Simplified_UpdateManager.ps1 -WhatIf
Pokazuje, jakie zmiany zostałyby wprowadzone, bez ich wykonywania.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param()

# --- DEFINIUJ UŻYTKOWNIKÓW I MENEDŻERÓW TUTAJ ---
# Format: @{UserPrincipalName = 'user@domain.com'; NewManagerPrincipalName = 'manager@domain.com' lub '$null'}
$usersToUpdate = @(
    @{UserPrincipalName = "user1@example.com"; NewManagerPrincipalName = "manager1@example.com"}
    @{UserPrincipalName = "user2@example.com"; NewManagerPrincipalName = "manager1@example.com"}
    @{UserPrincipalName = "user3@example.com"; NewManagerPrincipalName = '$null'} # Usuwa menedżera
    @{UserPrincipalName = "user4@example.com"; NewManagerPrincipalName = "manager2@example.com"}
    @{UserPrincipalName = "user5@example.com"; NewManagerPrincipalName = "director@example.com"}
    # Dodaj więcej użytkowników poniżej
)
# --- KONIEC DEFINICJI ---

# 1. Sprawdź/Zainstaluj moduł Microsoft.Graph.Users
if (-not (Get-Module -Name Microsoft.Graph.Users -ListAvailable)) {
    Write-Host "Moduł Microsoft.Graph.Users nie znaleziony, próba instalacji..." -ForegroundColor Yellow
    try {
        Install-Module Microsoft.Graph.Users -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
        Write-Host "Moduł zainstalowany." -ForegroundColor Green
    } catch {
        Write-Error "Błąd instalacji modułu Microsoft.Graph.Users. Zainstaluj go ręcznie."; return
    }
}

# 2. Połącz z Microsoft Graph (wymaga uprawnień User.ReadWrite.All)
Write-Host "Łączenie z Microsoft Graph..."
# Spróbuj połączyć; jeśli już połączono, nie rób nic; jeśli nie, poproś o login.
Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction SilentlyContinue
# Sprawdź, czy połączenie faktycznie istnieje
if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
    Write-Error "Nie udało się połączyć z Microsoft Graph. Sprawdź uwierzytelnienie i uprawnienia."; return
}
Write-Host "Połączono pomyślnie." -ForegroundColor Green

# 3. Przetwarzanie użytkowników
$total = $usersToUpdate.Count
$successCount = 0
$errorCount = 0
$i = 0

Write-Host "Rozpoczynanie przetwarzania $total użytkowników..."

foreach ($item in $usersToUpdate) {
    $i++
    $userUPN = $item.UserPrincipalName.Trim()
    $newManagerUPN = $item.NewManagerPrincipalName.Trim()

    # Podstawowa walidacja danych wejściowych
    if ([string]::IsNullOrWhiteSpace($userUPN) -or $null -eq $newManagerUPN -or ([string]::IsNullOrWhiteSpace($newManagerUPN) -and $newManagerUPN -ne '$null')) {
        Write-Warning "($i/$total) Pomijanie: Nieprawidłowe dane dla User '$userUPN' lub Manager '$newManagerUPN'."
        $errorCount++
        continue
    }
    if ($userUPN -eq $newManagerUPN) {
        Write-Warning "($i/$total) Pomijanie: Użytkownik '$userUPN' nie może być swoim własnym menedżerem."
        $errorCount++
        continue
    }

    # Główna logika z obsługą -WhatIf
    if ($PSCmdlet.ShouldProcess("Użytkownik '$userUPN'", "Aktualizacja menedżera (Nowy: '$newManagerUPN')")) {
        try {
            # Pobierz ID użytkownika
            $user = Get-MgUser -UserId $userUPN -ErrorAction Stop -Property Id
            if (-not $user) { throw "Nie znaleziono użytkownika '$userUPN'." }

            # Zdecyduj: Ustawienie czy usunięcie menedżera?
            if ($newManagerUPN -eq '$null') {
                # Usuń menedżera
                Write-Verbose " Usuwanie menedżera dla User ID $($user.Id)..."
                Remove-MgUserManagerByRef -UserId $user.Id -ErrorAction Stop
                Write-Host "($i/$total) OK: Usunięto menedżera dla $userUPN." -ForegroundColor Green
            } else {
                # Ustaw menedżera
                # Pobierz ID menedżera
                $manager = Get-MgUser -UserId $newManagerUPN -ErrorAction Stop -Property Id
                if (-not $manager) { throw "Nie znaleziono menedżera '$newManagerUPN'." }

                # Przygotuj ciało żądania dla API
                $managerRefBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($manager.Id)" }

                Write-Verbose " Ustawianie menedżera (ID: $($manager.Id)) dla User ID $($user.Id)..."
                Set-MgUserManagerByRef -UserId $user.Id -BodyParameter $managerRefBody -ErrorAction Stop
                Write-Host "($i/$total) OK: Ustawiono menedżera dla $userUPN na $newManagerUPN." -ForegroundColor Green
            }
            $successCount++
        } catch {
            # Obsługa błędów dla danego użytkownika
            Write-Error "($i/$total) BŁĄD przetwarzania '$userUPN': $($_.Exception.Message)"
            $errorCount++
        }
    } else {
         # Komunikat, gdy użyto -WhatIf lub anulowano
         Write-Warning "($i/$total) Pominięto aktualizację dla '$userUPN' (-WhatIf aktywny?)."
         # Nie zwiększamy $errorCount, bo to nie błąd, tylko świadome pominięcie
    }
}

# 4. Podsumowanie
Write-Host "`n--- Zakończono ---"
Write-Host "Przetworzono: $total"
Write-Host "Sukcesów: $successCount"
Write-Host "Błędów/Pominięto (bez -WhatIf): $errorCount"

# Opcjonalnie rozłącz sesję
# Disconnect-MgGraph