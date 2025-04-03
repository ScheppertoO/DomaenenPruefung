try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Warning "ActiveDirectory Modul nicht verfügbar – Dummy-Implementierungen werden genutzt"
}

# Dummy-Implementierungen für AD-Cmdlets, falls diese nicht auf dem System vorhanden sind.
if (-not (Get-Command Get-ADOrganizationalUnit -ErrorAction SilentlyContinue)) {
    function Get-ADOrganizationalUnit { }
}
if (-not (Get-Command New-ADOrganizationalUnit -ErrorAction SilentlyContinue)) {
    function New-ADOrganizationalUnit { }
}
if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
    function Get-ADUser { }
}
if (-not (Get-Command New-ADUser -ErrorAction SilentlyContinue)) {
    function New-ADUser { }
}
if (-not (Get-Command Get-ADGroup -ErrorAction SilentlyContinue)) {
    function Get-ADGroup { }
}
if (-not (Get-Command New-ADGroup -ErrorAction SilentlyContinue)) {
    function New-ADGroup { }
}
if (-not (Get-Command Add-ADGroupMember -ErrorAction SilentlyContinue)) {
    function Add-ADGroupMember { }
}

Import-Module Pester

Describe "AddUsersWithOUstrukture.ps1" {

    # Setze globale Mocks für alle AD-Cmdlets
    BeforeAll {
        # Mocks für OU-Erstellung
        Mock -CommandName Get-ADOrganizationalUnit -MockWith { return @() } -DisableCommandValidation
        Mock -CommandName New-ADOrganizationalUnit -DisableCommandValidation

        # Mocks für Benutzer
        Mock -CommandName Get-ADUser -MockWith { return $null } -DisableCommandValidation
        Mock -CommandName New-ADUser -DisableCommandValidation

        # Mocks für Gruppen
        Mock -CommandName Get-ADGroup -MockWith { return @() } -DisableCommandValidation
        Mock -CommandName New-ADGroup -DisableCommandValidation

        # Mocks für Gruppenmitgliedschaft
        Mock -CommandName Add-ADGroupMember -DisableCommandValidation
    }

    Context "Beim Erstellen der OU-Struktur" {
        It "sollten OUs erstellt werden, wenn sie noch nicht existieren" {
            # Führe das Script aus
            . "C:\Users\kesch\Documents\GitHub\DomaenenPruefung\AddUsersWithOUstrukture.ps1"
            
            # Überprüfe, ob New-ADOrganizationalUnit für die ersten 4 OUs aufgerufen wurde
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Technotrans" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Versand-Abt" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Vertrieb-Abt" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Gefue-Abt" } -Exactly 1
            
            # Überprüfe, ob zusätzliche OUs erstellt wurden
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Gruppen" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "Clients" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "GL-Gruppen" } -Exactly 1
            Assert-MockCalled -CommandName New-ADOrganizationalUnit -ParameterFilter { $Name -eq "DL-Gruppen" } -Exactly 1
        }
    }

    Context "Beim Anlegen der Benutzer" {
        It "sollten Benutzer erstellt werden, wenn sie nicht existieren" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Angenommen, $users enthält 3 Einträge – prüfe, ob New-ADUser 3-mal aufgerufen wurde
            Assert-MockCalled -CommandName New-ADUser -Exactly 3
        }
    }

    Context "Beim Erstellen der Gruppen und Zuweisen von Mitgliedschaften" {
        It "sollten lokale Domaenengruppen erstellt werden" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Prüfe, ob New-ADGroup mindestens einmal mit GroupScope DomainLocal aufgerufen wurde
            Assert-MockCalled -CommandName New-ADGroup -ParameterFilter { $GroupScope -eq "DomainLocal" } -AtLeast -Times 1
        }
        It "sollten Benutzer den entsprechenden Gruppen hinzugefügt werden" {
            . "$PSScriptRoot\AddUsersWithOUstrukture.ps1"
            # Prüfe, ob Add-ADGroupMember aufgerufen wurde
            Assert-MockCalled -CommandName Add-ADGroupMember -AtLeast -Times 1
        }
    }
}

. "C:\Users\kesch\Documents\GitHub\DomaenenPruefung\AddUsersWithOUstrukture.ps1"
Invoke-Pester