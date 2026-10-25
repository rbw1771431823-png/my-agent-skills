# 项目目录配置

项目配置把项目自己的名称、状态和说明留在项目里；通用工具只读取配置，不内置任何项目的事实或编号。没有配置文件时，工具使用中性的通用文字，不需要Git、TASK或特定文件夹名称。

本文件是JSON格式（方便查看和修改的结构化文字）。如需项目专属目录描述、状态或排除规则，复制Skill包中的 assets/directory-profile.example.json 到项目自己的说明/配置位置，填写后通过 ProjectProfilePath 使用。不要把项目专属内容放进通用Skill或示例。

## 主要字段

| 字段 | 用途 |
|---|---|
| schemaVersion | 必须为1，用来识别当前配置格式。 |
| profileName | 配置名称，供人辨认，不会写进目录页。 |
| rootTitle / titleSuffix | 根目录标题和标题后缀；rootTitle留空时使用根文件夹名。 |
| rootPurpose | 根目录用途说明。 |
| rootParentLine / childParentLine | 根目录和子目录的上级导航提示。 |
| statusRules | 给文件或文件夹标注项目自定义状态。 |
| descriptionRules | 按名称、路径或类型给项目文件写说明；按规则优先级取第一个匹配项。 |
| descriptionByExtension / descriptionDefault | 未命中特定规则的文件说明。 |
| folderDescriptionSuffix | 未单独说明的文件夹描述后缀。 |
| whenRules | 按名称、状态、扩展名或路径指定打开时机。 |
| folderPurposeRules | 子目录页顶部的用途说明。根目录使用 rootPurpose。 |
| folderPurposeFallback | 子目录没有命中用途规则时，使用 generic 通用说明，或 description 复用该文件夹的描述。 |
| excludedDirectoryNames | 追加需要跳过的目录名称。通用工具默认排除常见版本控制、开发和缓存目录。 |
| excludedNamePatterns | 追加需要跳过的文件/目录名称正则表达式（按名称匹配）。 |
| excludedFileExtensions | 追加需要跳过的文件扩展名，例如 .tmp。默认已排除 .pyc。 |
| unfinishedTextPatterns | 检查器要报告的项目专属未完成说明模式；不配置则不拦截任何文字。 |
| 目录文件名 | 固定为 _目录.md，所有目录页与子目录链接使用同一名称，不能在项目配置中改成其他文件名。 |
| lastSyncLabel / itemCountLabel / descriptionStatus | 目录页维护信息使用的项目文案。 |
| emptyDirectoryDescription / emptyDirectoryWhen | 空文件夹的显示说明和打开时机。 |

目录文件名固定为 _目录.md，目的是保证父子目录链接一致，并避免误把任意原文件当成目录页覆盖。若旧配置含 catalogFileName 字段，工具会在写入前明确报错；请删除该字段，保留约定文件名。

配置中的排除项是在通用默认排除项上追加。空、小或旧目录不是删除理由；排除只代表不列入导航，不会删除、移动或改写被排除内容。

## 匹配规则

每条规则包含 priority、when 和 value。priority数字小的先检查；数字相同时按配置中的出现顺序。when里的普通字段必须同时成立；allOf要求其中条件全部成立，anyOf要求至少一个成立。首个命中的规则生效。

支持的条件字段：

- isRoot：是否为指定项目根目录，值为 true/false。
- isDirectory：是否为文件夹，值为 true/false。
- directoryEmptyExceptCatalog：文件夹除目录文件外是否为空，值为 true/false。
- nameEquals、nameIn：名称精确匹配，单项或名称列表。
- nameRegex、nameWildcard：名称正则表达式或通配符。
- directoryNameEquals：文件夹名称精确匹配。
- extensionEquals、extensionIn：扩展名匹配，例如 .md。
- relativePathEquals、relativePathRegex、relativePathWildcard：相对于项目根目录的路径匹配。工具将反斜线统一为正斜线。
- statusEquals、statusIn：匹配前序规则得出的状态。

正则表达式按大小写不敏感方式匹配。未知字段、错误类型或无效正则会在更新前报配置错误，避免悄悄忽略拼写错误。配置错误不会写入目录。

规则形状示例：

~~~json
{
  "priority": 100,
  "when": {
    "allOf": [
      { "isDirectory": true },
      { "relativePathWildcard": "archive/*" }
    ]
  },
  "value": "historical"
}
~~~

## 示例配置

示例文件只含通用范例，没有现有项目名称、路径、业务状态或编号。它可以为空规则地运行；新项目也可以完全省略配置。