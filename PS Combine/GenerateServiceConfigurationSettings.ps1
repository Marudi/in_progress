[CmdLetBinding()]
param(
	[parameter(Mandatory=$true)]
	[string]$environmentName
,	[parameter(Mandatory=$true)]
	[string]$applicationPackagePath
,   [string]$targetInfrastructure
,   [string]$databaseServer
,   [string]$databaseUser
,   [string]$databasePwd
)

[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | Out-Null

$before = Get-Variable

# custom vars ### CODE_REVIEW: Parametrize it !!!
$IsHTTPS = "true"
$RedisConnectionString = "10.80.1.190"
$ApplicationInsights__InstrumentationKey= "849449c4-8fa6-45c1-97a7-577e66609572"
$ApplicationInsights__APIKey= "lfkyqhnjbs6fk6446g8yfxfqo82vn43r7g23wnlh"
$ApplicationInsights__ApplicationId= "98eadfe7-c9bd-42a7-9c73-15ee0ac0a699"
# end of custom vars

$after = Get-Variable -Exclude before

. $PSScriptRoot\lib\AppSettingsOverrideFunctions.ps1

$workingDirectory = "$PSScriptRoot\workdirectory"
New-Item $workingDirectory -ItemType Directory -Force | Out-Null

$sourceCodeZip = "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.Origin.zip"
if(-Not (Test-Path $sourceCodeZip))
{
    Copy-Item "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.zip" $sourceCodeZip | Out-Null
}

if(Test-Path $workingDirectory\code) {
    Remove-Item $workingDirectory\code -Recurse -Force | Out-Null
}
Copy-Item $sourceCodeZip $workingDirectory\code.zip | Out-Null

##############################
#Unzip the file
#############################
[System.IO.Compression.ZipFile]::ExtractToDirectory("$workingDirectory\code.zip", "$workingDirectory\code")
Remove-Item $workingDirectory\code.zip | Out-Null

Write-Host "Generating Configuration Service files ... "
$releaseConfigFile = "$workingDirectory\Code\ConfigurationFiles\Release"

$tempFolder = "$workingDirectory\_temp"
New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null

##########################################
# Apply replacement variables...
##########################################
Write-Host "    Applying replacement variables ... "
$variables = Compare-Object $after $before -Property Name | Select-Object -ExpandProperty Name

$files = Get-ChildItem -Path $releaseConfigFile\NG\AppSettings -Filter *.appsettings.json -Recurse
$files | ForEach-Object {
    $file = $_
	$fileContent = Get-Content $file.FullName
	foreach ($variable in $variables)
	{
		$fileContent = $fileContent.Replace("__$($variable)__", (Get-Variable $variable).Value)
	}
	#overwrite file => save as UTF8
	$fileContent | Out-File $file.FullName -Encoding UTF8 -Force
}

#############################################
# Generate AppSettings Configuration files
#############################################
write-host "Generate AppSettings configuration files..."
ConstructAppSettings -sourceConfigPath "$releaseConfigFile\NG" `
					 -infrastructureTarget $targetInfrastructure `
					 -outPath "$tempFolder\AppSettings" | Out-Null

if(Test-Path -Path "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG") {
	Write-Host "Replacement for $environmentName NG Application Settings..."
	ConstructAppSettings -sourceConfigPath "$tempFolder\AppSettings" `
						 -infrastructureTarget $targetInfrastructure `
						 -overrideConfigPath "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG" `
						 -outPath "$tempFolder\AppSettings" | Out-Null
}

Copy-Item "$workingDirectory\Code\ConfigurationFiles\Release\NG" "$workingDirectory\Code\ConfigurationFiles\$environmentName" -Recurse -Force | Out-Null
Remove-Item "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG\AppSettings" -Recurse -Force | Out-Null
Copy-Item "$tempFolder\AppSettings" "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG\AppSettings" -Recurse -Force | Out-Null

Get-ChildItem $workingDirectory\Code\ConfigurationFiles -Exclude "$environmentName" | Remove-Item -Recurse -force  | Out-Null

[System.IO.Compression.ZipFile]::CreateFromDirectory("$workingDirectory\Code", "$workingDirectory\Code.zip") 
Copy-Item "$workingDirectory\Code.zip" "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.zip" -Force | Out-Null
Remove-Item $workingDirectory -Recurse -Force | Out-Null