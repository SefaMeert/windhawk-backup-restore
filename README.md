# Windhawk Backup & Restore Toolbox

A robust, interactive all-in-one Batch script designed to manage your **Windhawk** configurations, active mods, source code, and registry settings with an intuitive menu interface.

Perfect for migrating your Windhawk setup to a new PC, keeping backups before major system updates, or automating your Windows post-installation setup.

---

## 🚀 Features

* **All-in-One Interface:** Access both backup and restore workflows from a single, clean command-line menu.
* **Smart Navigation:** Made a mistake? The script features smart validation prompts (`[Y]/[N]`) that safely return you to the main menu instead of closing the window.
* **Auto Admin Elevation:** Automatically detects administrator privileges at launch and prompts for UAC elevation just once.
* **Context Awareness:** Your backup file (`windhawk-config-archive.zip`) is always generated right next to the toolbox script.
* **Complete Coverage:** Safely archives compiled mods, custom mod source files, and core registry configurations (`Engine\Mods` & `Engine\ModsWritable`).

---

## 🛠️ How to Use

1. Download `windhawk_toolbox.bat` from this repository.
2. Double-click the file to open the interactive menu.
3. Choose your operation:
   * **Press [1]** to pull a fresh backup of your active Windhawk settings.
   * **Press [2]** to restore an existing backup (Make sure `windhawk-config-archive.zip` is in the same folder as the script).
   * **Press [3]** to safely exit.

---

## 📄 License
This project is open-source and free to use. Feel free to modify and share!
