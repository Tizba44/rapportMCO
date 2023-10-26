param(
    [string]$motDePasseSvc
)

# Définir les informations de connexion
$utilisateur = "svc-ad_join@intra.chu-nantes.fr"

# Convertir le mot de passe en une chaîne sécurisée
$motDePasseSvcSecurise = ConvertTo-SecureString -String $motDePasseSvc -AsPlainText -Force

# Créer un objet Credential à partir des informations de connexion
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $utilisateur, $motDePasseSvcSecurise

# Rejoindre le domaine
Add-Computer -DomainName "intra.chu-nantes.fr" -Credential $credential 

