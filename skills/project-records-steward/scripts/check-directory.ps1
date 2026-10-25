param(
    [string]$Root = "",
    [string]$ProjectProfilePath = ""
)
$ErrorActionPreference = "Stop"
$module = Join-Path $PSScriptRoot "directory-catalog-core.psm1"
try {
    Import-Module $module -Force -ErrorAction Stop
    $result = Invoke-DirectoryCatalogCheck -Root $Root -ProjectProfilePath $ProjectProfilePath
    if (-not $result.Passed) {
        Write-Output "目录检查失败：$($result.Errors.Count) 项问题。"
        foreach ($problem in $result.Errors) { Write-Output "- $problem" }
        exit 1
    }
    Write-Output "目录检查通过：$($result.Catalogs) 个目录文件，$($result.Items) 个直接子项，0 漏项，0 过期项，0 重复项，0 未完成说明。"
} catch {
    [Console]::Error.WriteLine("目录检查失败：$($_.Exception.Message)")
    exit 1
}