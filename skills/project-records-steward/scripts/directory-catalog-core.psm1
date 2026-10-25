Set-StrictMode -Version 2.0
$script:DirectoryCatalogName = "_目录.md"
$script:DefaultExcludedDirectories = @(".git", ".codex", ".agents", "__pycache__", "node_modules", ".venv", ".cache")
$script:DefaultExcludedNamePatterns = @("__pycache__")
$script:DefaultExcludedFileExtensions = @(".pyc")
$script:AllowedProfileFields = @("schemaVersion","profileName","rootTitle","titleSuffix","rootPurpose","rootParentLine","childParentLine","lastSyncLabel","itemCountLabel","descriptionStatus","emptyDirectoryDescription","emptyDirectoryWhen","excludedDirectoryNames","excludedNamePatterns","excludedFileExtensions","unfinishedTextPatterns","defaultStatus","defaultWhenToOpen","folderDescriptionSuffix","folderPurposeFallback","descriptionDefault","descriptionByExtension","statusRules","descriptionRules","whenRules","folderPurposeRules")
$script:AllowedRulePredicates = @("isRoot","isDirectory","directoryEmptyExceptCatalog","nameEquals","nameIn","nameRegex","nameWildcard","directoryNameEquals","extensionEquals","extensionIn","relativePathEquals","relativePathRegex","relativePathWildcard","statusEquals","statusIn","allOf","anyOf")

function Get-DirectoryProfileValue {
    param($Profile,[string]$Name,$DefaultValue=$null)
    if($null -eq $Profile){return $DefaultValue}
    if($Profile -is [System.Collections.IDictionary]){if($Profile.Contains($Name)){return $Profile[$Name]};return $DefaultValue}
    $property=$Profile.PSObject.Properties[$Name]
    if($null -eq $property){return $DefaultValue}
    return $property.Value
}

function Get-DirectoryObjectPropertyNames {
    param($Object)
    if($null -eq $Object){return @()}
    if($Object -is [System.Collections.IDictionary]){return @($Object.Keys)}
    return @($Object.PSObject.Properties | ForEach-Object Name)
}

function Get-DirectoryProfileRawValue {
    param($Profile,[string]$Name,$DefaultValue=$null)
    if($null -eq $Profile){return ,$DefaultValue}
    if($Profile -is [System.Collections.IDictionary]){if($Profile.Contains($Name)){return ,$Profile[$Name]};return ,$DefaultValue}
    $property=$Profile.PSObject.Properties[$Name]
    if($null -eq $property){return ,$DefaultValue}
    return ,$property.Value
}
function Get-DirectoryProfileArray {
    param($Profile,[string]$Name,[string[]]$Defaults=@())
    $values=New-Object System.Collections.Generic.List[string]
    $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($value in $Defaults){if($null -ne $value -and $seen.Add([string]$value)){$values.Add([string]$value)}}
    $configured=Get-DirectoryProfileRawValue $Profile $Name $null
    if($null -ne $configured){
        if($configured -is [string]){throw "项目配置格式错误：$Name 必须是字符串列表。"}
        foreach($value in @($configured)){if($null -ne $value -and $seen.Add([string]$value)){$values.Add([string]$value)}}
    }
    return $values.ToArray()
}

function Test-DirectoryRegex {
    param([string]$Pattern)
    try{[void][regex]::new($Pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant);return $true}catch{return $false}
}

function Test-DirectoryRuleShape {
    param($When,[string]$ProfilePath,[string]$RulePath)
    if($null -eq $When){throw "项目配置格式错误：$ProfilePath 的 $RulePath 缺少 when 条件。"}
    $names=@(Get-DirectoryObjectPropertyNames $When)
    if($names.Count -eq 0){throw "项目配置格式错误：$ProfilePath 的 $RulePath 没有匹配条件。"}
    $leaves=@("isRoot","isDirectory","directoryEmptyExceptCatalog","nameEquals","nameIn","nameRegex","nameWildcard","directoryNameEquals","extensionEquals","extensionIn","relativePathEquals","relativePathRegex","relativePathWildcard","statusEquals","statusIn")
    foreach($name in $names){
        if($name -in @("allOf","anyOf")){
            $nested=Get-DirectoryProfileValue $When $name $null
            if($nested -isnot [array] -or @($nested).Count -eq 0){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 必须是非空条件列表。"}
            foreach($child in @($nested)){Test-DirectoryRuleShape $child $ProfilePath "$RulePath.$name"}
            continue
        }
        if($name -notin $leaves){throw "项目配置格式错误：$ProfilePath 的 $RulePath 使用了未知匹配字段 $name。"}
        $value=Get-DirectoryProfileRawValue $When $name $null
        if($name -in @("isRoot","isDirectory","directoryEmptyExceptCatalog")){
            if($value -isnot [bool]){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 必须是 true 或 false。"}
        }elseif($name -in @("nameIn","extensionIn","statusIn")){
            if($value -isnot [array] -or @($value).Count -eq 0){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 必须是非空字符串列表。"}
            foreach($part in @($value)){if($part -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 含有非文本值。"}}
        }else{
            if($value -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 必须是文本。"}
            if($name -in @("nameRegex","relativePathRegex") -and -not (Test-DirectoryRegex $value)){throw "项目配置格式错误：$ProfilePath 的 $RulePath.$name 不是有效的正则表达式。"}
        }
    }
}

function Assert-DirectoryProfile {
    param($Profile,[string]$ProfilePath)
    if($null -eq $Profile -or $Profile -is [array] -or $Profile -is [string]){throw "项目配置格式错误：$ProfilePath 顶层必须是一个JSON对象。"}
    foreach($name in @(Get-DirectoryObjectPropertyNames $Profile)){if($name -eq "catalogFileName"){throw "项目配置格式错误：目录文件名固定为 _目录.md；请从 $ProfilePath 删除 catalogFileName。"};if($name -notin $script:AllowedProfileFields){throw "项目配置格式错误：$ProfilePath 存在未知字段 $name。"}}
    if((Get-DirectoryProfileValue $Profile "schemaVersion" $null) -ne 1){throw "项目配置格式错误：$ProfilePath 的 schemaVersion 必须为 1。"}
    foreach($name in @("profileName","rootTitle","titleSuffix","rootPurpose","rootParentLine","childParentLine","lastSyncLabel","itemCountLabel","descriptionStatus","emptyDirectoryDescription","emptyDirectoryWhen","defaultStatus","defaultWhenToOpen","folderDescriptionSuffix","folderPurposeFallback","descriptionDefault")){
        $value=Get-DirectoryProfileRawValue $Profile $name $null
        if($null -ne $value -and $value -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 $name 必须是文本。"}
    }
    foreach($name in @("excludedDirectoryNames","excludedNamePatterns","excludedFileExtensions","unfinishedTextPatterns")){
        $value=Get-DirectoryProfileRawValue $Profile $name $null
        if($null -ne $value){
            if($value -isnot [array]){throw "项目配置格式错误：$ProfilePath 的 $name 必须是字符串列表。"}
            foreach($part in @($value)){
                if($part -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 $name 含有非文本值。"}
                if($name -in @("excludedNamePatterns","unfinishedTextPatterns") -and -not (Test-DirectoryRegex $part)){throw "项目配置格式错误：$ProfilePath 的 $name 含有无效正则表达式。"}
            }
        }
    }
    foreach($field in @("statusRules","descriptionRules","whenRules","folderPurposeRules")){
        $list=Get-DirectoryProfileRawValue $Profile $field @()
        if($null -eq $list){continue}
        if($list -isnot [array]){throw "项目配置格式错误：$ProfilePath 的 $field 必须是规则列表。"}
        $index=0
        foreach($rule in @($list)){
            $index++;$where="$field[$index]"
            $ruleFields=@(Get-DirectoryObjectPropertyNames $rule)
            if($ruleFields -notcontains "when" -or $ruleFields -notcontains "value"){throw "项目配置格式错误：$ProfilePath 的 $where 必须有 when 和 value。"}
            if((Get-DirectoryProfileValue $rule "value" $null) -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 $where.value 必须是文本。"}
            $priority=Get-DirectoryProfileValue $rule "priority" $null
            if($null -ne $priority -and ($priority -isnot [ValueType] -or $priority -is [bool])){throw "项目配置格式错误：$ProfilePath 的 $where.priority 必须是数字。"}
            Test-DirectoryRuleShape (Get-DirectoryProfileValue $rule "when" $null) $ProfilePath $where
        }
    }
    $map=Get-DirectoryProfileValue $Profile "descriptionByExtension" $null
    if($null -ne $map){foreach($name in @(Get-DirectoryObjectPropertyNames $map)){if((Get-DirectoryProfileValue $map $name $null) -isnot [string]){throw "项目配置格式错误：$ProfilePath 的 descriptionByExtension.$name 必须是文本。"}}}
}

function Initialize-DirectoryProfileRuntime {
    param($Profile)
    if($null -eq $Profile){return}
    $ruleCache=@{}
    foreach($field in @("statusRules","descriptionRules","whenRules","folderPurposeRules")){
        $list=@(Get-DirectoryProfileRawValue $Profile $field @())
        $ranked=New-Object System.Collections.Generic.List[object]
        for($i=0;$i -lt $list.Count;$i++){
            $priority=Get-DirectoryProfileValue $list[$i] "priority" (($i+1)*10)
            $ranked.Add([PSCustomObject]@{P=[double]$priority;I=$i;R=$list[$i]})
        }
        $ruleCache[$field]=@($ranked.ToArray() | Sort-Object P,I | ForEach-Object { $_.R })
    }
    $exclusionCache=@{
        excludedDirectoryNames=Get-DirectoryProfileArray $Profile "excludedDirectoryNames" $script:DefaultExcludedDirectories
        excludedNamePatterns=Get-DirectoryProfileArray $Profile "excludedNamePatterns" $script:DefaultExcludedNamePatterns
        excludedFileExtensions=Get-DirectoryProfileArray $Profile "excludedFileExtensions" $script:DefaultExcludedFileExtensions
        unfinishedTextPatterns=Get-DirectoryProfileArray $Profile "unfinishedTextPatterns" @()
    }
    $runtime=@{rules=$ruleCache;exclusions=$exclusionCache}
    $Profile | Add-Member -NotePropertyName "__directoryRuntime" -NotePropertyValue $runtime -Force
}

function Get-DirectoryRuntimeArray {
    param($Profile,[string]$Name,[string[]]$Defaults=@())
    $runtime=Get-DirectoryProfileValue $Profile "__directoryRuntime" $null
    if($null -ne $runtime){
        $exclusions=Get-DirectoryProfileValue $runtime "exclusions" $null
        if($null -ne $exclusions -and $exclusions.Contains($Name)){return $exclusions[$Name]}
    }
    return Get-DirectoryProfileArray $Profile $Name $Defaults
}
function Read-DirectoryProfile {
    param([string]$ProjectProfilePath="")
    if([string]::IsNullOrWhiteSpace($ProjectProfilePath)){$profile=[PSCustomObject]@{};Initialize-DirectoryProfileRuntime $profile;return $profile}
    $path=[IO.Path]::GetFullPath($ProjectProfilePath)
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "找不到项目目录配置：$path"}
    try{$profile=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)) -ErrorAction Stop}catch{throw "无法读取项目目录配置 $path：$($_.Exception.Message)"}
    Assert-DirectoryProfile $profile $path
    Initialize-DirectoryProfileRuntime $profile
    return $profile
}
function Resolve-DirectoryCatalogRoot {
    param([string]$Root="")
    if([string]::IsNullOrWhiteSpace($Root)){$Root=(Get-Location).Path}
    if(-not (Test-Path -LiteralPath $Root -PathType Container)){throw "找不到工作目录：$Root"}
    $item=Get-Item -LiteralPath $Root -Force
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "不跨越链接根目录：$($item.FullName)"}
    return [IO.Path]::GetFullPath($item.FullName)
}

function Get-DirectoryRelativePath {
    param([string]$Root,[string]$FullPath)
    $rootFull=[IO.Path]::GetFullPath($Root);$full=[IO.Path]::GetFullPath($FullPath)
    if($full.Equals($rootFull,[StringComparison]::OrdinalIgnoreCase)){return ""}
    $trimmed=$rootFull.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar))
    $prefix=$trimmed+[IO.Path]::DirectorySeparatorChar
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "路径不在指定工作目录内：$FullPath"}
    return $full.Substring($prefix.Length)
}

function Test-DirectoryExcludedName {
    param([string]$Name,$Profile)
    if((Get-DirectoryRuntimeArray $Profile "excludedDirectoryNames" $script:DefaultExcludedDirectories) -contains $Name){return $true}
    foreach($pattern in (Get-DirectoryRuntimeArray $Profile "excludedNamePatterns" $script:DefaultExcludedNamePatterns)){
        if([regex]::IsMatch($Name,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)){return $true}
    }
    return $false
}
function Test-DirectoryExcludedItem {
    param([System.IO.FileSystemInfo]$Item,$Profile)
    if(Test-DirectoryExcludedName $Item.Name $Profile){return $true}
    if(-not $Item.PSIsContainer -and (Get-DirectoryRuntimeArray $Profile "excludedFileExtensions" $script:DefaultExcludedFileExtensions) -contains $Item.Extension){return $true}
    return $false
}
function Get-DirectoryCatalogDirectories {
    param([string]$Root,$Profile)
    $result=New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $queue=New-Object 'System.Collections.Generic.Queue[System.IO.DirectoryInfo]'
    $queue.Enqueue((Get-Item -LiteralPath $Root -Force))
    while($queue.Count -gt 0){
        $directory=$queue.Dequeue()
        if(($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
            $relative=Get-DirectoryRelativePath $Root $directory.FullName
            if($relative){throw "不跨越链接目录：$relative"}
            throw "不跨越链接根目录：$($directory.FullName)"
        }
        $result.Add($directory)
        foreach($child in @(Get-ChildItem -LiteralPath $directory.FullName -Directory -Force)){
            if(Test-DirectoryExcludedName $child.Name $Profile){continue}
            $queue.Enqueue($child)
        }
    }
    $sorted=@($result.ToArray() | Sort-Object { $relative=Get-DirectoryRelativePath $Root $_.FullName; ($relative -split '[\\/]').Count } -Descending)
    return $sorted
}

function Get-DirectoryCatalogItems {
    param([System.IO.DirectoryInfo]$Directory,$Profile)
    $name=$script:DirectoryCatalogName
    $items=@(Get-ChildItem -LiteralPath $Directory.FullName -Force | Where-Object {$_.Name -ne $name -and -not (Test-DirectoryExcludedItem $_ $Profile)} | Sort-Object @{Expression={-not $_.PSIsContainer}},Name)
    return $items
}

function Get-DirectoryCatalogFileType {
    param([System.IO.FileSystemInfo]$Item)
    if($Item.PSIsContainer){return "文件夹"}
    if($Item.Extension){return $Item.Extension.TrimStart(".").ToUpperInvariant()}
    return "文件"
}

function Escape-DirectoryCatalogCell {
    param([string]$Text)
    if($null -eq $Text){return ""}
    return ($Text -replace '\|','\|' -replace '\r?\n',' ')
}

function Escape-DirectoryCatalogLabel {
    param([string]$Text)
    if($null -eq $Text){return ""}
    return ((Escape-DirectoryCatalogCell $Text) -replace '\[','\[' -replace '\]','\]')
}

function Get-DirectoryCatalogLinkName {
    param([string]$Name)
    return ($Name -replace '%','%25' -replace '#','%23' -replace '\?','%3F')
}

function Test-DirectoryRuleLeaf {
    param([string]$Name,$Value,[System.IO.FileSystemInfo]$Item,[string]$RelativePath,[string]$Root,$Profile,[string]$Status)
    $path=$RelativePath.Replace('\','/')
    switch($Name){
        "isRoot"{return (($Item.FullName.Equals($Root,[StringComparison]::OrdinalIgnoreCase)) -eq [bool]$Value)}
        "isDirectory"{return ($Item.PSIsContainer -eq [bool]$Value)}
        "directoryEmptyExceptCatalog"{
            if(-not $Item.PSIsContainer){return $false}
            $cat=$script:DirectoryCatalogName
            return (@(Get-ChildItem -LiteralPath $Item.FullName -Force | Where-Object {$_.Name -ne $cat}).Count -eq 0) -eq [bool]$Value
        }
        "nameEquals"{return [string]::Equals($Item.Name,[string]$Value,[StringComparison]::OrdinalIgnoreCase)}
        "nameIn"{foreach($v in @($Value)){if([string]::Equals($Item.Name,[string]$v,[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
        "nameRegex"{return [regex]::IsMatch($Item.Name,[string]$Value,[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)}
        "nameWildcard"{return ($Item.Name -like [string]$Value)}
        "directoryNameEquals"{return ($Item.PSIsContainer -and [string]::Equals($Item.Name,[string]$Value,[StringComparison]::OrdinalIgnoreCase))}
        "extensionEquals"{return [string]::Equals($Item.Extension,[string]$Value,[StringComparison]::OrdinalIgnoreCase)}
        "extensionIn"{foreach($v in @($Value)){if([string]::Equals($Item.Extension,[string]$v,[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
        "relativePathEquals"{return [string]::Equals($path,([string]$Value).Replace('\','/'),[StringComparison]::OrdinalIgnoreCase)}
        "relativePathRegex"{return [regex]::IsMatch($path,[string]$Value,[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)}
        "relativePathWildcard"{return ($path -like ([string]$Value).Replace('\','/'))}
        "statusEquals"{return [string]::Equals($Status,[string]$Value,[StringComparison]::OrdinalIgnoreCase)}
        "statusIn"{foreach($v in @($Value)){if([string]::Equals($Status,[string]$v,[StringComparison]::OrdinalIgnoreCase)){return $true}};return $false}
        default{return $false}
    }
}

function Test-DirectoryRuleWhen {
    param($When,[System.IO.FileSystemInfo]$Item,[string]$RelativePath,[string]$Root,$Profile,[string]$Status)
    if($null -eq $When){return $false}
    $matched=$false
    foreach($name in @(Get-DirectoryObjectPropertyNames $When)){
        $value=Get-DirectoryProfileRawValue $When $name $null
        if($name -eq "allOf"){$matched=$true;foreach($child in @($value)){if(-not (Test-DirectoryRuleWhen $child $Item $RelativePath $Root $Profile $Status)){return $false}};continue}
        if($name -eq "anyOf"){$any=$false;foreach($child in @($value)){if(Test-DirectoryRuleWhen $child $Item $RelativePath $Root $Profile $Status){$any=$true;break}};if(-not $any){return $false};$matched=$true;continue}
        if(-not (Test-DirectoryRuleLeaf $name $value $Item $RelativePath $Root $Profile $Status)){return $false}
        $matched=$true
    }
    return $matched
}

function Get-DirectoryRuleText {
    param($Profile,[string]$Field,[System.IO.FileSystemInfo]$Item,[string]$RelativePath,[string]$Root,$Fallback,[string]$Status="")
    $runtime=Get-DirectoryProfileValue $Profile "__directoryRuntime" $null
    $cache=if($null -ne $runtime){Get-DirectoryProfileValue $runtime "rules" $null}else{$null}
    if($null -ne $cache -and $cache.Contains($Field)){$rules=$cache[$Field]}else{$rules=@()}
    foreach($rule in $rules){
        if(Test-DirectoryRuleWhen (Get-DirectoryProfileValue $rule "when" $null) $Item $RelativePath $Root $Profile $Status){return [string](Get-DirectoryProfileValue $rule "value" "")}
    }
    return $Fallback
}
function Get-DirectoryCatalogStatus {
    param([System.IO.FileSystemInfo]$Item,[string]$Path,[string]$Root,$Profile)
    return Get-DirectoryRuleText $Profile "statusRules" $Item $Path $Root ([string](Get-DirectoryProfileValue $Profile "defaultStatus" "一般资料"))
}

function Get-DirectoryCatalogDescription {
    param([System.IO.FileSystemInfo]$Item,[string]$Path,[string]$Root,$Profile)
    $text=Get-DirectoryRuleText $Profile "descriptionRules" $Item $Path $Root $null
    if($null -ne $text){return $text}
    if($Item.PSIsContainer){return ($Item.Name+[string](Get-DirectoryProfileValue $Profile "folderDescriptionSuffix" "相关内容；打开此目录查看直接子项。"))}
    $map=Get-DirectoryProfileValue $Profile "descriptionByExtension" $null
    if($null -ne $map){foreach($prop in $map.PSObject.Properties){if($prop.Name -ne "default" -and [string]::Equals($Item.Extension,$prop.Name,[StringComparison]::OrdinalIgnoreCase)){return [string]$prop.Value}};$fallback=Get-DirectoryProfileValue $map "default" $null;if($null -ne $fallback){return [string]$fallback}}
    switch($Item.Extension.ToLowerInvariant()){
        ".md"{return "文档；具体事实和状态以文件正文为准。"}
        ".ps1"{return "维护脚本；执行前核对其用途和范围。"}
        ".json"{return "结构化配置或数据；使用前核对来源和用途。"}
        ".csv"{return "表格清单或核查记录。"}
        ".pdf"{return "PDF文件；打开后核对原文内容。"}
        default{return [string](Get-DirectoryProfileValue $Profile "descriptionDefault" "项目文件；打开文件查看具体内容。")}
    }
}

function Get-DirectoryCatalogWhenToOpen {
    param([System.IO.FileSystemInfo]$Item,[string]$Status,[string]$Path,[string]$Root,$Profile)
    return Get-DirectoryRuleText $Profile "whenRules" $Item $Path $Root ([string](Get-DirectoryProfileValue $Profile "defaultWhenToOpen" "需要处理或查找此项内容时打开。")) $Status
}

function Get-DirectoryCatalogFolderPurpose {
    param([System.IO.DirectoryInfo]$Directory,[string]$Path,[string]$Root,$Profile)
    if($Directory.FullName.Equals($Root,[StringComparison]::OrdinalIgnoreCase)){return [string](Get-DirectoryProfileValue $Profile "rootPurpose" "工作区根目录；本页列出它的直接内容。")}
    $text=Get-DirectoryRuleText $Profile "folderPurposeRules" $Directory $Path $Root $null
    if($null -ne $text){return $text}
    if((Get-DirectoryProfileValue $Profile "folderPurposeFallback" "generic") -eq "description"){return Get-DirectoryCatalogDescription $Directory $Path $Root $Profile}
    return "本文件夹用于导航其中的直接内容。"
}
function Get-DirectoryCatalogContent {
    param([System.IO.DirectoryInfo]$Directory,[System.IO.FileSystemInfo[]]$Items,[string]$Root,$Profile)
    $cat=$script:DirectoryCatalogName
    $path=Get-DirectoryRelativePath $Root $Directory.FullName
    $isRoot=$Directory.FullName.Equals($Root,[StringComparison]::OrdinalIgnoreCase)
    $rootTitle=Get-DirectoryProfileValue $Profile "rootTitle" ""
    if($isRoot -and -not [string]::IsNullOrWhiteSpace([string]$rootTitle)){$display=[string]$rootTitle}elseif($isRoot){$display=$Directory.Name;if([string]::IsNullOrWhiteSpace($display)){$display=$Directory.FullName}}else{$display=$Directory.Name}
    $suffix=Get-DirectoryProfileValue $Profile "titleSuffix" "｜目录"
    $rootParent=Get-DirectoryProfileValue $Profile "rootParentLine" "- 上级目录：无"
    $childParent=Get-DirectoryProfileValue $Profile "childParentLine" "- 上级目录：[返回上级目录](<../_目录.md>)"
    $footer=Get-DirectoryProfileValue $Profile "descriptionStatus" "已按通用规则生成；条目含义以其来源文件为准。"
    $emptyDescription=Get-DirectoryProfileValue $Profile "emptyDirectoryDescription" "本目录当前为空；请先核对用途，工具不会删除空目录。"
    $emptyWhen=Get-DirectoryProfileValue $Profile "emptyDirectoryWhen" "需要确认本目录内容或检查资料缺口时。"
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add("# $display$suffix");$lines.Add("");$lines.Add("<!-- catalog:v1 scope:direct-only -->");$lines.Add("")
    $lines.Add("## 本文件夹用途");$lines.Add("");$lines.Add((Get-DirectoryCatalogFolderPurpose $Directory $path $Root $Profile));$lines.Add("")
    $lines.Add("## 使用提示");$lines.Add("");$lines.Add("- 本页只列本文件夹的直接子项，不展开更深层内容。");$lines.Add("- 子文件夹请点击其名称，进入它自己的目录。")
    if($isRoot){$lines.Add($rootParent)}else{$lines.Add($childParent)}
    $lines.Add("");$lines.Add("## 直接子项");$lines.Add("");$lines.Add("| 名称 | 类型 | 状态 | 是什么 | 什么时候打开 |");$lines.Add("|---|---|---|---|---|")
    foreach($item in $Items){
        $relative=Get-DirectoryRelativePath $Root $item.FullName;$status=Get-DirectoryCatalogStatus $item $relative $Root $Profile
        $description=Get-DirectoryCatalogDescription $item $relative $Root $Profile;$when=Get-DirectoryCatalogWhenToOpen $item $status $relative $Root $Profile
        $type=Get-DirectoryCatalogFileType $item;$linkName=Get-DirectoryCatalogLinkName $item.Name
        if($item.PSIsContainer){$target="./$linkName/$cat"}else{$target="./$linkName"}
        $label=Escape-DirectoryCatalogLabel $item.Name
        $lines.Add("| [$label](<$target>) | $(Escape-DirectoryCatalogCell $type) | $(Escape-DirectoryCatalogCell $status) | $(Escape-DirectoryCatalogCell $description) | $(Escape-DirectoryCatalogCell $when) |")
    }
    if($Items.Count -eq 0){$lines.Add("| （无直接子项） | — | — | $(Escape-DirectoryCatalogCell $emptyDescription) | $(Escape-DirectoryCatalogCell $emptyWhen) |")}
    $lines.Add("");$lines.Add("## 维护状态");$lines.Add("")
    $syncLabel=Get-DirectoryProfileValue $Profile "lastSyncLabel" "最近更新";$countLabel=Get-DirectoryProfileValue $Profile "itemCountLabel" "直接子项数"
    $lines.Add("- "+$syncLabel+"：");$lines.Add("- "+$countLabel+"：$($Items.Count)（不含 $cat）");$lines.Add("- 说明状态："+$footer)
    $lines.Add("");$lines.Add("<!-- catalog-manifest:start -->")
    foreach($item in $Items){$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($item.Name));$lines.Add("<!-- catalog-item64:$encoded -->")}
    $lines.Add("<!-- catalog-manifest:end -->")
    return (($lines -join [Environment]::NewLine)+[Environment]::NewLine)
}
function Set-DirectoryCatalogTimestamp {
    param([string]$Content,[string]$Stamp,$Profile)
    $label=[string](Get-DirectoryProfileValue $Profile "lastSyncLabel" "最近更新")
    $pattern="(?m)^- $([regex]::Escape($label))：.*$"
    return [regex]::Replace($Content,$pattern,("- "+$label+"："+$Stamp),1)
}

function Invoke-DirectoryCatalogUpdate {
    param([string]$Root="",[string]$ProjectProfilePath="")
    $rootPath=Resolve-DirectoryCatalogRoot $Root
    $profile=Read-DirectoryProfile $ProjectProfilePath
    $directories=@(Get-DirectoryCatalogDirectories $rootPath $profile)
    $created=0;$updated=0;$unchanged=0
    $encoding=New-Object Text.UTF8Encoding($false)
    foreach($directory in $directories){
        $cat=$script:DirectoryCatalogName
        $catalogPath=Join-Path $directory.FullName $cat
        $items=@(Get-DirectoryCatalogItems $directory $profile)
        $existing=if(Test-Path -LiteralPath $catalogPath -PathType Leaf){[IO.File]::ReadAllText($catalogPath,[Text.Encoding]::UTF8)}else{""}
        $label=[string](Get-DirectoryProfileValue $profile "lastSyncLabel" "最近更新")
        $match=[regex]::Match($existing,"(?m)^- $([regex]::Escape($label))：(.+)$")
        if($match.Success){$stamp=$match.Groups[1].Value.Trim()}else{$stamp=[DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss",[Globalization.CultureInfo]::InvariantCulture)}
        $candidate=Set-DirectoryCatalogTimestamp (Get-DirectoryCatalogContent $directory $items $rootPath $profile) $stamp $profile
        $candidateCompare=[regex]::Replace($candidate,"\r\n?","\n").TrimEnd()
        $existingCompare=[regex]::Replace($existing,"\r\n?","\n").TrimEnd()
        if($candidateCompare -ceq $existingCompare){$unchanged++;continue}
        $now=[DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss",[Globalization.CultureInfo]::InvariantCulture)
        $candidate=Set-DirectoryCatalogTimestamp $candidate $now $profile
        [IO.File]::WriteAllText($catalogPath,$candidate,$encoding)
        if([string]::IsNullOrEmpty($existing)){$created++}else{$updated++}
    }
    return [PSCustomObject]@{Created=$created;Updated=$updated;Unchanged=$unchanged;Directories=$directories.Count}
}

function Get-DirectoryCatalogManifestItems {
    param([string]$Content,[string]$RelativePath,$Errors)
    $startMarker="<!-- catalog-manifest:start -->";$endMarker="<!-- catalog-manifest:end -->"
    $startCount=[regex]::Matches($Content,[regex]::Escape($startMarker)).Count
    $endCount=[regex]::Matches($Content,[regex]::Escape($endMarker)).Count
    if($startCount -ne 1 -or $endCount -ne 1){$Errors.Add("目录清单标记缺失或重复：$RelativePath");return @()}
    $start=$Content.IndexOf($startMarker,[StringComparison]::Ordinal);$end=$Content.IndexOf($endMarker,[StringComparison]::Ordinal)
    if($end -lt $start){$Errors.Add("目录清单标记顺序错误：$RelativePath");return @()}
    $manifest=$Content.Substring($start+$startMarker.Length,$end-$start-$startMarker.Length)
    $matches=[regex]::Matches($manifest,'<!-- catalog-item64:(.*?) -->')
    $rawCount=[regex]::Matches($manifest,'catalog-item64:').Count
    if($matches.Count -ne $rawCount){$Errors.Add("目录条目标记格式错误：$RelativePath")}
    $result=New-Object System.Collections.Generic.List[string]
    $strictUtf8=New-Object Text.UTF8Encoding($false,$true)
    foreach($item in $matches){
        try{$bytes=[Convert]::FromBase64String($item.Groups[1].Value);$result.Add($strictUtf8.GetString($bytes))}
        catch{$Errors.Add("目录条目标记编码无效：$RelativePath")}
    }
    return $result.ToArray()
}

function Test-DirectoryCatalogMarkers {
    param([string]$Content,[string]$RelativePath,$Errors)
    $marker="<!-- catalog:v1 scope:direct-only -->"
    $count=[regex]::Matches($Content,[regex]::Escape($marker)).Count
    if($count -ne 1){$Errors.Add("目录格式标记错误：$RelativePath")}
}

function Test-DirectoryCatalogFinishedText {
    param([string]$Content,[string]$RelativePath,$Profile,$Errors)
    foreach($pattern in (Get-DirectoryRuntimeArray $Profile "unfinishedTextPatterns" @())){
        if([regex]::IsMatch($Content,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)){$Errors.Add("存在未完成说明：$RelativePath")}
    }
}
function Test-DirectoryCatalogLink {
    param([string]$Content,[System.IO.FileSystemInfo]$Item,[string]$Root,$Profile,[string]$CatalogPath,$Errors)
    $cat=$script:DirectoryCatalogName
    $relative=Get-DirectoryRelativePath $Root $Item.FullName
    $name=Get-DirectoryCatalogLinkName $Item.Name
    if($Item.PSIsContainer){$target="./$name/$cat"}else{$target="./$name"}
    $expected="[$(Escape-DirectoryCatalogLabel $Item.Name)](<$target>)"
    if(-not $Content.Contains($expected)){$Errors.Add("目录链接错误：$CatalogPath → $relative")}
}

function Invoke-DirectoryCatalogCheck {
    param([string]$Root="",[string]$ProjectProfilePath="")
    $rootPath=Resolve-DirectoryCatalogRoot $Root
    $profile=Read-DirectoryProfile $ProjectProfilePath
    $directories=@(Get-DirectoryCatalogDirectories $rootPath $profile)
    $errors=New-Object System.Collections.Generic.List[string]
    $catalogCount=0;$itemCount=0
    $cat=$script:DirectoryCatalogName
    foreach($directory in $directories){
        $catalogPath=Join-Path $directory.FullName $cat
        $relativeCatalog=Get-DirectoryRelativePath $rootPath $catalogPath
        if(-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)){
            $display=if($relativeCatalog){$relativeCatalog}else{"."}
            $errors.Add("缺少目录文件：$display")
            continue
        }
        $catalogCount++
        $content=[IO.File]::ReadAllText($catalogPath,[Text.Encoding]::UTF8)
        Test-DirectoryCatalogMarkers $content $relativeCatalog $errors
        Test-DirectoryCatalogFinishedText $content $relativeCatalog $profile $errors
        $actual=@(Get-DirectoryCatalogItems $directory $profile | ForEach-Object Name | Sort-Object -CaseSensitive)
        $listed=@(Get-DirectoryCatalogManifestItems $content $relativeCatalog $errors | Sort-Object -CaseSensitive)
        $itemCount+=$actual.Count
        $actualSet=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $listedSet=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach($name in $actual){[void]$actualSet.Add([string]$name)}
        foreach($name in $listed){[void]$listedSet.Add([string]$name)}
        if(($actual -join [Environment]::NewLine) -cne ($listed -join [Environment]::NewLine)){
            $missing=@($actual | Where-Object {-not $listedSet.Contains([string]$_)})
            $stale=@($listed | Where-Object {-not $actualSet.Contains([string]$_)})
            if($missing.Count){$errors.Add("目录漏项：$relativeCatalog → $($missing -join '；')")}
            if($stale.Count){$errors.Add("目录过期项：$relativeCatalog → $($stale -join '；')")}
        }
        if($listed.Count -ne $listedSet.Count){$errors.Add("目录存在重复条目：$relativeCatalog")}
        foreach($name in $actual){
            $itemPath=Join-Path $directory.FullName $name
            if(-not (Test-Path -LiteralPath $itemPath)){$errors.Add("目录链接目标不存在：$(Get-DirectoryRelativePath $rootPath $itemPath)");continue}
            $item=Get-Item -LiteralPath $itemPath -Force
            Test-DirectoryCatalogLink $content $item $rootPath $profile $relativeCatalog $errors
            if($item.PSIsContainer){
                $childCatalog=Join-Path $item.FullName $cat
                if(-not (Test-Path -LiteralPath $childCatalog -PathType Leaf)){$errors.Add("子目录链接目标缺少 $cat：$(Get-DirectoryRelativePath $rootPath $item.FullName)")}
            }
        }
    }
    if($errors.Count -gt 0){return [PSCustomObject]@{Passed=$false;Errors=@($errors.ToArray());Catalogs=$catalogCount;Items=$itemCount}}
    return [PSCustomObject]@{Passed=$true;Errors=@();Catalogs=$catalogCount;Items=$itemCount}
}

Export-ModuleMember -Function Read-DirectoryProfile,Invoke-DirectoryCatalogUpdate,Invoke-DirectoryCatalogCheck