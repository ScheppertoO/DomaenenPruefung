# ========================================================================
# KONFIGURATIONS-VORLAGE FÜR DOMAIN-SETUP
# ========================================================================
# Diese Datei kann als Vorlage für verschiedene Umgebungen kopiert und angepasst werden

# BEISPIEL 1: Standard Technotrans Konfiguration
$StandardConfig = @{
    Domain = @{
        CompanyName = "Technotrans"
        DomainDN = "DC=Demo,DC=dom" 
        DomainSuffix = "@Demo.dom"
        DefaultPassword = "Password1"
    }
    
    Users = @(
        @{
            Name = "Ute Uber"
            FirstName = "Ute"
            LastName = "Uber"
            Department = "Versand"
            OUName = "Versand-Abt"
            Username = "ute.uber"
            FolderName = "Versand-Daten"
            FolderPermission = "Read"
            Permissions = @("DL-Versand-Daten-R")
        },
        @{
            Name = "Max Mitte"
            FirstName = "Max"
            LastName = "Mitte"
            Department = "Vertrieb"
            OUName = "Vertrieb-Abt"
            Username = "max.mitte"
            FolderName = "Vertrieb-Daten"
            FolderPermission = "Modify"
            Permissions = @("DL-Vertrieb-Daten-AE")
        },
        @{
            Name = "Olaf Oben"
            FirstName = "Olaf"
            LastName = "Oben"
            Department = "Geschaeftsfuehrung"
            OUName = "Gefue-Abt"
            Username = "olaf.oben"
            FolderName = "Gefue-Daten"
            FolderPermission = "Modify"
            Permissions = @("DL-Gefue-Daten-AE", "DL-Versand-Daten-R")
        }
    )
    
    FileServer = @{
        BasePath = "E:\Firmendaten"
        CreateFolders = $true
        CreateShares = $true
    }
    
    VPN = @{
        ServerAddress = "vpn.technotrans.com"
        PreSharedKey = "PreSharedKey123"
        CreateVPN = $false
    }
}

# BEISPIEL 2: Andere Firma
$AlternativeConfig = @{
    Domain = @{
        CompanyName = "MusterFirma"
        DomainDN = "DC=muster,DC=local"
        DomainSuffix = "@muster.local"
        DefaultPassword = "Start123!"
    }
    
    Users = @(
        @{
            Name = "Anna Admin"
            FirstName = "Anna"
            LastName = "Admin"
            Department = "IT"
            OUName = "IT-Abt"
            Username = "anna.admin"
            FolderName = "IT-Daten"
            FolderPermission = "Modify"
            Permissions = @("DL-IT-Daten-AE")
        },
        @{
            Name = "Bob Benutzer"
            FirstName = "Bob"
            LastName = "Benutzer"
            Department = "Marketing"
            OUName = "Marketing-Abt"
            Username = "bob.benutzer"
            FolderName = "Marketing-Daten"
            FolderPermission = "Read"
            Permissions = @("DL-Marketing-Daten-R")
        }
    )
    
    FileServer = @{
        BasePath = "D:\Unternehmensdaten"
        CreateFolders = $true
        CreateShares = $true
    }
    
    VPN = @{
        ServerAddress = "vpn.muster.local"
        PreSharedKey = "Muster2025!"
        CreateVPN = $true
    }
}

# ========================================================================
# VERWENDUNG:
# ========================================================================
# 1. Kopieren Sie eine der Konfigurationen oben
# 2. Passen Sie die Werte an Ihre Umgebung an
# 3. Fügen Sie die Konfiguration in Ihr Haupt-Skript ein
# 4. Oder verwenden Sie diese Datei mit Import-Konfiguration

# Beispiel für Import:
# $Config = $StandardConfig  # oder $AlternativeConfig
# $DomainConfig = $Config.Domain
# $UsersConfig = $Config.Users
# $FileServerConfig = $Config.FileServer
# $VPNConfig = $Config.VPN
