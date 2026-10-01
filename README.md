# Windhawk Backup & Restore 

<br/>

[![Download Latest Release](https://img.shields.io/badge/DOWNLOAD-LATEST_RELEASE-0078D4?style=for-the-badge&logo=github&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)

<br/>

[![Release](https://img.shields.io/github/v/release/SefaMeert/windhawk-backup-restore?color=0078D4)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/SefaMeert/windhawk-backup-restore/total?color=0078D4)](https://github.com/SefaMeert/windhawk-backup-restore/releases)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D4.svg?logo=windows&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore)
[![Downloads](https://img.shields.io/github/downloads/SefaMeert/windhawk-backup-restore/total?color=0078D4)](https://github.com/SefaMeert/windhawk-backup-restore/releases)
[![License](https://img.shields.io/badge/license-MIT-0078D4.svg)](https://github.com/SefaMeert/windhawk-backup-restore/blob/main/LICENSE)

A robust, interactive Batch script designed to manage your **Windhawk** configurations, active mods, source code, and registry settings through a single, unified interface.

Perfect for migrating your Windhawk setup to a new PC, keeping backups before major system updates, or automating your Windows post-installation setup.

---

## 🚀 Features

* **All-in-One Execution:** Both backup and restore workflows are bundled into a single, clean command-line menu.
* **Smart Navigation:** Made a mistake or changed your mind? The script features validation prompts (`[Y]/[N]`) that safely return you to the main menu instead of abruptly closing.
* **Auto Admin Elevation:** Automatically detects administrator privileges at launch and prompts for UAC elevation just once.
* **Context Awareness:** Your backup file (`windhawk-backup-[date].zip`) is always generated right next to the AIO script.
* **Complete Coverage:** Safely archives compiled mods, custom mod source files, and core registry configurations (`Engine\Mods` & `Engine\ModsWritable`).

---

## 🛠️ How to Use

1. Download and run **`windhawk_Backup_Restore.bat`** (It will automatically request Administrator privileges).
2. Choose your operation from the interactive menu:
   - Press **[1]** to create a fresh, timestamped backup (`windhawk-backup-[date].zip`) of your active Windhawk settings.
   - Press **[2]** to view all available backups in the folder and select which one to restore by entering its number.
   - Press **[3]** to safely exit.

---

## 🇹🇷 Türkçe Açıklama

Windhawk modlarınızı, kodlarınızı, özelleştirmelerinizi ve tüm sistem ayarlarınızı tek bir interaktif menü üzerinden yedeklemenizi ve geri yüklemenizi sağlayan gelişmiş bir AIO (All-in-One) Batch betiğidir.

### Öne Çıkanlar:
- **Tek Dosyada Tüm İşlemler:** Yedek alma ve geri yükleme süreçlerini tek menüde birleştirir.
- **Otomatik Yönetici Yetkisi (UAC):** Gerekli izinleri açılışta otomatik olarak talep eder.
- **Tam Kapsamlı Yedekleme:** Modları ve Kayıt Defteri (Registry) yapılandırmalarını güvenle arşivler.

---

⚠️️ **Note on Windows SmartScreen:** Since this is an unsigned open-source Batch script, Windows SmartScreen might flag it during the first launch. Click on "More info" and then "Run anyway" to bypass it. You can review the entire source code to verify its safety.

---

## 📄 License

This project is open-source and free to use under the MIT License.
