param(
  [Parameter(Mandatory=$true)]
  [string]$Bucket
)

$Source = "\\192.168.8.30\arch"

if (-not (Test-Path $Source)) {
  throw "Source not found: $Source"
}

aws s3 sync $Source "s3://$Bucket/arch" --only-show-errors

if ($LASTEXITCODE -ne 0) {
  throw "aws s3 sync failed"
}

Write-Host "Migration completed: $Source -> s3://$Bucket/arch"
