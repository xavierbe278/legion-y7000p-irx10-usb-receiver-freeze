#!/bin/bash
# 列出所有 HID 设备，并标出 DriverKit(HIDRM) 状态异常的设备
# 用法: sudo bash check-hidrm.sh
echo "══════════════════════════════════════════════"
echo "  HID / HIDRM 状态检查"
echo "══════════════════════════════════════════════"
echo
echo "当前 dk 参数:"
nvram -p 2>/dev/null | grep -m1 boot-args | tr ' ' '\n' | grep '^dk=' || echo "  （未设置，DriverKit 处于默认启用状态）"
echo
echo "──── 设备列表 ────"
ioreg -l -w0 -rc IOHIDDevice 2>/dev/null | tr -d '\000' | awk '
  /"Product" = /            { p=$0; sub(/.*= "/,"",p); sub(/".*/,"",p) }
  /"VendorID" = /           { v=$0; sub(/.*= /,"",v); gsub(/[^0-9]/,"",v) }
  /"ProductID" = /          { d=$0; sub(/.*= /,"",d); gsub(/[^0-9]/,"",d) }
  /"HIDRMDeviceState" = /   { s=$0; sub(/.*= "/,"",s); sub(/".*/,"",s) }
  /"IOUserClasses" = /      { u=$0; sub(/.*= \(/,"",u); sub(/\).*/,"",u) }
  /^ *}$/ {
    if (p != "") {
      printf "  %-32s VID=%-6s PID=%-6s", p, v, d
      if (s != "") printf "  HIDRM=%-10s", s; else printf "  HIDRM=%-10s", "(内核HID)"
      if (u ~ /IOUserHIDDevice/) printf "  [DriverKit]"
      printf "\n"
    }
    p=""; v=""; d=""; s=""; u=""
  }
'
echo
echo "──── 判断 ────"
BAD=$(ioreg -l -w0 -rc IOHIDDevice 2>/dev/null | grep -c 'HIDRMDeviceState" = "Unknown"')
if [ "${BAD}" -gt 0 ]; then
  echo "  ⚠️  发现 ${BAD} 个 HID 实例处于 HIDRMDeviceState=Unknown"
  echo "     这类设备可能导致：输入卡死 / 拔插卡死 / 关机卡死"
  echo "     解决：boot-args 加 dk=0x0（关闭 DriverKit），或 dk=0x8001（仅关 entitlement 检查）"
else
  echo "  ✅ 没有发现 HIDRM 处于 Unknown 的设备"
fi