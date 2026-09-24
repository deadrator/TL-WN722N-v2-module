## Wireless Firmware for Nethunter

This Magisk module adds the required firmware for external wireless adapters to be used with Nethunter.

**NOTE:** Your kernel still needs to support external network adapters. This module only provides missing firmware, if any.

The list of included firmware is given below. For other devices, [create a new issue on GitHub  here.](https://github.com/rithvikvibhu/nh-magisk-wifi-firmware/issues)

This module should work with any variant of Nethunter, but it was created to work with __Nali Kethunter__ (https://forum.xda-developers.com/android/software-hacking/nali-kethunter-modded-kernel-supported-t3770455) - another Magisk module by [@LazerL0rd](https://forum.xda-developers.com/member.php?u=7836278) which systemlessly installs Kali Nethunter.

#### Supported chipsets:

- **Ralink** - RT2501, RT2501USB, RT2561, RT2561S, RT2571W, RT2600, RT2661, RT2671, RT2760, RT2790, RT2860, RT2870, RT2890, RT3070, RT3071, RT3090, RT3290, RT5201, RT5600
- **Realtek** - RTL8188* (EU/FTV), RTL8192* (CU/EU/DE/SE), RTL8821/12* (AE/AU/BU), RTL8822BU
- **Atheros** - AR9170, AR7010
- **Mediatek** - MT7601u
- **Broadcom** - bcm43xx (not tested), BRCM4335, BRCM4339, BRCM4354


#### Supported adapters

- TL-WN722N (v1, Atheros AR9271 - `htc_9271` firmware)
- TL-WN722N v2/v3 (Realtek RTL8188EUS - `rtlwifi/rtl8188eufw.bin`, see below)
- AWUS036NEH
- TE-W322U
- Netgear_WN111v2
- TL-WN821Nv3
- (and many more. Check if chipset is listed above.)

#### TL-WN722N v2/v3 notes (RTL8188EUS)

The v2/v3 hardware uses a completely different chipset than v1 (Realtek RTL8188EUS,
vs the Atheros AR9271 in v1). Most units enumerate as the generic Realtek USB ID
`0bda:8179`, but some (notably v3) ship with TP-Link's own pair `2357:010c` —
both are the same RTL8188EUS hardware. It needs `rtlwifi/rtl8188eufw.bin`,
which is the exact path requested by both kernel drivers that support it:

- `rtl8xxxu` (mainline since 6.3, the driver NetHunter uses)
- `r8188eu` (staging, kernels <= 6.2)

Since v2.1.0 this module ships the **linux-firmware v28.0** build of this file
(sha256 `2ff74315...`), which fixes monitor-mode issues with `rtl8xxxu` (see
[linux-firmware commit b72c69dd](https://gitlab.com/kernel-firmware/linux-firmware/-/commit/b72c69dd542c4684ece8ac88ec1ba33364ec9365)).
Older module releases shipped the 2013 v19 build, which breaks monitor mode on
rtl8xxxu kernels.

The module also installs a boot-time guard (`common/service.sh`) that:

1. Verifies the firmware is visible in the kernel's `request_firmware()` search
   path, and falls back to copying it into `/vendor/etc/firmware` if the Magisk
   overlay was not mounted.
2. If the adapter is plugged in but failed to get its firmware earlier in boot,
   re-probes it (drivers_probe / re-authorize / driver rebind) so it comes up
   without a manual replug.

To diagnose problems, run `nhwifi-check` (root shell) after plugging the adapter
in - it verifies placement, driver binding, and shows recent kernel log lines.


#### Changelog

* v2.1.2
    - nhwifi-check: distinguishes generic "usb" core binding from a real wifi
      driver on the USB interface, and reports whether an rtl8xxxu / r8188eu
      module is loaded or present in /system|/vendor|/odm lib/modules
    - service.sh: if the kernel ships an rtl8xxxu / r8188eu module that was
      not autoloaded, it is insmodded at boot; if a loaded driver does not
      know the adapter's USB ID, it is offered via driver `new_id` (old
      kernels often lack 2357:010c in their ID tables); interface-level
      drivers_probe added

* v2.1.1
    - TL-WN722N v2/v3: also detect TP-Link-branded USB ID `2357:010c` in
      service.sh and nhwifi-check (units enumerating as TP-Link, not generic
      Realtek `0bda:8179`, were previously reported as "not plugged in")

* v2.1.0
    - TL-WN722N v2/v3: updated rtl8188eufw.bin to linux-firmware v28.0 (fixes rtl8xxxu monitor mode)
    - Added boot-time guard (service.sh) ensuring firmware placement + adapter re-probe
    - Added /vendor/etc/firmware fallback copy of rtl8188eufw.bin
    - Added nhwifi-check diagnostic script (/system/bin/nhwifi-check)
    - Installer now verifies firmware presence at install time

* v2.0.4
    - Added files for RTL8812BU, RTL8822BU, BRCM4335, BRCM4339, BRCM4354

* v2.0.3
    - Added files for bcm43xx (meant for bcm4358)

* v2.0.2
    - Added all Ralink files
    - Check chipset list above

* v2.0.1
    - Added files for AR7010 and RTL8821

* v2.0.0
    - Migrated to new Magisk Installer template
    - Added upater-script for zip flashing

* v1.0.5
    - Added files for AR9170

* v1.0.4
    - Added files for RTL8192

* v1.0.3
    - Added files for RTL8188EU

* v1.0.2
    - Added files for RT3070 and RT3071

* v1.0.1
    - Added files for RT2870 and MT7601u

* v1.0
    - Initial release


**Source:** https://github.com/rithvikvibhu/nh-magisk-wifi-firmware
**Issues / Request other firmware:** https://github.com/rithvikvibhu/nh-magisk-wifi-firmware/issues
**Author:** [rithvikvibhu](https://github.com/rithvikvibhu) (https://github.com/rithvikvibhu)
