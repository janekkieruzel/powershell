# Ścieżka bazowa (gdzie są foldery wymienione w tabeli)
$BasePath = "C:\SharedData\"

# Mapowanie: kto → foldery, wstawione powyżej
$UserFolders = @{
  # 'user1'  = @('FOLDER1', 'FOLDER2')
  # 'group1' = @('FOLDER2','FOLDER3','FOLDER2','FOLDER1')
  # 'group2' = @('FOLDER2','FOLDER3','FOLDER2','FOLDER1')
  'Department1' = @('FOLDER1','FOLDER2','FOLDER3','FOLDER4')
  #'Department2' = @('FOLDER1')
  #'Department3' = @('FOLDER1', 'FOLDER2', 'FOLDER3')
  #'Department4' = @('FOLDER4', 'FOLDER3')
  #'user2' = @('FOLDER4','FOLDER3', 'FOLDER2', 'FOLDER1')
}

# Dla pewności ładujemy moduł w razie potrzeby (zwłaszcza jeśli to Windows Server lub lokal z RSAT).
# Import-Module ActiveDirectory

foreach ($Principal in $UserFolders.Keys) {
    # Wyciągamy listę folderów przypisanych danemu użytkownikowi/grupie/departamentowi
    $Folders = $UserFolders[$Principal]

    # (opcjonalnie) usuwamy duplikaty w tablicy:
    $Folders = $Folders | Sort-Object -Unique

    Write-Host "========== Ustawiam ACL dla obiektu '$Principal' ==========`n"

    foreach ($FolderName in $Folders) {
        # Pełna ścieżka do folderu
        $FullPath = Join-Path $BasePath $FolderName

        # Sprawdzamy, czy folder istnieje
        if (Test-Path $FullPath) {
            Write-Host "Przetwarzanie: $FullPath"

            # Pobierz bieżący ACL
            $acl = Get-Acl -Path $FullPath

            # Definiujemy prawa "Modify" + dziedziczenie na pliki i podfoldery
            $FileSystemRights  = [System.Security.AccessControl.FileSystemRights]"Modify"
            $InheritanceFlags  = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
            $PropagationFlags  = [System.Security.AccessControl.PropagationFlags]"None"
            $AccessRuleType    = [System.Security.AccessControl.AccessControlType]"Allow"

            # Nowa reguła
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Principal, 
                $FileSystemRights, 
                $InheritanceFlags, 
                $PropagationFlags, 
                $AccessRuleType
            )

            # Dodajemy regułę do ACL
            $acl.AddAccessRule($rule)

            # Zapisujemy ACL w systemie plików
            Set-Acl -Path $FullPath -AclObject $acl

            Write-Host "→ Nadano obiektowi '$Principal' uprawnienia 'Modify' (z dziedziczeniem) do: $FolderName`n"
        }
        else {
            Write-Warning "Folder '$FullPath' nie istnieje, pomijam."
        }
    }
    Write-Host "`n"
}

Write-Host "=== ZAKOŃCZONO nadawanie uprawnień według mapy ==="


