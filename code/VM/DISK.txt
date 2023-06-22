
# change CD/DVD Drive en A:
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' |
Select-Object -First 1 |
Set-WmiInstance -Arguments @{DriveLetter = 'A:' }

# initialize les disques
Get-Disk | Where-Object PartitionStyle -Eq 'RAW' | Initialize-Disk

# donne les lettres aux disques
$disquesTable = @("D", "E", "L", "S", "T")
for ($i = 1; $i -lt 6; $i++) {
  # crée les partitions donne la lettre et utilise la taille max
  New-Partition -DiskNumber $i -UseMaximumSize -DriveLetter $disquesTable[$i - 1]

  # formate les disques en ntfs
  Format-Volume -DriveLetter $disquesTable[$i - 1] -FileSystem NTFS -Confirm:$false

}

