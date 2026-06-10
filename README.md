# RegionSpoof — 在国行 Mac(macOS 27)上开启完整 Apple 智能

一个极简内核扩展(kext),在 **IORegistry 源头**把设备区域码从 `CH/A` 改成 `LL/A`(美版),
让 MobileGestalt 对全系统每个进程都返回美版区域,从而在国行机
(本机 Mac15,9 / M3 Max / macOS 27 26A5353q)上启用**完整的 Apple Intelligence**——
端侧 + Private Cloud Compute 云端全功能(写作工具含语气改写、图乐园、Genmoji、
Foundation Models、ChatGPT 扩展)。

## 快速安装(一键,推荐)

```bash
sudo ./install.sh
```

脚本自动完成:检查 SIP / Apple Silicon、**移除会杀死 PCC 的 `amfi_get_out_of_my_way` boot-arg**、
安装 kext + 配置开机自启、加载并刷新 Apple 智能守护进程。首次会提示你去
「系统设置 → 隐私与安全性」点一次 **允许** 后重启。

```bash
sudo ./install.sh status      # 体检:SIP / AMFI / region / kext / 资格 一览
sudo ./install.sh uninstall   # 卸载,恢复原始区域
```

> 前提:SIP 已关闭(恢复模式里 `csrutil disable`)。脚本若检测到未关,会给出分步指引。

## 原理

- 资格门的根因:`MGGetStringAnswer("RegionCode") == "CH"` → Apple 智能被关。
- 该值**实时**来自 IORegistry `IOPlatformExpertDevice` 的 `region-info` 属性(`"CH/A"`),
  并非任何 plist 缓存(macOS 27 的 eligibilityd 基于 SwiftData 实时重算,旧的改 plist / 锁
  uchg 方法全部失效)。
- 本 kext 匹配 `IOPlatformExpertDevice`,在 `start()` 里
  `setProperty("region-info", "LL/A")` + `setProperty("country-of-origin", "USA")`
  —— 全系统进程从**源头**读到美版,资格 / 模型下发 / 前端 UI 自然一通百通,无需逐进程注入。

## 文件

| 路径 | 作用 |
|------|------|
| `install.sh` | **一键安装 / 卸载 / 体检脚本** |
| `src/RegionSpoof.cpp` | kext 源码(IOService,改 `region-info`) |
| `src/kmod_info.c` | kext 入口声明,提供链接必需的 `_kmod_info` 符号 |
| `src/Info.plist` | kext bundle 的 Info.plist(IOKitPersonalities 匹配 IOPlatformExpertDevice) |
| `BUILD.md` | 完整编译 / 链接命令 |
| `RegionSpoof.kext/` | 已编译好的 kext(arm64e,ad-hoc 签名) |
| `com.local.regionkext.plist` | LaunchDaemon,开机早期自动加载 kext 并刷新 AI 守护进程 |
| `region-kext-load.sh` | LaunchDaemon 调用的加载脚本 |

## 前置条件(Apple Silicon)

1. **SIP 关闭 + Permissive 安全模式 + 允许第三方 kext** —— 恢复模式(1TR)里 `csrutil disable`
   一条即可全设。
2. **AMFI 必须保持开启** —— `nvram boot-args` 里**不能**有 `amfi_get_out_of_my_way=1`。
   AMFI 一关,SEP 会拒绝给 Private Cloud Compute 出硬件证明(日志表现为
   `AppleKeyStore kIOReturnNotPermitted`),**云端 AI 全部失效**;端侧仍可用。
3. kext 首次加载需在 **系统设置 → 隐私与安全性** 里点 **Allow** 后重启。

## 手动安装(可选)

```bash
sudo cp -R RegionSpoof.kext /Library/Extensions/
sudo chown -R 0:0 /Library/Extensions/RegionSpoof.kext
sudo cp region-kext-load.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/region-kext-load.sh
sudo cp com.local.regionkext.plist /Library/LaunchDaemons/
sudo kmutil load -p /Library/Extensions/RegionSpoof.kext   # 首次提示去设置 Allow → 重启
```

## 验证

```bash
# region-info 应为 0x4c4c2f41 ("LL/A")
ioreg -ard1 -c IOPlatformExpertDevice | plutil -p - | grep region-info
# GREYMATTER 资格应为 4 (eligible)
sudo /usr/libexec/PlistBuddy -c 'Print :OS_ELIGIBILITY_DOMAIN_GREYMATTER:os_eligibility_answer_t' \
  /private/var/db/eligibilityd/eligibility.plist
```

## 卸载

```bash
sudo launchctl bootout system/com.local.regionkext 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.local.regionkext.plist /usr/local/bin/region-kext-load.sh
sudo rm -rf /Library/Extensions/RegionSpoof.kext
sudo kmutil unload -b com.local.RegionSpoof 2>/dev/null
# 重启即恢复原区域
```

## 已知边界(实测确认)

- **SIP 必须保持关闭(Permissive)。** 本 kext 是 ad-hoc 签名;切到 Reduced Security(SIP 开)
  会以 `Authenticating extension failed: Bad code signature` 拒绝它,区域退回 CH、AI 关闭。
  要在 SIP 开启下使用,必须用 **Apple Developer ID($99/年)** 给 kext 正经签名后再走
  Reduced Security。
- **PCC 云端功能(语气改写 / 图乐园)依赖 AMFI 开启。** 切勿添加
  `amfi_get_out_of_my_way` boot-arg。
- **"New Siri" 等候名单** 是 Apple 服务端分批下发,与本地改区域无关。
