Import-Module Pester

Describe "AddUsersWithOUstrukture.ps1" {

    # Setze globale Mocks für alle AD-Cmdlets
    BeforeAll {
        # Mocks für OU-Erstellung
        Mock -CommandName Get-ADOrganizationalUnit -MockWith { return @() }
        Mock -CommandName New-ADOrganizationalUnit

        # Mocks für Benutzer
        Mock -CommandName Get-ADUser -MockWith { return $null }
        Mock -CommandName New-ADUser

        # Mocks für Gruppen
        Mock -CommandName Get-ADGroup -MockWith { return @() }
        Mock -CommandName New-ADGroup

        # Mocks für Gruppenmitgliedschaft
        Mock -CommandName Add-ADGroupMember
    }

    Context "Beim Erstellen der OU-Struktur" {
        It "sollten OUs erstellt werden, wenn sie noch nicht existieren" {
            # Führe das Script aus
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            
            # Überprüfe, ob New-ADOrganizationalUnit für die ersten 4 OUs aufgerufen wurde
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Technotrans" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Versand-Abt" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Vertrieb-Abt" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Gefue-Abt" } -Exactly 1
            
            # Erstelle zusätzliche OUs
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Gruppen" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Clients" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "GL-Gruppen" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "DL-Gruppen" } -Exactly 1
        }
    }

    Context "Beim Anlegen der Benutzer" {
        It "sollten Benutzer erstellt werden, wenn sie nicht existieren" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Da $users drei Einträge enthält, sollte New-ADUser 3-mal aufgerufen werden
            Assert-MockCalled -CommandName New-ADUser -Exactly 3
        }
    }

    Context "Beim Erstellen der Gruppen und Zuweisen von Mitgliedschaften" {
        It "sollten lokale Domaenengruppen erstellt werden" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Teste, ob New-ADGroup mindestens einmal aufgerufen wurde
            Assert-MockCalled -CommandName New-ADGroup -ParameterFilter { $GroupScope -eq "DomainLocal" } -AtLeast -Times 1
        }

        It "sollten Benutzer den entsprechenden Gruppen hinzugefügt werden" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Teste, ob Add-ADGroupMember aufgerufen wurde
            Assert-MockCalled -CommandName Add-ADGroupMember -AtLeast -Times 1
        }
    }
}

Invoke-Pester -Output Detailed