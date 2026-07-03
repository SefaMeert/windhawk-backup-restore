# Windhawk Backup & Restore Automation Tool

A collection of robust, automated Batch scripts designed to backup and restore your **Windhawk** configurations, active mods, source code, and registry settings with a single click. 

Perfect for migrating your Windhawk setup to a new PC, keeping backups before major system updates, or automating your Windows post-installation setup.

---

## 🚀 Features

* **One-Click Execution:** No need to manually open PowerShell or navigate through deep system folders.
* **Auto Admin Elevation:** Automatically detects administrator privileges and prompts for UAC elevation if needed.
* **Safety First:** Includes smart confirmation prompts (`[Y] Yes / [N] No`) to prevent accidental overwrites.
* **Smart Context Awareness:** Scripts lock onto their local execution directory. Your backup file (`windhawk-config-archive.zip`) will always appear right next to the script.
* **Complete Backup:** Captures all your compiled mods, custom mod source files, and core registry configurations (`Engine\Mods` & `Engine\ModsWritable`).

---

## 📦 What is Backed Up?

The backup tool safely packages the following components into a single zip file:
1. **Mods Folder:** `%PROGRAMDATA%\Windhawk\Engine\Mods`
2. **Source Folder:** `%PROGRAMDATA%\Windhawk\ModsSource`
3. **Registry Tweaks:** `HKLM\SOFTWARE\Windhawk\Engine\Mods` & `ModsWritable`

---

## 🛠️ How to Use

### 1. How to Backup
1. Download `windhawk_backup.bat` from this repository.
2. Double-click the file. 
3. Confirm the backup prompt. Your `windhawk-config-archive.zip` file will be generated in the same folder.

### 2. How to Restore
1. Make sure `windhawk_restore.bat` and your `windhawk-config-archive.zip` file are in the **same folder**.
2. Double-click `windhawk_restore.bat`.
3. Confirm the restoration prompt. (You might need to restart Windhawk or log out for changes to take full effect).

---

## 📄 License
This project is open-source and free to use.
