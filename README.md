# InjectCCDC
This inject does 

Backs up firewall rules,  
Enables firewall on all profiles & sets DefaultInbound = Block,  
Adds explicit Allow for TCP 80/443 (all profiles),  
Adds explicit Block for all other TCP (1–79, 81–442, 444–65535) and all UDP,  
Disables any other inbound allow rules.


BEFORE YOU RUN THIS PUT THESE CODE INTO POWERSHELL AS AN ADMINISTRATOR

Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools -All

Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole -All

Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All

Install-WindowsFeature Web-Server, Web-Mgmt-Tools, Web-Mgmt-Console

Import-Module WebAdministration


If you dont do this you will be an error saying 
"Web Administration Module not found. INstall IIS/Management Tools First."
