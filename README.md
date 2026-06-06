# Claude 桌面版一键汉化

> Claude Desktop 简体中文自然汉化修复包 - Windows 一键汉化工具

这是给 Windows 版 Claude Desktop 使用的本地汉化修复包，目标不是逐字直译，而是让 Claude Desktop 的界面文案更符合中国大陆用户的阅读习惯。

## 当前状态

- 已适配 Windows Store 版 Claude Desktop，例如 `Claude_*_x64__pzs8sxrjxfjjc`。
- 支持自动定位 Claude Desktop 的 `app\resources` 目录。
- 支持部署 `zh-CN.json` 和 `ion-dist\i18n\zh-CN.json`。
- 支持修补语言包覆盖不到的前端 JS 文案。
- 支持清理 Electron 缓存，避免旧英文文案继续显示。
- 已提供可双击运行的 WinForms 图形工具。

## 文件说明

- `portable\Fix-Claude-Desktop-ZhCN.ps1`：主修复脚本，自动定位、备份、部署汉化、修补 JS、清理缓存。
- `portable\zh-CN.json`：Claude Desktop 根资源目录使用的简体中文语言文件。
- `portable\frontend-zh-CN.json`：Claude Desktop 前端 i18n 使用的简体中文语言文件。
- `gui-legacy\ClaudeZhPatchTool.cs`：C# WinForms 图形工具源码。
- `gui-legacy\Claude汉化修复工具.exe`：已编译的图形修复工具。
- `dist\Claude汉化修复工具.exe`：桌面上的可运行版本。
- `.`：Codex skill 版本，包含脚本、资源和工具源码。

## 使用方法

### 图形工具

1. 双击 `Claude汉化修复工具.exe`。
2. Windows 弹出管理员权限确认时选择允许。
3. 点击“开始修复”。
4. 等待进度完成。
5. 完全退出并重新打开 Claude Desktop。

### PowerShell 脚本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File portable\Fix-Claude-Desktop-ZhCN.ps1
```

如需手动指定 Claude 的资源目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File portable\Fix-Claude-Desktop-ZhCN.ps1 -ClaudePath "C:\Program Files\WindowsApps\Claude_xxx\app\resources"
```

## 主要术语

- `Cowork` → `协作任务`
- 产品页签 `Code` → `代码开发`
- 一般语境 `Code` → `代码`
- `Artifact` → `产物`
- `Skill` → `技能`
- 用户可见的 `MCP` 相关入口 → `连接器` / `连接器服务器`
- `Claude Code` → 通常保留英文
- 模型用量单位 `token` → `词元`
- 认证或访问凭据中的 `token` → `令牌`
- `Inference configuration` → `模型服务设置`
- `Third-party inference` → `第三方模型服务`
- `Current streak` → `当前连续活跃`
- `Longest streak` → `最长连续活跃`
- `in / out / cache r / cache w` → `输入 / 输出 / 缓存读 / 缓存写`

## 统计面板书籍参考

统计面板中的书籍示例已改为中文用户更熟悉的作品。词元数按 `docs\中国经典名著清单.md` 中的口径估算：`1 汉字 ≈ 1.5 token`。

| 书名 | 约合词元 |
|:---|---:|
| 《茶馆》 | 48,000 |
| 《朝花夕拾》 | 150,000 |
| 《活着》 | 180,000 |
| 《球状闪电》 | 270,000 |
| 《围城》 | 375,000 |
| 《儒林外史》 | 540,000 |
| 《白鹿原》 | 750,000 |
| 《红楼梦》 | 1,095,000 |
| 《三体》 | 1,350,000 |
| 《天龙八部》 | 2,250,000 |

## 图形工具构建

图形工具使用 C# / .NET Framework WinForms 编写，原因是 Windows 通常自带 .NET Framework 编译环境，不需要额外安装 Python、Node.js 或打包运行时。

核心构建命令示例：

```powershell
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /target:winexe /platform:anycpu /optimize+ `
  /out:"dist\Claude汉化修复工具.exe" `
  /resource:"portable\Fix-Claude-Desktop-ZhCN.ps1,Fix-Claude-Desktop-ZhCN.ps1" `
  /resource:"portable\zh-CN.json,zh-CN.json" `
  /resource:"portable\frontend-zh-CN.json,frontend-zh-CN.json" `
  /reference:System.Windows.Forms.dll `
  /reference:System.Drawing.dll `
  /reference:Microsoft.CSharp.dll `
  "gui-legacy\ClaudeZhPatchTool.cs"
```

## 来源与声明

- 初始语言包思路和部分前端中文资源参考了公开 GitHub 项目 `javaht/claude-desktop-zh-cn`：https://github.com/javaht/claude-desktop-zh-cn
- 该项目说明其用途是 Claude Desktop 中文界面补丁，支持简体中文和繁体中文。
- 本工具在此基础上做了二次整理和自然化润色，包括 Windows Store 路径定位、权限处理、缓存清理、Claude 新版前端 chunk 修补、中文会话标题生成提示、统计面板书籍示例、用词统一和 WinForms 一键修复工具。
- 本工具与 Anthropic / Claude 官方无关，只是本地资源修补工具。
- 如果计划公开发布或再分发，请先核对上游项目的许可证和授权状态，并保留来源声明。

## 注意事项

- 修改前会备份目标文件。
- 不修改 `app.asar`，优先只改语言文件和必要的前端资源文件。
- Windows PowerShell 5.1 容易因编码导致中文 JSON 损坏，脚本中必须显式使用 UTF-8。
- Claude 更新后可能覆盖资源文件，届时重新运行修复工具即可。
- 如果界面仍有英文，先完全退出 Claude Desktop，再重新打开；必要时再次运行工具清理缓存。
