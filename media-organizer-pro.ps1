# ================= GLOBAL TIMER =================
$globalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ================= OPTIONS =================
$UsePathBasedSorting     = $false   # $false = ExifTool, $true = infer from path

# ================= CONFIG =================
$TypeSortRoots = @(
    "H:\Photos\unorganized",
    "P:\John",
    "P:\Roena"
)

$BaseKeepRoots = @(
    "P:\Photography",
    "H:\PhotoGroups",
    "W:\ExcessPhotos",
    "W:\problem images\Junk"
)

$SourceRoots     = $TypeSortRoots + $BaseKeepRoots
$PhotosRoot      = "H:\Photos"
$PhotographyRoot = "P:\Photography"
$VideosRoot      = "H:\Videos"
$AudioRoot       = "H:\Audio"

$ExifTool        = "C:\Tools\ExifTool\exiftool.exe"
$LogFile         = Join-Path -Path $PSScriptRoot -ChildPath "move-log.txt"

$ImageExt = @(".jpg",".jpeg",".jpe",".png",".gif",".bmp",".tif",".tiff",".heic",".heif",".webp",".avif",".jp2",".j2k",".psd",".psb",".xcf",".ico")
$RawExt   = @(".cr2",".cr3",".nef",".nrw",".arw",".srf",".sr2",".dng",".orf",".rw2",".raf",".pef",".ptx",".srw",".3fr",".iiq",".x3f")
$VideoExt = @(".mp4",".m4v",".mov",".avi",".mkv",".wmv",".flv",".f4v",".webm",".3gp",".3g2",".mts",".m2ts",".ts",".vob",".ogv",".rm",".rmvb",".asf")
$AudioExt = @(".mp3",".wav",".aac",".flac",".m4a",".aif",".aiff",".ogg",".wma")
$AllMediaExt = $ImageExt + $RawExt + $VideoExt + $AudioExt

# ================= FUNCTIONS =================
function Get-PathDate {
    param ($file)
    $path = $file.DirectoryName
    $year = if ($path -match '(\d{4})') { $matches[1] } else { $file.LastWriteTime.Year }
    if ($path -match '(0[1-9]|1[0-2])\s+(January|February|March|April|May|June|July|August|September|October|November|December)') {
        $mNum = $matches[1]; $mName = $matches[2]
    } elseif ($path -match '(January|February|March|April|May|June|July|August|September|October|November|December)') {
        $mName = $matches[1]; $mNum = (Get-Date "1 $mName").ToString("MM")
    } else {
        $mNum = "{0:D2}" -f $file.LastWriteTime.Month; $mName = $file.LastWriteTime.ToString("MMMM")
    }
    return @{ Year = $year; mNum = $mNum; mName = $mName }
}

function Get-MediaDate {
    param ($file, $isMedia)
    if (Test-Path $ExifTool) {
        $tags = if ($isMedia) { "MediaCreateDate","TrackCreateDate","CreateDate" } else { "DateTimeOriginal","CreateDate" }
        foreach ($tag in $tags) {
            try {
                $value = & $ExifTool "-s3" "-$tag" $file.FullName 2>$null
                if ($value) { return [datetime]::ParseExact($value.Trim().Substring(0,19), "yyyy:MM:dd HH:mm:ss", $null) }
            } catch {}
        }
    }
    return $file.LastWriteTime
}

# ================= INITIAL SCAN =================
Write-Host "Scanning Source Roots..." -ForegroundColor Cyan
$allFiles = foreach ($root in $SourceRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File | Where-Object {
            $ext = $_.Extension.ToLower()
            if ($AllMediaExt -notcontains $ext) { return $false }
            $currentDir = $_.Directory
            $parentDir  = $currentDir.Parent
            $alreadyOrganized = ($currentDir.Name -match '^\d{2}\s\w+$') -and ($parentDir -and $parentDir.Name -match '^\d{4}$')
            return (-not $alreadyOrganized)
        }
    }
}

$total = $allFiles.Count
$index = 0
if ($total -eq 0) { Write-Host "No files to move!" -ForegroundColor Green; exit }

# ================= MAIN LOOP =================
foreach ($file in $allFiles) {
    $index++
    $sourcePath = $file.FullName
    $ext = $file.Extension.ToLower()
    $status = "None"

    # 1. Date Logic
    if ($UsePathBasedSorting) {
        $d = Get-PathDate $file
        $year = $d.Year; $monthNum = $d.mNum; $monthName = $d.mName
    } else {
        $dt = Get-MediaDate $file ($VideoExt + $AudioExt -contains $ext)
        $year = $dt.Year; $monthNum = "{0:D2}" -f $dt.Month; $monthName = $dt.ToString("MMMM")
    }

    # 2. Routing Logic
    $foundRoot = $null
    $isFromTypeSortRoot = $false
    foreach ($root in $SourceRoots) {
        if ($sourcePath.StartsWith($root, "OrdinalIgnoreCase")) {
            $foundRoot = $root
            if ($TypeSortRoots -contains $root) { $isFromTypeSortRoot = $true }
            break
        }
    }

    if ($isFromTypeSortRoot) {
        if ($ImageExt -contains $ext) { $basePath = $PhotosRoot }
        elseif ($RawExt -contains $ext) { $basePath = $PhotographyRoot }
        elseif ($VideoExt -contains $ext) { $basePath = $VideosRoot }
        elseif ($AudioExt -contains $ext) { $basePath = $AudioRoot }
        else { $basePath = $PhotosRoot }
    } else {
        # Preserve middle path (Kira\Fof\)
        $relativeDir = $file.DirectoryName.Replace($foundRoot, "").TrimStart('\').TrimStart('/')
        $cleanRelativeDir = $relativeDir -replace '(\d{4}[\\/]\d{2}\s\w+)', ''
        $basePath = Join-Path $foundRoot $cleanRelativeDir
    }

    # 3. Final Path Construction
    $destFolder = Join-Path $basePath "$year\$monthNum $monthName"
    $finalDest  = Join-Path $destFolder $file.Name

    # 4. Move/Rename with Sidecar Handling
    if ($sourcePath -ne $finalDest) {
        if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
        $count = 1
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $targetPath = $finalDest
        while (Test-Path $targetPath) {
            $targetPath = Join-Path $destFolder "$baseName`_$count$ext"
            $count++
            $status = "Renamed"
        }
        try {
            Move-Item $sourcePath $targetPath -ErrorAction Stop
            $xmpSrc = [System.IO.Path]::ChangeExtension($sourcePath, ".xmp")
            if (Test-Path $xmpSrc) {
                $xmpDst = [System.IO.Path]::ChangeExtension($targetPath, ".xmp")
                Move-Item $xmpSrc $xmpDst -Force -ErrorAction SilentlyContinue
            }
            if ($status -eq "None") { $status = "Moved" }
            $finalDest = $targetPath # For display
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`t$sourcePath -> $finalDest" | Add-Content $LogFile
        } catch { $status = "Error" }
    }

    # 5. Output
    $avg = $globalStopwatch.Elapsed.TotalSeconds / $index
    $ts = [timespan]::FromSeconds(($total - $index) * $avg)
    $eta = "{0:D2}:{1:D2}:{2:D2}" -f [int][math]::Floor($ts.TotalHours), $ts.Minutes, $ts.Seconds
    $color = switch ($status) { "Moved" {"Green"} "Renamed" {"Cyan"} "Error" {"Red"} Default {"Gray"} }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("[{0,5}/{1}] ETA: {2} | {3}" -f $index, $total, $eta, $status) -ForegroundColor $color
    Write-Host "  SRC: $sourcePath" -ForegroundColor Gray
    Write-Host "  DST: $finalDest" -ForegroundColor $color
}

# ================= ORPHAN CLEANUP =================
Write-Host "`nCleaning up orphaned XMP files..." -ForegroundColor Yellow
foreach ($root in $SourceRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -Filter "*.xmp" | Where-Object {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
            $media = Get-ChildItem -Path $_.DirectoryName -File | Where-Object {
                ([System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $base) -and ($AllMediaExt -contains $_.Extension.ToLower())
            }
            -not $media
        } | Remove-Item -Force
    }
}

$globalStopwatch.Stop()
Write-Host "`n--- Finished in $($globalStopwatch.Elapsed.ToString("hh\:mm\:ss")) ---" -ForegroundColor DarkMagenta