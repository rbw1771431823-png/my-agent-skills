param(
    [string]$Root = "",
    [string]$ProjectProfilePath = ""
)
$ErrorActionPreference = "Stop"
$module = Join-Path $PSScriptRoot "directory-catalog-core.psm1"
try {
    Import-Module $module -Force -ErrorAction Stop
    $result = Invoke-DirectoryCatalogUpdate -Root $Root -ProjectProfilePath $ProjectProfilePath
    Write-Output "目录同步完成：新建 $($result.Created)，更新 $($result.Updated)，无变化 $($result.Unchanged)；覆盖目录 $($result.Directories)。"
} catch {
    [Console]::Error.WriteLine("目录更新失败：$($_.Exception.Message)")
    exit 1
}