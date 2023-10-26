<#
NAME:  main.ps1
AUTHOR: AUDEON Baptiste
LASTEDIT: 20/06/2023
VERSION: 1.0.0
1.X.X Ajout d’une fonctionnalité

DESCRIPTION:c'est un script powershell qui permet de crée une VM avec tous l'environment pour MSSQL

Pre-requis:
- avoir le module powerCLI d'installer
- avoir le mdp du compte svc-ad_join
- changer les constence selon les serveurs 
- avoir un compte adm 
- changer la machine virtuel dans l'ad


LINK:
https://wikidsnt.intra.chu-nantes.fr/doku.php?id=dsn:infrastructure:exploitation_dsnt:2infra:bdd
https://4sysops.com/archives/managing-disks-with-powershell/
https://www.kittell.net/code/powershell-change-windows-cd-dvd-drive-letter/
https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser?view=windowsserver2022-ps
#>



# # # # # # # # # # # # # # # # # // contence // # # # # # # # # # # # # # # # # # # # # # #

# l'hote sur lequel je crée ma vm
$vmHost = ""

# le datastore sur lequel je crée ma vm
$myDatastore = ""

# serveur vcenter sur lequel je crée ma vm
$serveur = ""

# chemin de mon script de création de disque
$disk = "C:\Users\adm-baudeon\Desktop\VmMsSqlScript\DISK.ps1"

# chemin de mon script de configuration de la vm dans l'AD et domaine
$ad = "C:\Users\adm-baudeon\Desktop\VmMsSqlScript\AD.ps1"

# chemin de mon script de deploiement de MSSQL 
$MSSQL = ""

$destinationTemp = "C:\temp"

# # # # # # # # # # # # # # # # # // function // # # # # # # # # # # # # # # # # # # # # # #
# verifie si le script est lancer en admin
function admin  () {
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        # Relancer le script en tant qu'administrateur
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
}

# demander le nom de compte adm verifie si il y a "adm-""avec gestion d'erreur
function account  () {
    # demander le nom de compte SQL SVC/AGENT
    $AccountAdm = Read-Host -Prompt "rentrer un compte adm (ex:adm-dupond)"
    #verifie si il y a  "CHU-NANTES\svc""au debut de $AccountAdm redemande jusqu'a ce que ce soit bon
    while ($AccountAdm -notlike "adm-*") {
        $AccountAdm = Read-Host -Prompt "rentrer un compte adm (ex:adm-dupond)"
    }
    
    $global:Accountadm = $AccountAdm
}

function credlocal {
    # si le fichier credlocal.xml n'existe pas le creer
    if (-not (Test-Path "C:\temp\credlocal.xml")) {
        # Importer les informations d'identification depuis le fichier XML
        Write-Host -Prompt "entrée le compte admin local (Administrator) et le mot de passe des templates M_Win2022/M_Win2019"
        $credloc = (Get-Credential)
        $credloc | Export-Clixml -Path "C:\temp\credlocal.xml"
    }
    $Credentialloc = Import-CliXml -Path "C:\temp\credlocal.xml"
    $global:Credentialloc = $Credentialloc
}


# demande quel version d'os window utiliser propose deux templates avec gestion d'erreur
function choixwindow () {
    $choixTemplates = 0 
    # tant que choixISO n'est pas différent de 0
    while ($choixTemplates -eq 0) {
        # Demander quel fichier ISO utiliser
        Write-Host "1 = template window 2019"
        Write-Host "2 = template window 2022"
        $choixTemplates = Read-Host -Prompt "Quel window utiliser ?"
        # Vérifier le choix de l'utilisateur
        switch ($choixTemplates) {
            1 {
                Write-Host "M_Win2019"
                # Envoyer la variable $cheminISO en dehors de la fonction
                $global:templates = "M_Win2019"

            }
            2 {
                Write-Host "M_Win2022"
                # Envoyer la variable $cheminISO en dehors de la fonction
                $global:templates = "M_Win2022"
        
            }
            default {
                Write-Host "Choix incorrect."
                # Réinitialiser la variable $choixISO
                $choixTemplates = 0
            }
        }
    }
}

# demande les taille des disque et les stock dans un tableau avec gestion d'erreur
function TailleDisque {
    # les disques à créer
    $disquesTable = @("D", "E", "L", "S", "T")

    # tableau vide pour les tailles des disques
    $tailleTable = @(0, 0, 0, 0, 0)

    # taille du disque C
    Write-Host "Le disque C n'est pas réglable dans ce script, il est fixé dans le modèle."

    # demander la taille des disques
    for ($i = 0; $i -lt 5; $i++) {
        # tant que la taille  est pas plus petite que 1 et plus grand que 100
        while ($tailleTable[$i] -lt 1 -or $tailleTable[$i] -gt 100) {
            Write-Host "Taille du disque" $disquesTable[$i]
            $tailleTable[$i] = Read-Host "Entrez la taille du disque (entre 1 et 100)"
            $tailleTable[$i] = [int]$tailleTable[$i]
        }
 
    }
    $global:tailleTable = $tailleTable
}

# ajoute les dique brut à la vm avec leur taille stocker dans le tableau tailleTable
function configDisque {
    for ($i = 0; $i -lt 5; $i++) {
        # ajoute les avec les valeur demander dans le tableau tailleTable
        Get-VM $vm | New-HardDisk -CapacityGB $tailleTable[$i]  -Persistence persistent -Confirm:$false
    }
}
# attend que la machine est redemarrer pour jouer le srcript 
function attendre {
    write-host "wait restart..."
    Start-Sleep -s 30
}


# # # # # # # # # # # # # # # # # // debut // # # # # # # # # # # # # # # # # # # # # # # 

#verifie si le script est lancer en admin
admin

# demander le le compte admin local (Administrator) et le mot de passe des templates M_Win2022/M_Win2019 si jamais rentrée 
credlocal 

# demander compte adm un compte adm est un compte qui commence par "adm-" et possedant des droits dans le domaine
account

# demander le mot de passe adm
$PasswordAdm = Read-Host -Prompt "Mot de passe adm" -AsSecureString
# Convertir le SecureString en chaîne de caractères
$PasswordAdm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordAdm))

# Commande pour se connecter aux serveurs vCenter
Connect-VIServer -Server $serveur -User $AccountAdm -Password $PasswordAdm

# demander le mot de passe adm  taper le mot page sire2 laxmi 
$motDePasseSvc = Read-Host -Prompt "taper le Mot de passe compte ad_join chercher dans page sire2 laxmi" -AsSecureString
# Convertir le SecureString en chaîne de caractères
$motDePasseSvc = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($motDePasseSvc))

# verifier si les templates M_Win2019" et "M_Win2022" existe sur le serveur vcenter 
Get-Template -Name "M_Win2019" -Server $serveur
Get-Template -Name "M_Win2022" -Server $serveur

# demander le nom de la machine virtuelle
$vm = Read-Host -Prompt "nom de la machine virtuelle"
$Global:vm = $vm

# demande quel version d'os window utiliser propose deux templates avec gestion d'erreur
choixwindow

# demande la taille des 5 disques et les stock dans un tableau avec gestion d'erreur disque entre 0 et 100 go 
TailleDisque

# Créer une nouvelle machine virtuelle en utilisant un modèle
New-VM -Name $vm  -template $templates -Datastore $myDatastore  -VMHost $vmHost

# ajoute les disque brut à la vm avec leur taille stocker dans le tableau tailleTable
configDisque

# allume la machine virtuelle
Start-VM $vm

# envoyer le script disk sur la vm
Copy-VMGuestFile -Source $disk -Destination $destinationTemp -VM $vm -LocalToGuest -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password

# execute un scripte a l'aide invoke-vmscript qui va partitionner les disque et les formater
Invoke-VMScript -VM $vm -ScriptText "$destinationTemp\DISK.ps1" -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password -ScriptType Powershell

# execute un scripte a l'aide invoke-vmscript qui change son nom en celui de la vm
Invoke-VMScript $vm -ScriptText "Rename-Computer -NewName $vm -Force"  -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password -ScriptType Powershell

# restart la vm 
Restart-VMGuest $vm 

# attend que la machine est redemarrer plus 1er restart plus long car peux avoir des mise a jour
write-host "wait restart..."
Start-Sleep -s 120
        

# envoyer le script ad sur la vm 
Copy-VMGuestFile -Source $ad -Destination $destinationTemp -VM $vm -LocalToGuest  -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password 
# jouer le script ad sur la vm qui va ajouter la vm au domaine
Invoke-VMScript $vm -ScriptText "$destinationTemp\AD.ps1 -motDePasseSvc '$motDePasseSvc'"  -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password -ScriptType Powershell

# restart la vm 
Restart-VMGuest $vm 
attendre

# mettre le compte adm en administrateur local de la vm
Invoke-VMScript -VM $vm -ScriptText "Add-LocalGroupMember -Group Administrators -Member $AccountAdm" -GuestUser $Credentialloc.UserName -GuestPassword $Credentialloc.Password -ScriptType Powershell

# restart la vm  
Restart-VMGuest $vm 
attendre

# envoyer un fichier sur la vm sur le bureau du compte adm
Copy-VMGuestFile -Source $MSSQL -Destination $destinationTemp -VM $vm -LocalToGuest -GuestUser $AccountAdm  -GuestPassword $PasswordAdm

write-host "la machine est configurer !, connecter vous avec le compte $AccountAdm, le scripte 'MSSQLscript.ps1'ce trouve prêt à configurer le serveur MSSQL dans le répertoire $destinationTemp!"

# laisser le scripte ouvert après l'execution
pause

# # # # # # # # # # # # # # # # // fin // # # # # # # # # # # # # # # # # # # # # # # 




















