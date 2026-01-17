This updated `README.md` reflects the final, verified logic of your script, specifically highlighting the **Preservation vs. Merging** rules and the **Orphan Cleanup** process.

---

# 📸 Media Organizer Pro

A specialized PowerShell automation tool for cross-drive media management. This script utilizes a hybrid routing engine to consolidate mobile imports while maintaining the categorical structure of archival collections.

## 🧠 Routing Intelligence

The script distinguishes between "New Imports" and "Managed Collections" using two distinct logic paths:

### 1. Dynamic Merging (Type-Based)

* **Sources:** `H:\Photos\unorganized`, `P:\John`, `P:\Roena`.
* **Behavior:** Files are stripped of their source subfolders and routed to central repositories based on file extension.
* **Destinations:** * Standard Images  `H:\Photos\YYYY\MM Month`
* RAW/Pro Photography  `P:\Photography\YYYY\MM Month`
* Videos  `H:\Videos\YYYY\MM Month`



### 2. Categorical Preservation (Base-Based)

* **Sources:** `H:\PhotoGroups`, `W:\ExcessPhotos`, `W:\problem images\Junk`.
* **Behavior:** The script respects the "Middle Path" (e.g., `...\Christina\Brent Mason\`). It inserts the Date folders *at the end* of that specific path.
* **Result:** `W:\ExcessPhotos\Kira\Fof\image.jpg`  `W:\ExcessPhotos\Kira\Fof\2026\01 January\image.jpg`.

---

## 🛠 Features & Safety

* **Precision Dating:** Primary dating via **ExifTool** (metadata). Supports a `$UsePathBasedSorting` toggle to infer dates from folder names for scanned media.
* **Atomic Sidecar Handling:** `.xmp` files are linked to their parent media. If `photo.jpg` is renamed to `photo_1.jpg` to avoid a collision, the sidecar is automatically renamed to `photo_1.xmp`.
* **Collision Prevention:** Uses an incremental suffix system (`_1`, `_2`) to ensure no file is ever overwritten.
* **Orphan Sweep:** Automatically purges standalone `.xmp` files from source directories if the parent media has been moved.

---

## 📋 Configuration Guide

### Source Roots

Modify these arrays in the script to add or remove watch-folders:

* `$TypeSortRoots`: Folders that should be "cleaned" and merged into main drives.
* `$BaseKeepRoots`: Folders where subfolder names (categories) must be preserved.

### Drive Mapping

| Drive Root | Purpose |
| --- | --- |
| `H:\Photos` | Final destination for all standard consumer images. |
| `P:\Photography` | Final destination for RAW files and photography sessions. |
| `H:\Videos` | Final destination for all video formats. |
| `H:\Audio` | Final destination for music and recordings. |

---

## 🚦 Execution

1. **Requirement:** Ensure `exiftool.exe` is located at `C:\Tools\ExifTool\`.
2. **Run:** Open PowerShell and execute:
```powershell
.\media-organizer-pro.ps1

```


3. **Logs:** All movements and deletions are timestamped in `H:\_code\move-log2.txt`.

---

## 🧹 Cleanup Process

At the conclusion of the move, the script performs a recursive scan of all Source Roots. It identifies `.xmp` files and checks for matching filenames with media extensions (`.jpg`, `.cr2`, `.mp4`, etc.). If no match is found in that folder, the XMP is deleted to keep your archives lean.
