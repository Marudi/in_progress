﻿Configuration Main
{

Param ( [string] $nodeName, [string] $webDeployPackage, [string] $certStoreName, [string]  $certDomain)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName WebAdministration

# param( 
# [Parameter(Mandatory=$true)] 
# [ValidateNotNullorEmpty()] 
# [PSCredential]
# $storageCredential
# )
#
Node $nodeName
  {
   # This commented section represents an example configuration that can be updated as required.
    WindowsFeature WebServerRole
    {
      Name = "Web-Server"
      Ensure = "Present"
    }
    WindowsFeature WebManagementConsole
    {
      Name = "Web-Mgmt-Console"
      Ensure = "Present"
    }
    WindowsFeature WebManagementService
    {
      Name = "Web-Mgmt-Service"
      Ensure = "Present"
    }
    WindowsFeature ASPNet45
    {
      Name = "Web-Asp-Net45"
      Ensure = "Present"
    }
    WindowsFeature HTTPRedirection
    {
      Name = "Web-Http-Redirect"
      Ensure = "Present"
    }
    WindowsFeature CustomLogging
    {
      Name = "Web-Custom-Logging"
      Ensure = "Present"
    }
    WindowsFeature LogginTools
    {
      Name = "Web-Log-Libraries"
      Ensure = "Present"
    }
    WindowsFeature RequestMonitor
    {
      Name = "Web-Request-Monitor"
      Ensure = "Present"
    }
    WindowsFeature Tracing
    {
      Name = "Web-Http-Tracing"
      Ensure = "Present"
    }
    WindowsFeature BasicAuthentication
    {
      Name = "Web-Basic-Auth"
      Ensure = "Present"
    }
    WindowsFeature WindowsAuthentication
    {
      Name = "Web-Windows-Auth"
      Ensure = "Present"
    }
    WindowsFeature ApplicationInitialization
    {
      Name = "Web-AppInit"
      Ensure = "Present"
    }
    Script DownloadWebDeploy
    {
        TestScript = {
            Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        }
        SetScript ={
            $source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
            $dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Invoke-WebRequest $source -OutFile $dest
        }
        GetScript = {@{Result = "DownloadWebDeploy"}}
        DependsOn = "[WindowsFeature]WebServerRole"
    }
    Package InstallWebDeploy
    {
        Ensure = "Present"  
        Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.6"
        ProductId = "{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}"
        Arguments = "ADDLOCAL=ALL"
        DependsOn = "[Script]DownloadWebDeploy"
    }
    Service StartWebDeploy
    {                    
        Name = "WMSVC"
        StartupType = "Automatic"
        State = "Running"
        DependsOn = "[Package]InstallWebDeploy"
    } 
	 Install the IIS role 
		WindowsFeature IIS 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Server" 
		} 
		# Install the ASP .NET 4.5 role 
		WindowsFeature AspNet45 
		{ 
			Ensure          = "Present" 
			Name            = "Web-Asp-Net45" 
		}
		
		File DownloadPackage 
		{            	
			Ensure = "Present"              	
			Type = "Directory"             	
			SourcePath ="https://asplatformresources.blob.core.windows.net/deploymentfolder/NGFull"            	
			DestinationPath = "C:\NGFull"
			Recurse = $true
		}
	   
		## IIS URL Rewrite module download and install
		Package UrlRewrite
		{
			#Install URL Rewrite module for IIS
			DependsOn = "[WindowsFeature]WebServerRole"
			Ensure = "Present"
			Name = "IIS URL Rewrite Module 2"
			Path = "http://download.microsoft.com/download/6/7/D/67D80164-7DD0-48AF-86E3-DE7A182D6815/rewrite_2.0_rtw_x64.msi"
			Arguments = "/quiet"
			ProductId = "EB675D0A-2C95-405B-BEE8-B42A65D23E11"
		}

		# Download and install the web site and content
		Script DeployWebPackage
		{
			GetScript = {@{Result = "DeployWebPackage"}}
			TestScript = {$false}
			SetScript ={
				[system.io.directory]::CreateDirectory("C:\NGFull")
				$dest = "C:\NGFull" 
				Remove-Item -path "C:\NGFull" -Force -Recurse -ErrorAction SilentlyContinue
				Invoke-WebRequest $using:webDeployPackage -OutFile $dest
				Add-Type -assembly "system.io.compression.filesystem"
				[io.compression.zipfile]::ExtractToDirectory($dest, "C:\inetpub\wwwroot")

				## create 443 binding from the cert store
				$certPath = 'cert:\LocalMachine\' + $using:certStoreName				
				$certObj = Get-ChildItem -Path $certPath -DNSName $using:certDomain
				if($certObj)
				{
					New-WebBinding -Name "Default Web Site" -IP "*" -Port 80 -Protocol https					
					$certWThumb = $certPath + '\' + $certObj.Thumbprint 
					cd IIS:\SSLBindings
					get-item $certWThumb | new-item 0.0.0.0!80

					# Create URL Rewrite Rules
					cd c:
					Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webserver/rewrite/GlobalRules" -name "." -value @{name='HTTP to HTTPS Redirect'; patternSyntax='ECMAScript'; stopProcessing='True'}
					Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webserver/rewrite/GlobalRules/rule[@name='HTTP to HTTPS Redirect']/match" -name url -value "(.*)"
					Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webserver/rewrite/GlobalRules/rule[@name='HTTP to HTTPS Redirect']/conditions" -name "." -value @{input="{HTTPS}"; pattern='^OFF$'}
					Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/globalRules/rule[@name='HTTP to HTTPS Redirect']/action" -name "type" -value "Redirect"
					Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/globalRules/rule[@name='HTTP to HTTPS Redirect']/action" -name "url" -value "https://{HTTP_HOST}/{R:1}"
					Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/globalRules/rule[@name='HTTP to HTTPS Redirect']/action" -name "redirectType" -value "SeeOther"
				}				
			}
			DependsOn  = "[WindowsFeature]WebServerRole"
		}

		## configure IIS Rewrite rules 
		#Script ReWriteRules
		#{
		#	#Adds rewrite allowedServerVariables to applicationHost.config
		#	DependsOn = "[Package]UrlRewrite"
		#	SetScript = {
		#		$current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection | ?{$_.ElementTagName -eq "add"} | select -ExpandProperty name
		#		$expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
		#		$missing = $expected | where {$current -notcontains $_}
		#		try
		#		{
		#			Start-WebCommitDelay 
		#			$missing | %{ Add-WebConfiguration /system.webServer/rewrite/allowedServerVariables -atIndex 0 -value @{name="$_"} -Verbose }
		#			Stop-WebCommitDelay -Commit $true 
		#		} 
		#		catch [System.Exception]
		#		{ 
		#			$_ | Out-String
		#		}
		#	}
		#	TestScript = {
		#		$current = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection | select -ExpandProperty name
		#		$expected = @("HTTPS", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "REMOTE_ADDR")
		#		$result = -not @($expected| where {$current -notcontains $_}| select -first 1).Count
		#		return $result
		#	}
		#	GetScript = {
		#		$allowedServerVariables = Get-WebConfiguration /system.webServer/rewrite/allowedServerVariables | select -ExpandProperty collection
		#		return $allowedServerVariables
		#	}
		#}

		# Install SSL Certificate
		#Script DeployAppCert
  #      {
  #          SetScript =  {
		#	Import-PfxCertificate -FilePath \\XXXdemoad01\source\certs\MyWebAppCert.pfx -CertStoreLocation Cert:\LocalMachine\WebHosting
		#	}
  #          TestScript = "try { (Get-Item Cert:\LocalMachine\WebHosting\C534DFBFE8DB597F22320682F7BBFBA2611DC45A -ErrorAction Stop).HasPrivateKey} catch { `$False }"
  #          GetScript = {
		#		@{Ensure = if ((Get-Item Cert:\LocalMachine\WebHosting\C534DFBFE8DB597F22320682F7BBFBA2611DC45A -ErrorAction SilentlyContinue).HasPrivateKey) 
  #            {'Present'} 
  #            else {'Absent'}}
		#	  }
  #          DependsOn = "[WindowsFeature]WebServerRole"
  #      }

		# Copy the website content 
		File WebContent 
		{ 
			Ensure          = "Present" 
			SourcePath      = "C:\WebApp"
			DestinationPath = "C:\Inetpub\wwwroot"
			Recurse         = $true 
			Type            = "Directory" 
			DependsOn       = "[Script]DeployWebPackage" 
		}		
		
  }
}