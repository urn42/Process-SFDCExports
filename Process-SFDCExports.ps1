$scriptName = $MyInvocation.MyCommand.Name.Replace(".ps1","")
$logFile = ".\logs\$scriptName.{0:yyyyMMdd}.log" -f (Get-Date)
$logDaysToKeep = 365

$tempFolder = "T:\sfdctemp"
$primaryArchive = "\\npi-bignas\ydrive\salesforce backup\"
$secondaryArchive = "\\qnas-10\public\salesforce backup archives\"
$archiveDaysToKeep = 21

#create log file and directory if they don't exist
New-Item $logFile -Type file -Force
Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Starting...")

#create folders if they don't exist
$tempFolder, $primaryArchive, $secondaryArchive | ForEach { if(!(Test-Path $_)) { New-Item -Path $_ -Force -ItemType directory }}

#download files to temp directory
Try {
    .\FuseIT.SFDC.DataExportConsole.exe /c:RAMConnection $tempFolder
}
Catch [system.exception] {
    Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Exception encountered trying to execute FuseIT SFDC Explorer: $($Error[0].Exception.Message)")
}

#copy to archive 1
Get-ChildItem $tempFolder -Filter *.zip | ForEach { 
    $destFileName = $primaryArchive+"SFDCExport.{0:yyyyMMdd}.$_" -f $_.CreationTime
    Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Copying $_ to $destFileName")
    Copy-Item $_.FullName -destination $destFileName -Force
}

#move to archive 2
Get-ChildItem $tempFolder -Filter *.zip | ForEach { 
    $destFileName = $secondaryArchive+"SFDCExport.{0:yyyyMMdd}.$_" -f $_.CreationTime
    Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Moving $_ to $destFileName")
    Move-Item $_.FullName -destination $destFileName -Force
}

#trim archives
$primaryArchive, $secondaryArchive | ForEach {
    Get-ChildItem $_ -Filter *.zip | ForEach {
        if (((Get-Date) - $_.CreationTime).Days -gt $archiveDaysToKeep) {
            Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Deleting $($_.FullName)")
            Remove-Item $_.FullName -Force
        }
    }
}

#clean own logs
Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Cleaning up own log files")
if ((Get-ChildItem ".\logs\" -Filter "$scriptName.*.log" | Where-Object { ((Get-Date) - $_.LastWriteTime).Days -gt $logDaysToKeep } ).Length -eq 0) {
    Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " No log files to delete")
}
else {
    Get-ChildItem ".\logs\" -Filter "$scriptName.*.log" | ForEach {
        if (((Get-Date) - $_.CreationTime).Days -gt $logDaysToKeep) {
            Add-Content $logFile -Value ((Get-Date -Format "yyyy-MM-dd hh:mm:ss") + " Deleting $($_.FullName)")
            Remove-Item $_.FullName -Force
        }
    }
}
