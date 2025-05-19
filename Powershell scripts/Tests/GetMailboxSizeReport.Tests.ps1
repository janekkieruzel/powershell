BeforeAll {
    # Mock ExchangeOnlineManagement module
    Mock Import-Module { return $true }
    
    # Enhanced Exchange Online Module check
    Mock Get-Module {
        return @{
            Name = 'ExchangeOnlineManagement'
            Version = '3.0.0'
            count = 1
        }
    } -ParameterFilter { $Name -eq 'ExchangeOnlineManagement' }

    # Mock all possible connection scenarios
    Mock Connect-ExchangeOnline {
        return @{
            ConnectionUri = "https://outlook.office365.com/powershell-liveid/"
            Authentication = "Basic"
            Authorization = "Bearer"
        }
    } -ParameterFilter { $UserName -ne $null }

    Mock Connect-ExchangeOnline {
        return @{
            ConnectionUri = "https://outlook.office365.com/powershell-liveid/"
            Authentication = "Certificate"
            Authorization = "Bearer"
        }
    } -ParameterFilter { $CertificateThumbprint -ne $null }

    Mock Connect-ExchangeOnline {
        return @{
            ConnectionUri = "https://outlook.office365.com/powershell-liveid/"
            Authentication = "Modern"
            Authorization = "Bearer"
        }
    }

    # Import the scripts after mocking
    . $PSScriptRoot\..\GetMailboxSizeReport.ps1
    . $PSScriptRoot\TestHelpers.ps1
}

Describe 'GetMailboxSizeReport' {
    BeforeEach {
        # Mock Exchange Online commands with parameter validation
        Mock Get-Mailbox {
            return @{
                UserPrincipalName = "user@example.com"
                RecipientTypeDetails = "UserMailbox"
                DisplayName = "Test User"
                PrimarySMTPAddress = "user@example.com"
                IssueWarningQuota = "49 GB (52,428,800,000 bytes)"
                ProhibitSendQuota = "50 GB (53,687,091,200 bytes)"
                ProhibitSendReceiveQuota = "50 GB (53,687,091,200 bytes)"
                ArchiveDatabase = $null
                ArchiveDatabaseGuid = "00000000-0000-0000-0000-000000000000"
                ArchiveGuid = "00000000-0000-0000-0000-000000000000"
            }
        } -ParameterFilter { $ResultSize -eq 'Unlimited' }

        Mock Get-MailboxStatistics {
            return @{
                TotalItemSize = "1.5 GB (1,610,612,736 bytes)"
                TotalDeletedItemSize = "200 MB (209,715,200 bytes)"
                ItemCount = 1000
                DeletedItemCount = 100
            }
        }
    }

    It 'Should connect to Exchange Online' {
        . main
        Should -Invoke Connect-ExchangeOnline -Times 1 -Exactly
    }

    It 'Should create a CSV file with UTF8 encoding' {
        . main
        $latestReport = Get-ChildItem -Path "." -Filter "MailboxSizeReport*.csv" | 
                       Sort-Object CreationTime -Descending | 
                       Select-Object -First 1
        
        $latestReport | Should -Not -BeNullOrEmpty
        $fileContent = Get-Content -Path $latestReport.FullName -Encoding UTF8 -Raw
        $fileContent | Should -Not -BeNullOrEmpty
        $fileContent | Should -BeLike "*user@example.com*"
    }

    AfterEach {
        # Cleanup test files
        Get-ChildItem -Path "." -Filter "MailboxSizeReport*.csv" | Remove-Item -Force
    }
}