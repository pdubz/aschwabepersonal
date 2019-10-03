$files = @()
$files = Get-ChildItem -Path 'C:\users\aschwabe\Desktop\New folder'

foreach ($file in $files) {
    Write-S3Object -BucketName infor-prd-ncr-appdata-us-east-1 -Key "mssql/amsi/gold_databases/$file" -File $file.FullName 
}
