<#
NAME:  MSSQLscript.ps1
AUTHOR: AUDEON Baptiste
LASTEDIT: 18/06/2023
VERSION: 1.0.0
1.X.X Ajout d’une fonctionnalité

DESCRIPTION:
script d'installation/deploiements de Microsoft SQL Server 2019/2022

Pre-requis:
- avoir les droits de l'ad sur son compte adm 
- les disque sur la VM, voir wiki 
- se connecter sur la vm avec sont compte adm en administrateur
- crée compte service, voir wiki 

LINK:
 https://wikidsnt.intra.chu-nantes.fr/doku.php?id=dsn:infrastructure:exploitation_dsnt:2infra:bdd
 https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?redirectedfrom=MSDN&view=sql-server-ver16
 https://subscription.packtpub.com/book/shell/9781785283321/1/ch01lvl1sec11/installing-sql-server-using-powershell
#>

# # # # # # # # # # # # # # # # # // constante // # # # # # # # # # # # # # # # # # # # # # # 

# Chemin du fichier source ISO 2019
$cheminSourceISO2019 = ""

# Chemin du fichier source ISO 2022
$cheminSourceISO2022 = ""

# Chemin du fichier source INI 2019
$cheminSourceINI2019 = ""

# Chemin du fichier source INI 2022
$cheminSourceINI2022 = ""

# chemin du dossier a suprimer , crée bug 
$tempdbpath = "T:\MSSQL"

# # # # # # # # # # # # # # # # # // function // # # # # # # # # # # # # # # # # # # # # # #

# verifie si le script est lancer en admin
function admin  () {
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        # Relancer le script en tant qu'administrateur
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
}

# verifie si le dossier tempdb existe deja car il va empecher l'installation
function tempdb  () {
    # Vérifier si le dossier tempdb existe déjà
    if (Test-Path -Path $tempdbpath) {
        Write-Host "Le dossier T:\MSSQL\tempdb existe déjà il va empecher l'installation donc il va être supprimer."
        # suprimer le dossier T:\MSSQL
        Remove-Item -Path $tempdbpath -Force -Recurse
    } 
}


# demander le nom de compte SQL SVC/AGENT verifie si il y a "CHU-NANTES\svc""au debut de $account redemande jusqu'a ce que ce soit bon retourne $account
function account  () {
    # demander le nom de compte SQL SVC/AGENT
    $Account = Read-Host -Prompt "adresse et nom du compte SQL SVC/AGENT (ex: CHU-NANTES\svc-exemple)"
    #verifie si il y a  "CHU-NANTES\svc""au debut de $account redemande jusqu'a ce que ce soit bon
    while ($Account -notlike "CHU-NANTES\svc-*") {
        $Account = Read-Host -Prompt "adresse et nom du compte SQL SVC/AGENT commplète avec au début CHU-NANTES\svc-compte"
    }
    $global:Account = $Account
}


# demander quel fichier iso utiliser en proposant une liste de choix avec gestion d'erreur 
function choixISO () {
    $choixISO = 0 
    # tant que choixISO n'est pas différent de 0
    while ($choixISO -eq 0) {
        # Demander quel fichier ISO utiliser
        Write-Host "1 = SQL Server 2019"
        Write-Host "2 = SQL Server 2022"
        $choixISO = Read-Host -Prompt "Quel ISO utiliser ?"
        # Vérifier le choix de l'utilisateur
        switch ($choixISO) {
            1 {
                Write-Host "SQL Server 2019."
                # Envoyer la variable $cheminISO en dehors de la fonction
                $global:cheminISO = $cheminSourceISO2019
                $global:cheminINI = $cheminSourceINI2019

            }
            2 {
                Write-Host "SQL Server 2022."
                # Envoyer la variable $cheminISO en dehors de la fonction
                $global:cheminISO = $cheminSourceISO2022
                $global:cheminINI = $cheminSourceINI2022
            }
            default {
                Write-Host "Choix incorrect."
                # Réinitialiser la variable $choixISO
                $choixISO = 0
            }
        }
    }
}

# Vérifier si le fichier source existe 
function verifSource ($cheminSource) {
    # Vérifier si le fichier source existe
    if (Test-Path -Path $cheminSource) {
        Write-Host "Le fichier source existe : $cheminSource"
    }
    else {
        Write-Host "Le fichier source n'existe pas."
        exit
    }
}

#verifie si le fichier ISO existe et le monte sur un lecteur virtuel et met a jour le chemin du fichier d'installation
function monterISO {
    # Monter l'ISO sur un lecteur virtuel
    $virtualDrive = Mount-DiskImage -ImagePath $cheminISO -PassThru
        
    # Récupérer la lettre du lecteur virtuel
    $driveLetter = ($virtualDrive | Get-Volume).DriveLetter

    # Mettre à jour le chemin du fichier d'installation avec la lettre du lecteur virtuel
    $setupFilePath = "$driveLetter`:\setup.exe"
    Write-Host "Le chemin du fichier d'installation a été mis à jour : $setupFilePath"

    # Envoyer la variable $setupFilePath en dehors de la fonction
    $global:setupFilePath = $setupFilePath
}

# # # # # # # # # # # # # # # # # // debut // # # # # # # # # # # # # # # # # # # # # # # 

#verifie si le script est lancer en admin
admin

# verifie si le dossier tempdb existe deja car il va empecher l'installation
tempdb

# demander nom Instance
$Instance = Read-Host -Prompt "Nom Instance"

# demander le nom de compte SQL SVC/AGENT avec gestion d'erreur
account

# demander le Mot de passe SQL SVC/AGENT en crypter 
$Password = Read-Host -Prompt "Mot de passe SQL SVC/AGENT" -AsSecureString
# Convertir le SecureString en chaîne de caractères
$Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

# demander le Mot de passe SA
$SAPassword = Read-Host -Prompt "Mot de passe SA" -AsSecureString
$SAPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SAPassword))

# demander quel version de SQL Server utiliser avec gestion d'erreur
choixISO

# verif source avec comme parametre l'ISO
verifSource $cheminINI

# verif source avec comme parametre l'ISO
verifSource $CheminISO

#monte sur un lecteur virtuel 
monterISO

$command = "$setupFilePath /AGTSVCACCOUNT=`"$Account`" /SQLSVCACCOUNT=`"$Account`"  /INSTANCEID=`"$Instance`"  /INSTANCENAME=`"$Instance`"  /SQLSVCPASSWORD=`"$Password`" /AGTSVCPASSWORD=`"$Password`" /SAPWD=`"$SAPassword`" /ConfigurationFile=$($cheminINI)"

# commande qui lance l'installation avec les parametre
write-host $command

#joue la commande
Invoke-Expression -Command $command

write-host "l'installation est terminer"

# laisser le scripte ouvert après l'execution
pause

# # # # # # # # # # # # # # # # # // fin // # # # # # # # # # # # # # # # # # # # # # # 