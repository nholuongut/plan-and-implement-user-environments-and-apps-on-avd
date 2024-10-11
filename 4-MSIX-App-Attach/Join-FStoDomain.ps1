# Change the execution policy to unblock importing AzFilesHybrid.psm1 module
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# Get the AzFilesHybrid from here: https://github.com/Azure-Samples/azure-files-samples/releases

# Navigate to where AzFilesHybrid is unzipped and stored and run to copy the files into your path
.\CopyToPSPath.ps1 

# Import AzFilesHybrid module
Import-Module -Name AzFilesHybrid

# Login with an Azure AD credential that has either storage account owner or contributor Azure role assignment
# If you are logging into an Azure environment other than Public (ex. AzureUSGovernment) you will need to specify that.
# See https://docs.microsoft.com/azure/azure-government/documentation-government-get-started-connect-with-ps
# for more information.
Connect-AzAccount

# Define parameters, $StorageAccountName currently has a maximum limit of 15 characters
$SubscriptionId = "SUB_ID"
$ResourceGroupName = "RG_NAME"
$StorageAccountName = "SA_NAME"
$DomainAccountType = "ComputerAccount" # Default is set as ComputerAccount
# If you don't provide the OU name as an input parameter, the AD identity that represents the storage account is created under the root directory.
$OuDistinguishedName = "OU=Azure Storage Accounts,DC=contosohq,DC=xyz"
# Specify the encryption algorithm used for Kerberos authentication. AES256 is recommended. Default is configured as "'RC4','AES256'" which supports both 'RC4' and 'AES256' encryption.
$EncryptionType = "AES256,RC4"

# Select the target subscription for the current session
Select-AzSubscription -SubscriptionId $SubscriptionId 

# Register the target storage account with your active directory environment under the target OU (for example: specify the OU with Name as "UserAccounts" or DistinguishedName as "OU=UserAccounts,DC=CONTOSO,DC=COM"). 
# You can use to this PowerShell cmdlet: Get-ADOrganizationalUnit to find the Name and DistinguishedName of your target OU. If you are using the OU Name, specify it with -OrganizationalUnitName as shown below. If you are using the OU DistinguishedName, you can set it with -OrganizationalUnitDistinguishedName. You can choose to provide one of the two names to specify the target OU.
# You can choose to create the identity that represents the storage account as either a Service Logon Account or Computer Account (default parameter value), depends on the AD permission you have and preference. 
# Run Get-Help Join-AzStorageAccountForAuth for more details on this cmdlet.

Join-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -DomainAccountType $DomainAccountType `
        -OrganizationalUnitDistinguishedName $OuDistinguishedName `
        -EncryptionType $EncryptionType

#Run the command below to enable AES256 encryption. If you plan to use RC4, you can skip this step.
Update-AzStorageAccountAuthForAES256 -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

# For MSIX App Attach go to the portal and assign permissions

#You can run the Debug-AzStorageAccountAuth cmdlet to conduct a set of basic checks on your AD configuration with the logged on AD user. This cmdlet is supported on AzFilesHybrid v0.1.2+ version. For more details on the checks performed in this cmdlet, see Azure Files Windows troubleshooting guide.
Debug-AzStorageAccountAuth -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -Verbose

# Get properties of the storage account for confirmation
$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

Write-Output $sa.AzureFilesIdentityBasedAuth.ActiveDirectoryProperties

# Set up NTFS permissions

# Get the storage key for the storage account
$keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName


# Get the UNC path from the file endpoint
$UNCPath = $sa.PrimaryEndpoints.File -replace ("https://","\\")
$UNCPath = $UNCPath -replace ("/","\")

$FileShareName = "msix-apps"

Write-Output "$UNCPath$FileShareName"

net use E: ($UNCPath + $FileShareName) $keys[0].Value /user:Azure\$StorageAccountName

# For MSIX App Attach
# Change the NTFS permissions to grant session hosts Modify access

# For FSLogix shares
# Run these from a standard command prompt
icacls E: /grant "FSLogixUsers@contosohq.xyz":(M)
icacls E: /grant "Creator Owner":(OI)(CI)(IO)(M)
icacls E: /remove "Authenticated Users"
icacls E: /remove "Builtin\Users"

# Use this value for the FSLogix install
$UNCPath + $FileShareName

# Script can be found on GitHub: https://raw.githubusercontent.com/DeanCefola/Azure-WVD/master/PowerShell/FSLogixSetup.ps1
# Copy script over to session host and run from an adminstrative PowerShell prompt
# 
