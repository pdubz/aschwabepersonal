Rename-Computer andytest001-c
Restart-Computer
Add-Computer -DomainName "test.inforcloud.local" -OUPath 'OU=Storage,OU=Infrastructure,OU=Servers,DC=test,DC=inforcloud,DC=local'
tzutil.exe /s 'Eastern Standard Time'
gpupdate /force
Restart-Computer
