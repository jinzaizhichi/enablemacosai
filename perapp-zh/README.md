# perapp-zh — 全局英文保资格,逐 App 中文界面

Apple 智能(含新 Siri)的资格判定读的是**用户全局** `AppleLanguages` / Siri 语言,而新 Siri 的语言白名单只有英文。
所以系统语言一旦切成中文,新 Siri 就会掉。本脚本反过来做:全局保持 English,把中文写进**每个 App 自己的偏好域**
(等价于「系统设置 → 通用 → 语言与地区 → 应用程序」逐个添加),eligibilityd 不读这些域,资格不受影响。

实测环境:macOS 27 beta,Apple Silicon。脚本要求 macOS ≥ 14、arm64。

## 用法

```bash
./perapp-zh.sh dry-run        # 只统计,不改任何东西
./perapp-zh.sh all            # pilot + apple + shell + widgets + settings
./perapp-zh.sh third-party    # /Applications 下含简中的第三方 App(范围大,单独开)
./perapp-zh.sh login          # 登录窗语言(系统级,需 sudo,单独开)
./perapp-zh.sh status         # 看当前应用了什么
./perapp-zh.sh check          # 复验资格:三项语言输入应为 3/3/3,GREYMATTER / AMERICIUM 应为 4
./perapp-zh.sh revert         # 一键回退以上全部
```

| 阶段 | 做什么 |
|---|---|
| `pilot` | Finder / Dock / 控制中心 / 菜单栏 |
| `apple` | `/System/Applications` 下含简中资源的自带 App(跳过 Apple 面板硬排除项与 Siri 相关) |
| `shell` | Spotlight / 通知中心 |
| `widgets` | 桌面与通知中心的 WidgetKit 小组件扩展(各自独立 bundle,写容器域后重启 chronod) |
| `settings` | 系统设置:面板扩展写中文 + 常驻代理(见下) |
| `third-party` | `/Applications` 下含简中资源的第三方 App |
| `login` | 登录窗语言(`/Library/Preferences/.GlobalPreferences`,需 sudo) |

语言列表自动推导:`zh-Hans-<AppleLocale 地区>` + 你现有的全局列表(去重),与 Apple 面板写法一致。
可用 `PERAPP_LANGS="zh-Hans-CN en-CN" ./perapp-zh.sh …` 覆盖。

## 系统设置为什么要代理

系统设置被 Apple 硬排除在逐 App 语言之外,持久化偏好它不读,只吃启动参数 `-AppleLanguages`。
`settings` 阶段安装一个 launchd 常驻代理(`SettingsZH.app`,无 Dock 图标):

1. 系统设置 willLaunch 时若命令行没带 `-AppleLanguages`,在窗口画出前结束并带参数重开(约 100 ms,无闪屏);带参数的实例放行。
2. 自身接管 `x-apple.systempreferences:` 深链接,收到后带参数转发,所以权限弹窗 / Spotlight / 控制中心打开的也是中文并落到目标面板。
3. 安全阀:60 秒内重开 4 次即暂停拦截 5 分钟。日志在 `~/Library/Logs/settings-zh-agent.log`。

Dock 里钉真正的「系统设置」即可,单图标。已知边界:AppleScript `reveal pane` 或直接打开 .mobileconfig 这类"先启动再送事件"的方式会丢事件,只落到默认面板。

## 回退与状态

所有改动都记录在 `~/Library/Application Support/perapp-zh/`:`manifest.txt`(改过哪些域)、`backup/`(每项的原值:
per-app 原语言、面板登记表、登录窗语言、深链接处理器;原本不存在的记为 `ABSENT`,回退时删键)。
`revert` 按记录逐项恢复原值、卸载代理、还原处理器、重启 Finder / Dock 等,全部成功后把记录归档到 `reverted-<时间>/`。
状态目录独立于脚本目录,删仓库也不丢。

## 注意

- **不要** `sudo ./perapp-zh.sh`(脚本会拒绝):它改的是当前用户偏好,需要提权的步骤自行 `sudo`。
- 不要在系统设置里把系统语言改成中文,那会直接丢新 Siri 资格;脚本从不改全局语言。
- 从未运行过的沙盒 App 没有容器,会被跳过;运行一次后再跑对应阶段即可。
- Siri / Apple 智能相关的 bundle(`com.apple.campo`、`com.apple.Siri` 等)脚本一律拒绝写入。

## 文件

| 文件 | 作用 |
|---|---|
| `perapp-zh.sh` | 主脚本 |
| `SettingsZH.app` | 预编译的系统设置代理(arm64,ad-hoc 签名) |
| `lshandler` | 预编译的 URL scheme 默认处理器查看 / 设置工具 |
| `settings-zh-agent.swift` / `lshandler.swift` / `SettingsZH-Info.plist` | 源码;缺预编译文件时脚本会用 `swiftc` 自动编译(需 Xcode Command Line Tools) |
