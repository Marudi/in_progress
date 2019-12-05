Write-Host "Stop NG Windows Services"
Get-Service | Where-Object { $_.DisplayName -like "NG*" } | ForEach-Object { 
    Write-Output "Stopping $($_.name) ..."
    Stop-Service $_.name 

    Write-Output "Removing $($_.name)..."
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='$($_.name)'"
    $service.delete()
}