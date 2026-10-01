# Windhawk Backup & Restore AIO 🚀


[![Download Latest Release](https://img.shields.io/badge/DOWNLOAD-LATEST_RELEASE-2ea44f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)

<br/>

[![Platform](https://img.shields.io/badge/platform-Windows-0078D4.svg?logo=windows&logoColor=white)](https://github.com/SefaMeert/windhawk-backup-restore)
[![Downloads](https://img.shields.io/github/downloads/SefaMeert/windhawk-backup-restore/total?color=44cc11)](https://github.com/SefaMeert/windhawk-backup-restore/releases)
[![Release](https://img.shields.io/github/v/release/SefaMeert/windhawk-backup-restore?color=007ec6)](https://github.com/SefaMeert/windhawk-backup-restore/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/SefaMeert/windhawk-backup-restore/blob/main/LICENSE)

A robust, interactive All-in-One (AIO) Batch script designed to manage your **Windhawk** configurations, active mods, source code, and registry settings through a single, unified interface.

Perfect for migrating your Windhawk setup to a new PC, keeping backups before major system updates, or automating your Windows post-installation setup.

---

## 🚀 Features

* **All-in-One Execution:** Both backup and restore workflows are bundled into a single, clean command-line menu.
* **Smart Navigation:** Made a mistake or changed your mind? The script features validation prompts (`[Y]/[N]`) that safely return you to the main menu instead of abruptly closing.
* **Auto Admin Elevation:** Automatically detects administrator privileges at launch and prompts for UAC elevation just once.
* **Context Awareness:** Your backup file (`windhawk-config-archive.zip`) is always generated right next to the AIO script.
* **Complete Coverage:** Safely archives compiled mods, custom mod source files, and core registry configurations (`Engine\Mods` & `Engine\ModsWritable`).

---

## 🛠️ How to Use

1. Download `windhawk_Backup_Restore_AIO.bat` from the latest release or repository.
2. Double-click the file to open the interactive menu.
3. Choose your operation:
   * **Press [1]** to create a fresh backup of your active Windhawk settings.
   * **Press [2]** to restore an existing backup (Make sure `windhawk-config-archive.zip` is in the same folder as the script).
   * **Press [3]** to safely exit.

---

## 🇹🇷 Türkçe Açıklama

Windhawk modlarınızı, kodlarınızı, özelleştirmelerinizi ve tüm sistem ayarlarınızı tek bir interaktif menü üzerinden yedeklemenizi ve geri yüklemenizi sağlayan gelişmiş bir AIO (All-in-One) Batch betiğidir.

### Öne Çıkanlar:
- **Tek Dosyada Tüm İşlemler:** Yedek alma ve geri yükleme süreçlerini tek menüde birleştirir.
- **Otomatik Yönetici Yetkisi (UAC):** Gerekli izinleri açılışta otomatik olarak talep eder.
- **Tam Kapsamlı Yedekleme:** Derlenmiş modları, kaynak kodları ve Kayıt Defteri (Registry) yapılandırmalarını güvenle arşivler.

---

⚠️️ **Note on Windows SmartScreen:** Since this is an unsigned open-source Batch script, Windows SmartScreen might flag it during the first launch. Click on "More info" and then "Run anyway" to bypass it. You can review the entire source code to verify its safety.

---

## 📄 License

This project is open-source and free to use under the MIT License.
