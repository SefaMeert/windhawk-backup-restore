# Windhawk Backup & Restore

<br/>

[![Download Latest Release](https://img.shields.io/badge/DOWNLOAD-LATEST_RELEASE-0284C7?style=for-the-badge&logo=github&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)

<br/>

[![Release](https://img.shields.io/github/v/release/SefaMeert/windhawk-backup-restore?color=0284C7)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows-0284C7.svg?logo=windows&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore)
[![License](https://img.shields.io/badge/license-MIT-0284C7.svg)](LICENSE)

A standalone Batch/PowerShell utility for backing up and restoring Windhawk settings, installed mods and mod settings. No additional software is required.

## Features

- Interactive backup and restore menu with automatic administrator elevation.
- Timestamped ZIP backups saved next to the script; newest modified backup marked **Latest**.
- SHA-256 manifest and ZIP content verification for newly created backups.
- Restore replaces managed files and registry settings; unchanged files are preserved.
- Optional permanent safety ZIP and a temporary rollback snapshot before restore. If rollback fails, the recovery snapshot is retained and its path reported.
- File-lock detection using Windows Restart Manager. With explicit confirmation, the script can restart a verified desktop Explorer process in the current session. Other applications are not forcibly closed.
- Compatibility with legacy backup layouts, including v1.3.0. Older archives without a manifest do not have SHA-256 manifest verification.

## Backup scope

| Data | Location |
| --- | --- |
| Installed mod files | `%ProgramData%\Windhawk\Engine\Mods` |
| Mod source files | `%ProgramData%\Windhawk\ModsSource` |
| Machine configuration and mod settings | `HKLM\SOFTWARE\Windhawk` |
| User configuration, when present | `HKCU\Software\Windhawk` |

Other ProgramData directories, including `ModsWritable` runtime files, caches and logs outside the managed directories, are not backed up or restored. This is not a full Windhawk installation or arbitrary mod data backup.

## Requirements

- Windows with Windows PowerShell 5.1 (64-bit PowerShell on 64-bit Windows).
- A standard installed Windhawk instance using the default ProgramData location and `Windhawk` service. Portable and custom data locations are not supported.
- Administrator privileges under the intended Windows user account.

## How to use

1. Download `windhawk_Backup_Restore_v1.4.1.bat` from the [latest release](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest) and run it. Administrator privileges will be requested automatically. No extraction is required.
2. Select **1** to create a backup, **2** to restore or **3** to exit.
3. To restore, place the backup ZIP next to the script and select its number. Select **Y** for a permanent safety ZIP (recommended), **N** to continue with only the temporary rollback snapshot, or **0** to cancel.
4. If Explorer is locking mod files, save your work and finish file transfers before approving its restart. The taskbar and File Explorer windows may temporarily close. If other processes block the restore, close them normally or follow the safe-mode/restart advice shown by the script.
5. Restart Windhawk or sign out if necessary.

**Important:** Restore replaces the managed configuration, including removing managed files and registry entries absent from the selected backup. Keep a separate known-good backup. Use only trusted archives: SHA-256 manifests check integrity, not authenticity. Automatic rollback is best effort, not a guarantee against every failure or interruption.

### Diagnostics

Run from an administrator PowerShell terminal in the script directory:

```powershell
& .\windhawk_Backup_Restore_v1.4.1.bat --self-test
```

The self-test checks file-lock detection and Explorer restart prerequisites without closing Explorer or changing real Windhawk data or registry settings. It does not replace a live restore test.

## 🇹🇷 Türkçe açıklama

Windhawk ayarlarını, kurulu modları, mod kaynak kodlarını ve kayıt defterindeki mod ayarlarını tek BAT dosyasıyla yedekleyip geri yükleyebilirsiniz. Geçici çalışma dosyaları ve yönetilen kapsam dışındaki klasörler yedeklenmez. Taşınabilir ve özel veri konumlu kurulumlar desteklenmez.

[Son sürüm](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest) sayfasından BAT dosyasını indirin ve doğrudan çalıştırın. Yönetici yetkisi otomatik olarak istenir; arşivden çıkarma gerekmez.

- **1:** Yedek oluşturur. ZIP dosyası betiğin bulunduğu klasöre kaydedilir ve SHA-256 ile doğrulanır.
- **2:** Yedek seçerek geri yükler. **Y** kalıcı güvenlik yedeği oluşturur, **N** yalnızca geçici geri alma yedeğiyle devam eder, **0** iptal eder.
- **3:** Çıkış yapar.

Geri yükleme mevcut yönetilen mod dosyalarını ve kayıt defteri ayarlarını yedekteki duruma getirir. Değişmemiş dosyalara dokunulmaz. Hata durumunda geri alma denenir; başarısız olursa kurtarma yedeği saklanır. Kilitli dosyalar için Windows Gezgini yalnızca onayınızla yeniden başlatılabilir; diğer uygulamalar zorla kapatılmaz. v1.3.0 yedekleri desteklenir, ancak manifest içermeyen eski arşivlerde SHA-256 manifest doğrulaması yapılamaz.

Yalnızca güvenilir yedekleri kullanın ve ayrı bir sağlam yedek saklayın. `--self-test` seçeneği yönetici yetkili PowerShell üzerinden gerçek Windhawk verilerine dokunmadan kilit tespiti tanılamalarını çalıştırır.

## License

This project is released under the [MIT License](LICENSE). It is an independent utility and is not affiliated with the Windhawk project.
