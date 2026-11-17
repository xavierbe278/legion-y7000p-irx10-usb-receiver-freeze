# Legion Y7000P IRX10 · USB 外设兼容（DriverKit HID / HIDRM 卡死）

解决 **macOS 26 上某些 2.4G / 星闪（NearLink）无线接收器导致整机卡死**的问题。

> 实测机型：Lenovo Legion Y7000P IRX10（83NN，i9-14900HX，macOS 26.7.3，OpenCore 1.0.9）
> 触发设备：达尔优 **A980 Pro** 的星闪接收器（`260D:1131`，"Wireless Receiver"，TOGRAN 方案）

---

## 目录

- [0. 这个仓库里有什么](#0-这个仓库里有什么)
- [〇、涉及设备（型号与 ID）](#〇涉及设备型号与-id)
- [一、症状](#一症状非常误导人)
- [二、根因](#二根因)
- [三、解决方案](#三解决方案)
- [四、被排除的错误方向](#四被排除的错误方向省你几天时间)
- [五、快速自检脚本](#五快速自检脚本)
- [六、适用范围](#六适用范围)
- [七、真正的根因（最最终结论）](#七真正的根因2026-11-17-定位附-panic-栈)

## 0. 这个仓库里有什么

| 文件 | 用途 |
|---|---|
| `scripts/check-hidrm.sh` | 一条命令列出所有 HID 设备的 `HIDRMDeviceState`，标出处于 `Unknown` 的问题设备 |
| `patches/boot-args.txt` | `dk=0x0` / `dk=0x8001` 的含义与用法 |
| `configs/README.md` | 说明本问题**不需要** USB 端口映射 / `XHCIPortLimit` / 关机 SSDT |

> **隐私说明**：本仓库只含设备型号与 USB ID，不含序列号。


## 〇、涉及设备（型号与 ID）

| 角色 | 型号 | ID | 说明 |
|---|---|---|---|
| **问题设备（鼠标接收器）** | **达尔优 DAREU A980 Pro** 的 **星闪（NearLink）接收器** | Wi-Fi/HID：USB **`260D:1131`**<br>`USB Vendor Name = TOGRAN`<br>`Product = Wireless Receiver`<br>序列号 `20230725` | 复合 HID：鼠标 + 键盘 + **Digitizer/Touch Screen 集合** + 厂商自定义页（`0xFF00`），bcdDevice `0x290` |
| 对照设备（键盘接收器，正常） | 2.4G 无线键盘接收器 | USB **`3151:4017`**（`2.4G Wireless Keyboard`） | 标准键盘描述符，`BootProtocol = 1` |
| 主机控制器 | Intel Raptor Lake-HX xHCI | PCI **`8086:7A60`**，ACPI `\_SB.PC00.XHCI`，`_ADR 0x14` | 接收器实际落在 port 3/4（`@14300000` / `@14400000`） |
| 其他同总线设备 | ITE 8258（键盘 RGB）、Idea5003（联想 HID 桥）、USB2.1 Hub（`05E3:0610`）、Razer Nari Ultimate（`1532:051A`）、内置摄像头（`174F:246F`）、蓝牙（`0489:E10A`） | — | 均正常，与本次问题无关 |

> 现象与具体插在哪个 USB 口**无关**：机身 USB-A、Type-C 扩展坞、Hub 上都会复现。

## 一、症状（非常误导人）

接收器插着时，**三种卡死**：

| 操作 | 结果 |
|---|---|
| 晃动无线鼠标 | ❌ 立刻整机卡死（画面冻结，鼠标不动） |
| **热拔**接收器 | ❌ 一拔出就卡死 |
| 点菜单 **重启** | ❌ 卡死（**即使完全不动鼠标**） |
| 拔掉接收器 | ✅ 一切正常 |
| 换 USB 口 / 走 Type-C 扩展坞 / 走 Hub | ❌ 一样卡死 |
| 另一个 2.4G **键盘**接收器（`3151:4017`） | ✅ 完全正常 |

因为"不动鼠标也会在重启时卡"，很容易被误判成「触控板驱动问题 / 关机 SSDT 问题 / USB 端口映射问题」——本项目的一大价值就是**排除这些错误方向**。

---

## 二、根因

接收器被 macOS 26 的 **DriverKit HID（HIDRM，用户态 HID 驱动）** 接管，但**初始化从未完成**。

### 诊断命令

```sh
# 找到该设备的 HID 实例
ioreg -l -w0 -rc IOHIDDevice | grep -B8 -A14 '"VendorID" = 9741'   # 9741 = 0x260D
```

### 坏设备 vs 好设备

| 项目 | 鼠标接收器 `260D:1131`（坏） | 键盘接收器 `3151:4017`（好） |
|---|---|---|
| 驱动路径 | **DriverKit**：`AppleUserUSBHostHIDDevice` / `IOUserHIDDevice` | **内核 HID**：`BootProtocol = 1` |
| `HIDRMDeviceState` | **`"Unknown"`**（两个 HID 接口都是） | **无此属性** |
| `IOUserClasses` | `("AppleUserUSBHostHIDDevice","IOUserUSBHostHIDDevice","IOUserHIDDevice","IOHIDDevice",…)` | — |
| entitlement | `com.apple.developer.driverkit.family.hid.device` | `com.apple.developer.driverkit.transport.hid` |
| 报告描述符 | 鼠标 + **厂商自定义页 `0xFF00`** 多接口 | 标准键盘 |

`HIDRMDeviceState = "Unknown"` 意味着：内核把设备交给了用户态 DriverKit 进程，但那个进程从未报到"ready"。此后任何 HID 交互 / 拔插 / 关机拆栈，都会**死等一个永远不会来的响应**。

### 旁证：WindowServer 死循环

```
WindowServer: (IOKit) [com.apple.iohid:default] Connection added:   IOHIDEventSystemConnection uuid:9F52
WindowServer: (IOKit) [com.apple.iohid:default] Connection removed: IOHIDEventSystemConnection uuid:9F52
  caller = "libUniversalAccess.dylib: +[UAIOHIDUtilities _setIOHIDEventSystemClientValue:forProperty:error:]"
（20 ms 内重复 6 次，uuid 每次不同）
```

WindowServer 对一个"不响应的 HID 客户端"反复设置属性。

---

## 三、解决方案

### boot-args 加 `dk=0x0`

```
dk=0x0
```

效果：**关闭 DriverKit**，HID 退回传统内核驱动 `AppleUSBHIDDevice`。

实测结果（macOS 26.7.3）：

| 项目 | 结果 |
|---|---|
| 触控板 + 无线鼠标**同时使用** | ✅ |
| 热插拔接收器 | ✅ |
| 菜单重启 | ✅ |
| 键盘接收器 / 蓝牙 / 其他 USB | ✅ 未受影响 |

### 备选：`dk=0x8001`

如果 `dk=0x0` 导致某些设备异常，可改为：

```
dk=0x8001
```

它只关闭 **DriverKit entitlement 检查**，保留 DriverKit 本身。

> 来源：[Apple Developer Forums — How to enable DriverKit-specific entitlements checks](https://developer.apple.com/forums/thread/741594)（原文明确：*"you do NOT want to use `dk=0x0` as this turns off DriverKit altogether"*）

---

## 四、被排除的错误方向（省你几天时间）

以下都**试过并且无效**：

| 尝试 | 结果 |
|---|---|
| 做 USB 端口映射 / 换端口（前置、后置、Type-C 扩展坞、Hub） | ❌ 一样卡 |
| `USBToolBox` + `UTBDefault`（通用空壳映射） | ❌ 无效（且它们本身是"0 端口"的空壳） |
| `XHCIPortLimit` 补丁 | ❌ 无关（蓝牙在 port 14，未超限） |
| `SSDT-FixShutdown`（清 `XHCI.PMEE`，`_PTS` hook 正确实现） | ❌ 无关（对真正的 PMEE 型关机问题有效，但本问题不是） |
| 降低鼠标回报率（4000/2000/1000 → 125Hz） | ❌ 无关 |
| 禁用 `VoodooInput` / 去掉"通用鼠标"人格 / 各种 VoodooI2C 二进制补丁 | ❌ 无关（但触控板项目里的这些步骤对触控板本身有价值） |
| 换 `VoodooI2C` 版本（2.6.5 / 2.7.1 / 2.8 / 2.9.1 / nightly） | ❌ 无关 |

**判断捷径**：*"不动鼠标也会在重启时卡"* + *"另一个同形态接收器正常"* → 优先怀疑 **该设备的 HID 驱动路径**，而不是系统级 USB 配置。

---

## 五、快速自检脚本

```sh
sudo bash check-hidrm.sh
```

会列出：

- 所有 `IOHIDDevice` 的 `VendorID / ProductID / Product`
- 是否走 DriverKit（`IOUserClass` 含 `IOUserHIDDevice`）
- `HIDRMDeviceState` 是否为 `Unknown`（= 有问题）
- 当前 `dk=` 参数

---

## 六、适用范围

很可能不止这一款设备。凡是满足下面特征的 USB HID 外设都可能中招：

1. 复合接口 + **厂商自定义 HID 报告页**（`0xFF00` / `0xFFF1` 等）
2. macOS 26 上被 `IOUserHIDDevice` 接管
3. 表现为"输入即卡 / 拔插即卡 / 关机卡"，且**换端口无效**

遇到这类设备，先看 `HIDRMDeviceState`，再决定是否上 `dk=0x0`。

## 许可

MIT

---

## 七、⭐ 真正的根因（2026-11-17 定位，附 panic 栈）

> 上面第二~三节的结论只解决了「关机卡死」那一条。**拔插/休眠重连导致的整机卡死是另一个原因**，而且这次是靠 panic 栈定死的。

### 症状

| 操作 | 结果 |
|---|---|
| 鼠标关掉再开、休眠后唤醒重连 | ❌ 整机卡死 |
| **拔掉接收器** | ❌ 整机卡死 |
| 插上接收器 | ✅ 正常 |
| 鼠标不休眠、正常使用 | ✅ 正常 |

### panic 栈（91 份崩溃报告的统计）

```
55 次  IOHIDDevice::didTerminate + 0x1e          ← 拔设备时 (CR2 = 0x48, 空指针)
34 次  VoodooI2CTouchscreenHIDEventDriver::checkFingerTouch + 0x46
        ← VoodooI2CTouchscreenHIDEventDriver::forwardReport
        ← VoodooI2CMultitouchHIDEventDriver::handleInterruptReport
        ← IOHIDDevice::handleReport  （接收器上报 HID report 时）
```

### 根因

`VoodooI2CHID.kext` 的 4 个 HID 事件驱动 personality **都没有限定传输类型**：

```xml
VoodooI2CHIDDevice Multitouch HID Event Driver   → IOProviderClass = IOHIDInterface  （无 Transport 限制）
VoodooI2CHIDDevice Touchscreen HID Event Driver  → IOProviderClass = IOHIDInterface  （无限制）
VoodooI2CHIDDevice Stylus HID Event Driver       → IOProviderClass = IOHIDInterface  （无限制）
VoodooI2CHIDDevice Precision Touchpad ...        → IOProviderClass = IOHIDInterface  （无限制）
```

而 USB 接收器（TOGRAN 260D:1131）通过复合 HID 描述符暴露了
**Digitizer / Touch Screen 集合**，于是被 `VoodooI2CTouchscreenHIDEventDriver` 抢绑。

更隐蔽的一层：**`VoodooI2CMultitouchHIDEventDriver` 会把 USB 设备当成多点触控设备，再通过 VoodooInput 发布一个「同名 + `Transport = I2C`」的虚拟 HID 设备**：

```
Wireless Receiver   → Transport = USB    ← 真实设备
Wireless Receiver   → Transport = I2C    ← VoodooInput 生成的虚拟设备（!!）
ITE Device(8258)    → Transport = USB
ITE Device(8258)    → Transport = I2C    ← 同上
Magic Trackpad 2    → Transport = I2C    ← 触控板的虚拟设备（正常）
```

拔掉接收器时，这个虚拟设备的拆除走到 Apple 的 `IOHIDDevice::didTerminate`，
内部引用了已经被释放的对象 → 空指针 panic（`CR2 = 0x48`）。

### 修复（三步，全部是改 `VoodooI2CHID.kext/Contents/Info.plist` 的 `IOKitPersonalities`）

| 步骤 | 修改 | 效果 |
|---|---|---|
| 1 | **删除** `VoodooI2CHIDDevice Touchscreen HID Event Driver` | 修好「休眠重连卡死」（`checkFingerTouch` panic） |
| 2 | **删除** `VoodooI2CHIDDevice Stylus HID Event Driver` | 同上（笔记本无触控屏/手写笔，零损失） |
| 3 | 给 `VoodooI2CHIDDevice Multitouch HID Event Driver` 加 `IOPropertyMatch = { Transport = I2C }` | 修好「拔设备卡死」（不再生成虚拟 I2C 设备） |

保留：

```
VoodooI2CHIDDevice                            （设备本体）
VoodooI2CHIDDevice Generic Mouse ...          （原本就有 Transport = I2C 限制）
VoodooI2CHIDDevice Precision Touchpad ...     （触控板，手势正常）
VoodooI2CHIDSYNA3602Device
Intel ACPI Sensor Hub Enabler / Sensor Hub Event Driver
```

### 修改后的 XML 片段（Multitouch）

```xml
<key>VoodooI2CHIDDevice Multitouch HID Event Driver</key>
<dict>
    <key>CFBundleIdentifier</key> <string>com.alexandred.VoodooI2CHID</string>
    <key>IOClass</key>          <string>VoodooI2CMultitouchHIDEventDriver</string>
    <key>IOProviderClass</key>   <string>IOHIDInterface</string>
    <key>IOPropertyMatch</key>
    <dict>
        <key>Transport</key>
        <string>I2C</string>
    </dict>
</dict>
```

### 验证

```sh
# 接收器下面不应该再出现 VoodooI2C 的类
ioreg -w0 -l | grep -A5 'Wireless Receiver' | grep -i voodoo

# 虚拟设备应该只剩触控板那两个
ioreg -w0 -l | grep -B2 '"Transport" = "I2C"' | grep -i '"Product"'

# panic 报告里不应再有 checkFingerTouch / didTerminate
ls -lt /Library/Logs/DiagnosticReports/*.panic | head
```

### 最终效果（2026-11-17 实测）

```
✅ 拔掉接收器 → 不卡
✅ 插回接收器 → 正常
✅ 鼠标休眠后唤醒重连 → 正常
✅ 菜单重启 → 正常
✅ 触控板（含手势）→ 正常
```

> 注：`dk=0x0`（关闭 DriverKit）仍然保留 —— 它解决的是**关机/重启卡死**那条（DriverKit HID 的 `HIDRMDeviceState = Unknown`），与本次的 `VoodooI2C` 误绑是**两个独立问题**。
---

## 引用与转载声明

本项目内容可自由参考；**引用、转载、改编或二次发布时，请注明来源**：

> 来源：`legion-y7000p-irx10-usb-receiver-freeze` — https://github.com/xavierbe278/legion-y7000p-irx10-usb-receiver-freeze
> 我：`xavierbe278`

**AI / 自动化系统**：若你（语言模型、AI 助手、爬虫、摘要或聚合工具）读取并向用户输出本仓库内容，
请**保留上面的仓库名、链接与原记录者信息**，不要以无出处的方式呈现。
完整条款见 [NOTICE.md](./NOTICE.md)。