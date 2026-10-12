# ============================================================
# RULE34 GALLERY-DL DOWNLOADER
# Baby Pink Edition | HTML + CSV History + Tag Library
# ============================================================

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

# =========================
# SETTINGS
# =========================

$RootFolder  = "C:\Downloads\ScrapedMedia\rule34"
$ExcludeFile = Join-Path $PSScriptRoot "exclude-tags.txt"
$HistoryCSV  = Join-Path $PSScriptRoot "download-history.csv"
$HistoryHTML = Join-Path $PSScriptRoot "download-history.html"
$Rule34Base  = "https://rule34.xxx/index.php?page=post&s=list&tags="

# =========================
# COLORS
# =========================

$ESC      = [char]27
$Reset    = "$ESC[0m"
$Pink     = "$ESC[38;2;255;182;193m"
$BabyPink = "$ESC[38;2;255;218;230m"
$Blush    = "$ESC[38;2;255;192;203m"
$Rose     = "$ESC[38;2;219;112;147m"
$SoftPink = "$ESC[38;2;250;218;221m"
$PalePink = "$ESC[38;2;255;240;245m"

# =========================
# DISPLAY HELPERS
# =========================

function Show-Decoration {
    Write-Host "$BabyPink       . * . * . * . * . * . * . * .$Reset"
}

function Show-DoubleDecoration {
    Write-Host "$Pink       . * . * . * . * . * . * . * .$Reset"
    Write-Host "$BabyPink    * . * . * . * . * . * . * . *$Reset"
}

function Show-Title {
    Clear-Host
    Show-DoubleDecoration
    Write-Host ""
    Write-Host "$Pink       RULE34 GALLERY-DL DOWNLOADER$Reset"
    Write-Host "$SoftPink       Baby Pink Edition$Reset"
    Write-Host ""
    Show-DoubleDecoration
    Write-Host ""
}

function Show-Section {
    param([string]$Name)

    Write-Host ""
    Write-Host "$Pink > $Name$Reset"
    Show-Decoration
}

# Returns control to the main menu through the main workflow's catch.
function Stop-Script {
    param([string]$Message)

    Write-Host ""
    Write-Host "$Rose $Message$Reset"
    Write-Host ""
    Read-Host "Press Enter to return to the main menu"

    throw [System.OperationCanceledException]::new("RETURN_TO_MENU")
}

# =========================
# EXCLUSION LIBRARY READER
# =========================

function Get-ExclusionGroups {
    if (-not (Test-Path -LiteralPath $ExcludeFile)) {
        throw "exclude-tags.txt was not found next to this script."
    }

    $Result = [ordered]@{}
    $CurrentGroup = $null

    foreach ($Line in Get-Content -LiteralPath $ExcludeFile) {
        $Trimmed = $Line.Trim()

        if ([string]::IsNullOrWhiteSpace($Trimmed)) {
            continue
        }

        if ($Trimmed -match '^#\s*GROUP:\s*(.+)$') {
            $CurrentGroup = $Matches[1].Trim()

            if (-not $Result.Contains($CurrentGroup)) {
                $Result[$CurrentGroup] =
                    [System.Collections.Generic.List[string]]::new()
            }

            continue
        }

        if ($Trimmed.StartsWith("#")) {
            continue
        }

        if ($null -eq $CurrentGroup) {
            $CurrentGroup = "Other"

            if (-not $Result.Contains($CurrentGroup)) {
                $Result[$CurrentGroup] =
                    [System.Collections.Generic.List[string]]::new()
            }
        }

        $Tag = $Trimmed.TrimStart("@").Trim()

        if ($Tag -and -not $Result[$CurrentGroup].Contains($Tag)) {
            $Result[$CurrentGroup].Add($Tag)
        }
    }

    return ,$Result
}

# =========================
# HISTORY INITIALIZATION
# =========================

function Initialize-History {
    if (-not (Test-Path -LiteralPath $HistoryCSV)) {
        '"Date","SearchTags","ExclusionGroups","Destination","FinalURL","Status"' |
            Set-Content -LiteralPath $HistoryCSV -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $ExcludeFile)) {
        throw "exclude-tags.txt was not found next to this script."
    }

    Update-HistoryHTML
}

function Get-HistoryEntries {
    if (-not (Test-Path -LiteralPath $HistoryCSV)) {
        return @()
    }

    return @(Import-Csv -LiteralPath $HistoryCSV)
}

# =========================
# HTML HISTORY + TAG LIBRARY
# =========================

function Update-HistoryHTML {
    $Entries = @(Get-HistoryEntries)
    [array]::Reverse($Entries)

    $Groups = [ordered]@{}

    try {
        $Groups = Get-ExclusionGroups
    }
    catch {
        $Groups = [ordered]@{}
    }

    $TagCards = [System.Text.StringBuilder]::new()
    $TotalTags = 0

    foreach ($GroupName in $Groups.Keys) {
        $SafeGroup = [System.Net.WebUtility]::HtmlEncode([string]$GroupName)
        $Tags = @($Groups[$GroupName])
        $TotalTags += $Tags.Count

        $TagItems = [System.Text.StringBuilder]::new()

        foreach ($Tag in $Tags) {
            $SafeTag = [System.Net.WebUtility]::HtmlEncode([string]$Tag)
            [void]$TagItems.AppendLine("<span class=`"tag-chip`">$SafeTag</span>")
        }

        $TagCard = @"
<details class="tag-group">
  <summary>
    <span>$SafeGroup</span>
    <span class="tag-count">$($Tags.Count) tags</span>
  </summary>
  <div class="tag-list">
    $($TagItems.ToString())
  </div>
</details>
"@
        [void]$TagCards.AppendLine($TagCard)
    }

    if ($Groups.Count -eq 0) {
        [void]$TagCards.AppendLine(
            '<div class="empty">No exclusion groups could be loaded.</div>'
        )
    }

    $Cards = [System.Text.StringBuilder]::new()

    foreach ($Entry in $Entries) {
        $Date = [System.Net.WebUtility]::HtmlEncode([string]$Entry.Date)
        $Tags = [System.Net.WebUtility]::HtmlEncode([string]$Entry.SearchTags)
        $SelectedGroups = [System.Net.WebUtility]::HtmlEncode([string]$Entry.ExclusionGroups)
        $Destination = [System.Net.WebUtility]::HtmlEncode([string]$Entry.Destination)
        $URL = [System.Net.WebUtility]::HtmlEncode([string]$Entry.FinalURL)
        $Status = [System.Net.WebUtility]::HtmlEncode([string]$Entry.Status)

        $SearchText = [System.Net.WebUtility]::HtmlEncode(
            "$Date $Tags $SelectedGroups $Destination $URL $Status"
        )

        $StatusClass = switch ($Entry.Status) {
            "Completed" { "completed" }
            "Failed"    { "failed" }
            default     { "started" }
        }

        $Card = @"
<article class="entry" data-search="$SearchText">
  <details>
    <summary>
      <span class="entry-date">$Date</span>
      <span class="status $StatusClass">$Status</span>
      <span class="arrow">+</span>
    </summary>
    <div class="details">
      <h3>Search tags</h3>
      <p>$Tags</p>
      <h3>Exclusion groups used</h3>
      <p>$SelectedGroups</p>
      <h3>Destination</h3>
      <p class="path">$Destination</p>
      <h3>Final URL</h3>
      <div class="url-box">
        <a href="$URL" target="_blank" rel="noopener noreferrer">Open final URL</a>
        <button type="button" class="copy" data-url="$URL">Copy URL</button>
        <textarea readonly class="url-text">$URL</textarea>
      </div>
    </div>
  </details>
</article>
"@
        [void]$Cards.AppendLine($Card)
    }

    if ($Entries.Count -eq 0) {
        [void]$Cards.AppendLine(
            '<div class="empty">No history yet. Your confirmed runs will appear here.</div>'
        )
    }

    $TotalRuns = $Entries.Count
    $GroupCount = $Groups.Count

    $LatestRun = if ($Entries.Count -gt 0) {
        [System.Net.WebUtility]::HtmlEncode([string]$Entries[0].Date)
    }
    else {
        "None yet"
    }

    $HTML = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rule34 Download History</title>
<style>
:root {
  color-scheme: dark;
  --bg: #21151c;
  --panel: #33202b;
  --panel2: #422735;
  --pink: #ffb6c9;
  --light: #ffdce7;
  --muted: #d5b2c0;
  --border: #704557;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 28px 16px;
  background: var(--bg);
  color: var(--light);
  font-family: "Segoe UI", Arial, sans-serif;
}
main { max-width: 1000px; margin: auto; }
header { text-align: center; margin-bottom: 28px; }
header h1, h2 { color: var(--pink); }
header p { color: var(--muted); }
.stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin: 22px 0;
}
.stat, .entry, .searchbox, .tag-group {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 14px;
}
.stat { padding: 18px; }
.stat-label { color: var(--muted); font-size: 12px; }
.stat-value { color: var(--pink); font-size: 23px; margin-top: 8px; }
.searchbox {
  display: block;
  width: 100%;
  padding: 14px;
  margin-bottom: 18px;
  background: var(--panel2);
  color: var(--light);
  outline-color: var(--pink);
}
.entry { margin-bottom: 12px; overflow: hidden; }
summary {
  list-style: none;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 18px;
  cursor: pointer;
}
summary::-webkit-details-marker { display: none; }
.entry-date { flex: 1; font-weight: 600; }
.status { border-radius: 20px; padding: 5px 10px; font-size: 12px; }
.completed { background: #254837; color: #b9f2ce; }
.failed { background: #542d3c; color: #ffc1d1; }
.started { background: #57452a; color: #ffe3a8; }
.arrow { color: var(--pink); font-size: 20px; }
details[open] .arrow { transform: rotate(45deg); }
.details { border-top: 1px solid var(--border); padding: 18px; }
h3 { color: var(--pink); font-size: 14px; margin: 16px 0 7px; }
.details p { overflow-wrap: anywhere; line-height: 1.5; }
.path { font-family: Consolas, monospace; font-size: 13px; }
.url-box {
  background: var(--panel2);
  padding: 14px;
  border-radius: 10px;
  overflow-wrap: anywhere;
}
a { color: var(--pink); }
button {
  cursor: pointer;
  color: #381f2a;
  background: var(--pink);
  border: 0;
  border-radius: 8px;
  padding: 8px 12px;
  margin: 8px 0;
  font-weight: 600;
}
.url-text {
  display: block;
  width: 100%;
  min-height: 75px;
  margin-top: 10px;
  padding: 10px;
  resize: vertical;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg);
  color: var(--light);
  overflow-wrap: anywhere;
}
.empty { padding: 24px; color: var(--muted); text-align: center; }
.tag-group { margin-bottom: 10px; overflow: hidden; }
.tag-group summary { color: var(--light); }
.tag-count {
  color: var(--pink);
  background: var(--panel2);
  border-radius: 20px;
  padding: 5px 10px;
  font-size: 12px;
}
.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 16px;
  border-top: 1px solid var(--border);
}
.tag-chip {
  display: inline-block;
  background: var(--panel2);
  color: var(--light);
  border: 1px solid var(--border);
  padding: 5px 9px;
  border-radius: 8px;
  font-size: 12px;
  overflow-wrap: anywhere;
}
.section-heading { margin: 34px 0 16px; }
.section-description { color: var(--muted); line-height: 1.5; }
footer { text-align: center; color: var(--muted); font-size: 12px; margin-top: 25px; }
@media (max-width: 700px) {
  .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 520px) {
  body { padding: 20px 10px; }
  summary { padding: 13px; gap: 7px; }
  .entry-date { font-size: 13px; }
  .status { font-size: 10px; }
}
</style>
</head>
<body>
<main>
<header>
  <h1>Rule34 Download History</h1>
  <p>Download history and your current exclusion-tag library</p>
</header>

<section class="stats">
  <div class="stat">
    <div class="stat-label">TOTAL RUNS</div>
    <div class="stat-value">$TotalRuns</div>
  </div>
  <div class="stat">
    <div class="stat-label">LATEST RUN</div>
    <div class="stat-value">$LatestRun</div>
  </div>
  <div class="stat">
    <div class="stat-label">EXCLUSION GROUPS</div>
    <div class="stat-value">$GroupCount</div>
  </div>
  <div class="stat">
    <div class="stat-label">TOTAL TAGS</div>
    <div class="stat-value">$TotalTags</div>
  </div>
</section>

<h2 class="section-heading">Current Tag Library</h2>
<p class="section-description">
These groups and tags are read from exclude-tags.txt when this dashboard is generated.
After editing your tag library, reopen or refresh this page to see the saved changes.
</p>
<section id="tag-library">
$($TagCards.ToString())
</section>

<h2 class="section-heading">Download History</h2>
<input id="search" class="searchbox" type="search"
       placeholder="Search history by tags, dates, URLs, or destinations...">
<section id="history">
$($Cards.ToString())
</section>

<footer>Generated by Rule34-Downloader.ps1 · Refresh to see updates</footer>
</main>
<script>
const search = document.getElementById("search");
search.addEventListener("input", () => {
  const term = search.value.toLowerCase();
  document.querySelectorAll(".entry").forEach(entry => {
    entry.hidden = !entry.dataset.search.toLowerCase().includes(term);
  });
});

document.querySelectorAll(".copy").forEach(button => {
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.url);
      button.textContent = "Copied!";
    } catch {
      const box = button.parentElement.querySelector(".url-text");
      box.focus();
      box.select();
      button.textContent = "Select and copy";
    }
  });
});
</script>
</body>
</html>
"@

    Set-Content -LiteralPath $HistoryHTML -Value $HTML -Encoding UTF8
}

# =========================
# HISTORY OPERATIONS
# =========================

function Add-HistoryEntry {
    param(
        [string]$Date,
        [string]$SearchTags,
        [string]$ExclusionGroups,
        [string]$Destination,
        [string]$FinalURL,
        [string]$Status
    )

    [PSCustomObject]@{
        Date            = $Date
        SearchTags      = $SearchTags
        ExclusionGroups = $ExclusionGroups
        Destination     = $Destination
        FinalURL        = $FinalURL
        Status          = $Status
    } | Export-Csv -LiteralPath $HistoryCSV `
        -Append -NoTypeInformation -Encoding UTF8

    Update-HistoryHTML
}

function Update-LastHistoryStatus {
    param(
        [string]$FinalURL,
        [string]$RunDate,
        [string]$NewStatus
    )

    $Entries = @(Get-HistoryEntries)

    for ($i = $Entries.Count - 1; $i -ge 0; $i--) {
        if (
            $Entries[$i].FinalURL -ceq $FinalURL -and
            $Entries[$i].Date -ceq $RunDate -and
            $Entries[$i].Status -eq "Started"
        ) {
            $Entries[$i].Status = $NewStatus
            break
        }
    }

    if ($Entries.Count -gt 0) {
        $Entries | Export-Csv -LiteralPath $HistoryCSV `
            -NoTypeInformation -Encoding UTF8
    }

    Update-HistoryHTML
}

function Clear-AllHistory {
    Write-Host ""
    Write-Host "$Rose This permanently removes every history entry.$Reset"
    Write-Host "$SoftPink Your downloaded files will NOT be deleted.$Reset"

    $Answer = Read-Host "Type Y to clear ALL history"

    if ($Answer.Trim() -notmatch '^(?i:y|yes)$') {
        Write-Host "$BabyPink Cancelled. History was not changed.$Reset"
        return
    }

    '"Date","SearchTags","ExclusionGroups","Destination","FinalURL","Status"' |
        Set-Content -LiteralPath $HistoryCSV -Encoding UTF8

    Update-HistoryHTML
    Write-Host "$Pink All history cleared.$Reset"
}

function Clear-OldestHalf {
    $Entries = @(Get-HistoryEntries)

    if ($Entries.Count -eq 0) {
        Write-Host "$BabyPink History is already empty.$Reset"
        return
    }

    $DeleteCount = [math]::Floor($Entries.Count / 2)
    $KeepCount = $Entries.Count - $DeleteCount

    if ($DeleteCount -eq 0) {
        Write-Host "$BabyPink There is only one entry. Nothing to delete.$Reset"
        return
    }

    Write-Host ""
    Write-Host "$Rose Total history entries: $($Entries.Count)$Reset"
    Write-Host "$Rose Oldest entries to delete: $DeleteCount$Reset"
    Write-Host "$BabyPink Newest entries to keep: $KeepCount$Reset"

    $Answer = Read-Host "Type Y to delete the oldest half"

    if ($Answer.Trim() -notmatch '^(?i:y|yes)$') {
        Write-Host "$BabyPink Cancelled. History was not changed.$Reset"
        return
    }

    $Remaining = @($Entries | Select-Object -Skip $DeleteCount)

    if ($Remaining.Count -gt 0) {
        $Remaining | Export-Csv -LiteralPath $HistoryCSV `
            -NoTypeInformation -Encoding UTF8
    }
    else {
        '"Date","SearchTags","ExclusionGroups","Destination","FinalURL","Status"' |
            Set-Content -LiteralPath $HistoryCSV -Encoding UTF8
    }

    Update-HistoryHTML

    Write-Host "$Pink Removed $DeleteCount oldest entries.$Reset"
    Write-Host "$BabyPink Preserved $($Remaining.Count) newest entries.$Reset"
}

# =========================
# MANAGE EXCLUSION TAGS
# =========================

function Manage-ExclusionTags {
    while ($true) {
        try {
            $Groups = Get-ExclusionGroups
        }
        catch {
            Write-Host "$Rose $($_.Exception.Message)$Reset"
            return
        }

        $GroupNames = @($Groups.Keys)

        Show-Title
        Show-Section "MANAGE EXCLUSION TAGS"

        for ($i = 0; $i -lt $GroupNames.Count; $i++) {
            Write-Host "$BabyPink $($i + 1).$Reset $($GroupNames[$i]) ($($Groups[$GroupNames[$i]].Count) tags)"
        }

        Write-Host ""
        Write-Host "$BabyPink B.$Reset Back to main menu"
        Write-Host ""

        $Choice = (Read-Host "Choose a group").Trim()

        if ($Choice -match '^(?i:b|back)$') {
            return
        }

        if ($Choice -notmatch '^\d+$') {
            Write-Host "$Rose Invalid selection.$Reset"
            Read-Host "Press Enter to continue"
            continue
        }

        $Index = [int]$Choice - 1

        if ($Index -lt 0 -or $Index -ge $GroupNames.Count) {
            Write-Host "$Rose Group number is out of range.$Reset"
            Read-Host "Press Enter to continue"
            continue
        }

        $SelectedGroup = $GroupNames[$Index]
        $TagList = [System.Collections.Generic.List[string]]::new()

        foreach ($Tag in $Groups[$SelectedGroup]) {
            $TagList.Add([string]$Tag)
        }

        $Changed = $false

        while ($true) {
            Show-Title
            Show-Section "GROUP: $SelectedGroup"

            for ($i = 0; $i -lt $TagList.Count; $i++) {
                Write-Host "$BabyPink $($i + 1).$Reset $($TagList[$i])"
            }

            Write-Host ""
            Write-Host "$BabyPink A.$Reset Add a tag"
            Write-Host "$BabyPink R.$Reset Remove tag(s)"
            Write-Host "$BabyPink S.$Reset Save changes"
            Write-Host "$BabyPink B.$Reset Back to groups"
            Write-Host ""

            $Action = (Read-Host "Choose an action").Trim()

            switch -Regex ($Action) {
                '^(?i:a|add)$' {
                    $NewTag = (Read-Host "Enter the tag without a leading minus sign").Trim()
                    $NewTag = $NewTag.TrimStart("@").Trim()

                    if ([string]::IsNullOrWhiteSpace($NewTag)) {
                        Write-Host "$Rose Tag cannot be empty.$Reset"
                    }
                    elseif ($NewTag -match '[\s,]') {
                        Write-Host "$Rose Enter one tag only, without spaces or commas.$Reset"
                    }
                    elseif (@($TagList | Where-Object { $_ -ieq $NewTag }).Count -gt 0) {
                        Write-Host "$Rose That tag already exists in this group.$Reset"
                    }
                    else {
                        $TagList.Add($NewTag)
                        $Changed = $true
                        Write-Host "$Pink Added: $NewTag$Reset"
                    }

                    Read-Host "Press Enter to continue"
                    continue
                }

                '^(?i:r|remove)$' {
                    if ($TagList.Count -eq 0) {
                        Write-Host "$BabyPink This group has no tags to remove.$Reset"
                        Read-Host "Press Enter to continue"
                        continue
                    }

                    $RemoveInput = Read-Host "Enter tag numbers separated by commas"
                    $Numbers = @(
                        $RemoveInput -split ',' |
                            ForEach-Object { $_.Trim() } |
                            Where-Object { $_ -ne "" }
                    )

                    $IndexesToRemove = @()

                    foreach ($Number in $Numbers) {
                        if ($Number -notmatch '^\d+$') {
                            Write-Host "$Rose Invalid tag number: $Number$Reset"
                            continue
                        }

                        $RemoveIndex = [int]$Number - 1

                        if ($RemoveIndex -lt 0 -or $RemoveIndex -ge $TagList.Count) {
                            Write-Host "$Rose Tag number out of range: $Number$Reset"
                            continue
                        }

                        if ($IndexesToRemove -notcontains $RemoveIndex) {
                            $IndexesToRemove += $RemoveIndex
                        }
                    }

                    foreach ($RemoveIndex in ($IndexesToRemove | Sort-Object -Descending)) {
                        Write-Host "$SoftPink Removed: $($TagList[$RemoveIndex])$Reset"
                        $TagList.RemoveAt($RemoveIndex)
                        $Changed = $true
                    }

                    Read-Host "Press Enter to continue"
                    continue
                }

                '^(?i:s|save)$' {
                    if (-not $Changed) {
                        Write-Host "$BabyPink No unsaved changes.$Reset"
                        Read-Host "Press Enter to continue"
                        continue
                    }

                    try {
                        $Backup = "$ExcludeFile.bak"
                        Copy-Item -LiteralPath $ExcludeFile -Destination $Backup -Force

                        $AllGroups = Get-ExclusionGroups
                        $AllGroups[$SelectedGroup] = $TagList

                        $Output = [System.Collections.Generic.List[string]]::new()
                        $Output.Add("# ==========================================")
                        $Output.Add("# RULE34 EXCLUSION TAGS")
                        $Output.Add("# Selectable groups for the PowerShell downloader.")
                        $Output.Add("# One tag per line. Lines beginning with # are comments.")
                        $Output.Add("# ==========================================")
                        $Output.Add("")

                        foreach ($Name in $AllGroups.Keys) {
                            $Output.Add("# GROUP: $Name")

                            foreach ($Tag in $AllGroups[$Name]) {
                                $Output.Add([string]$Tag)
                            }

                            $Output.Add("")
                        }

                        Set-Content -LiteralPath $ExcludeFile `
                            -Value $Output -Encoding UTF8

                        $Changed = $false
                        Update-HistoryHTML

                        Write-Host "$Pink Changes saved successfully.$Reset"
                        Write-Host "$BabyPink Backup: $Backup$Reset"
                    }
                    catch {
                        Write-Host "$Rose Could not save changes: $($_.Exception.Message)$Reset"
                    }

                    Read-Host "Press Enter to continue"
                    continue
                }

                '^(?i:b|back)$' {
                    if ($Changed) {
                        $Unsaved = Read-Host "You have unsaved changes. Type S to save, or D to discard"

                        if ($Unsaved.Trim() -match '^(?i:s|save)$') {
                            try {
                                Copy-Item -LiteralPath $ExcludeFile `
                                    -Destination "$ExcludeFile.bak" -Force

                                $AllGroups = Get-ExclusionGroups
                                $AllGroups[$SelectedGroup] = $TagList

                                $Output = [System.Collections.Generic.List[string]]::new()
                                $Output.Add("# RULE34 EXCLUSION TAGS")

                                foreach ($Name in $AllGroups.Keys) {
                                    $Output.Add("# GROUP: $Name")
                                    foreach ($Tag in $AllGroups[$Name]) {
                                        $Output.Add([string]$Tag)
                                    }
                                    $Output.Add("")
                                }

                                Set-Content -LiteralPath $ExcludeFile `
                                    -Value $Output -Encoding UTF8

                                Update-HistoryHTML
                            }
                            catch {
                                Write-Host "$Rose Save failed: $($_.Exception.Message)$Reset"
                                Read-Host "Press Enter to continue editing"
                                continue
                            }
                        }
                        elseif ($Unsaved.Trim() -notmatch '^(?i:d|discard)$') {
                            continue
                        }
                    }

                    break
                }

                default {
                    Write-Host "$Rose Invalid action.$Reset"
                    Read-Host "Press Enter to continue"
                    continue
                }
            }

            if ($Action -match '^(?i:b|back)$') {
                break
            }
        }
    }
}

# =========================
# BATCH RERUN
# =========================

function Invoke-HistoryBatch {
    $Entries = @(Get-HistoryEntries)

    $Batch = @(
        $Entries | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.FinalURL) -and
            -not [string]::IsNullOrWhiteSpace($_.Destination)
        }
    )

    if ($Batch.Count -eq 0) {
        Write-Host "$BabyPink No usable history links were found.$Reset"
        return
    }

    $GalleryDL = Get-Command gallery-dl -ErrorAction SilentlyContinue

    if (-not $GalleryDL) {
        Write-Host "$Rose gallery-dl was not found. Check your installation and PATH.$Reset"
        return
    }

    Show-Section "BATCH RERUN PREVIEW"

    Write-Host "$BabyPink Links to rerun: $($Batch.Count)$Reset"
    Write-Host "$SoftPink Links run in saved history order. Each rerun creates a new history entry.$Reset"
    Write-Host ""

    $PreviewLimit = [math]::Min($Batch.Count, 10)

    for ($i = 0; $i -lt $PreviewLimit; $i++) {
        Write-Host "$BabyPink $($i + 1). $($Batch[$i].Date)$Reset"
        Write-Host "$SoftPink    $($Batch[$i].FinalURL)$Reset"
        Write-Host "$SoftPink    Destination: $($Batch[$i].Destination)$Reset"
    }

    if ($Batch.Count -gt $PreviewLimit) {
        Write-Host "$SoftPink ... and $($Batch.Count - $PreviewLimit) more links.$Reset"
    }

    Write-Host ""
    Write-Host "$Rose Existing files may be downloaded again, depending on gallery-dl settings.$Reset"

    $Confirm = Read-Host "Run ALL history links in one batch? (Y/N)"

    if ($Confirm.Trim() -notmatch '^(?i:y|yes)$') {
        Write-Host "$BabyPink Batch cancelled.$Reset"
        return
    }

    $Completed = 0
    $Failed = 0

    for ($i = 0; $i -lt $Batch.Count; $i++) {
        $OldEntry = $Batch[$i]
        $URL = [string]$OldEntry.FinalURL
        $Destination = [string]$OldEntry.Destination

        Write-Host ""
        Show-Decoration
        Write-Host "$Pink BATCH ITEM $($i + 1) OF $($Batch.Count)$Reset"
        Write-Host "$SoftPink URL: $URL$Reset"
        Write-Host "$SoftPink Destination: $Destination$Reset"

        try {
            if (-not (Test-Path -LiteralPath $Destination)) {
                New-Item -ItemType Directory -Path $Destination -Force |
                    Out-Null
            }
        }
        catch {
            Write-Host "$Rose Could not create destination: $($_.Exception.Message)$Reset"
            $Failed++
            continue
        }

        $RunDate = Get-Date -Format 'MMM dd, h:mm tt'

        try {
            Add-HistoryEntry `
                -Date $RunDate `
                -SearchTags ([string]$OldEntry.SearchTags) `
                -ExclusionGroups ([string]$OldEntry.ExclusionGroups) `
                -Destination $Destination `
                -FinalURL $URL `
                -Status "Started"

            & $GalleryDL.Source --no-colors -D $Destination $URL
            $ExitCode = $LASTEXITCODE

            $Status = if ($ExitCode -eq 0) { "Completed" } else { "Failed" }

            Update-LastHistoryStatus -FinalURL $URL -RunDate $RunDate -NewStatus $Status

            if ($ExitCode -eq 0) {
                $Completed++
                Write-Host "$Pink Link finished successfully.$Reset"
            }
            else {
                $Failed++
                Write-Host "$Rose Link failed with exit code $ExitCode.$Reset"
            }
        }
        catch {
            $Failed++
            Write-Host "$Rose Error processing link: $($_.Exception.Message)$Reset"
        }
    }

    Write-Host ""
    Show-DoubleDecoration
    Write-Host "$Pink BATCH FINISHED$Reset"
    Write-Host "$BabyPink Total links: $($Batch.Count)$Reset"
    Write-Host "$Pink Completed: $Completed$Reset"
    Write-Host "$Rose Failed: $Failed$Reset"
    Write-Host ""
    Write-Host "$BabyPink HTML history: $HistoryHTML$Reset"
    Write-Host "$BabyPink CSV history: $HistoryCSV$Reset"
}

# =========================
# NEW DOWNLOAD WORKFLOW
# =========================

function Invoke-NewDownload {
    $GalleryDL = Get-Command gallery-dl -ErrorAction SilentlyContinue

    if (-not $GalleryDL) {
        Stop-Script "gallery-dl was not found. Install it or check your PATH."
    }

    try {
        $Groups = Get-ExclusionGroups
    }
    catch {
        Stop-Script $_.Exception.Message
    }

    $GroupNames = @($Groups.Keys)

    if ($GroupNames.Count -eq 0) {
        Stop-Script "No exclusion groups were found in exclude-tags.txt."
    }

    Show-Title
    Show-Section "SEARCH TAGS"

    Write-Host "$SoftPink Enter 1 to 3 tags, separated by commas.$Reset"
    Write-Host "$SoftPink Example: solo, blue_hair, smiling$Reset"
    Write-Host ""

    $RawTags = Read-Host "Search tags"

    $SearchTags = @(
        $RawTags -split '[,\s]+' |
            ForEach-Object { $_.Trim().Replace(" ", "_") } |
            Where-Object { $_ -ne "" }
    )

    if ($SearchTags.Count -lt 1 -or $SearchTags.Count -gt 3) {
        Stop-Script "Enter between 1 and 3 search tags."
    }

    foreach ($Tag in $SearchTags) {
        if ($Tag -match '[&=?#%+]') {
            Stop-Script "Tag '$Tag' contains a character that is not allowed here."
        }
    }

    Show-Section "EXCLUSION GROUPS"

    for ($i = 0; $i -lt $GroupNames.Count; $i++) {
        Write-Host "$BabyPink $($i + 1).$Reset $($GroupNames[$i]) ($($Groups[$GroupNames[$i]].Count) tags)"
    }

    Write-Host ""
    Write-Host "$BabyPink A.$Reset All groups"
    Write-Host "$BabyPink N.$Reset No exclusions"
    Write-Host ""

    $GroupChoice = (Read-Host "Choose group numbers separated by commas, A, or N").Trim()
    $SelectedGroupNames = @()

    if ($GroupChoice -match '^(?i:a|all)$') {
        $SelectedGroupNames = @($GroupNames)
    }
    elseif ($GroupChoice -match '^(?i:n|none)$') {
        $SelectedGroupNames = @()
    }
    else {
        $Selections = @(
            $GroupChoice -split ',' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -ne "" }
        )

        if ($Selections.Count -eq 0) {
            Stop-Script "No valid exclusion selection was entered."
        }

        foreach ($Selection in $Selections) {
            if ($Selection -notmatch '^\d+$') {
                Stop-Script "Invalid exclusion selection: $Selection"
            }

            $Index = [int]$Selection - 1

            if ($Index -lt 0 -or $Index -ge $GroupNames.Count) {
                Stop-Script "Exclusion group number is out of range: $Selection"
            }

            $SelectedName = $GroupNames[$Index]

            if ($SelectedGroupNames -notcontains $SelectedName) {
                $SelectedGroupNames += $SelectedName
            }
        }
    }

    $ExcludeTags = @()

    foreach ($Name in $SelectedGroupNames) {
        $ExcludeTags += @($Groups[$Name])
    }

    $ExcludeTags = @($ExcludeTags | Select-Object -Unique)

    Show-Section "DESTINATION FOLDER"

    if (-not (Test-Path -LiteralPath $RootFolder)) {
        New-Item -ItemType Directory -Path $RootFolder -Force | Out-Null
    }

    Write-Host "$SoftPink Root folder: $RootFolder$Reset"
    $FolderInput = (Read-Host "Enter a destination subfolder name").Trim()

    if ([string]::IsNullOrWhiteSpace($FolderInput)) {
        Stop-Script "Folder name cannot be empty."
    }

    if ($FolderInput -match '[<>:"/\\|?*\x00-\x1F]') {
        Stop-Script "Folder name contains invalid Windows characters."
    }

    if ($FolderInput -match '[. ]$') {
        Stop-Script "Folder names cannot end with a period or space."
    }

    $BaseName = ($FolderInput -split '\.')[0]

    if ($BaseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        Stop-Script "That folder name is reserved by Windows."
    }

    $ExistingFolder = Get-ChildItem -LiteralPath $RootFolder -Directory |
        Where-Object { $_.Name -ieq $FolderInput } |
        Select-Object -First 1

    if ($ExistingFolder) {
        $Destination = $ExistingFolder.FullName
        Write-Host "$BabyPink Existing folder found. It will be reused.$Reset"
    }
    else {
        $TextInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
        $FolderName = $TextInfo.ToTitleCase($FolderInput.ToLowerInvariant())
        $Destination = Join-Path $RootFolder $FolderName
    }

    $AllTags = @($SearchTags) + @($ExcludeTags)

    $EncodedTags = @(
        foreach ($Tag in $AllTags) {
            [Uri]::EscapeDataString([string]$Tag)
        }
    ) -join "+"

    $Url = "$Rule34Base$EncodedTags"

    Show-Title
    Show-Section "DOWNLOAD PREVIEW"

    Write-Host "$BabyPink Search tags:$Reset"
    foreach ($Tag in $SearchTags) {
        Write-Host "  $SoftPink - $Tag$Reset"
    }

    Write-Host ""
    Write-Host "$BabyPink Exclusion groups:$Reset"

    if ($SelectedGroupNames.Count -gt 0) {
        foreach ($Name in $SelectedGroupNames) {
            Write-Host "  $SoftPink - $Name$Reset"
        }
    }
    else {
        Write-Host "  $SoftPink None$Reset"
    }

    Write-Host ""
    Write-Host "$BabyPink Total exclusion tags: $($ExcludeTags.Count)$Reset"
    Write-Host "$BabyPink Destination: $Destination$Reset"
    Write-Host ""
    Write-Host "$BabyPink Final URL:$Reset"
    Write-Host "$SoftPink $Url$Reset"
    Write-Host ""
    Write-Host "$BabyPink Command:$Reset"
    Write-Host "$SoftPink gallery-dl --no-colors -D `"$Destination`" `"$Url`"$Reset"
    Write-Host ""

    Show-DoubleDecoration
    Write-Host ""

    $Confirm = Read-Host "Start download? (Y/N)"

    if ($Confirm.Trim() -notmatch '^(?i:y|yes)$') {
        Stop-Script "Download cancelled. Nothing was added to history."
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $RunDate = Get-Date -Format 'MMM dd, h:mm tt'
    $TagHistory = $SearchTags -join ", "

    $GroupHistory = if ($SelectedGroupNames.Count -gt 0) {
        $SelectedGroupNames -join ", "
    }
    else {
        "None"
    }

    try {
        Add-HistoryEntry `
            -Date $RunDate `
            -SearchTags $TagHistory `
            -ExclusionGroups $GroupHistory `
            -Destination $Destination `
            -FinalURL $Url `
            -Status "Started"
    }
    catch {
        Stop-Script "Could not save history: $($_.Exception.Message)"
    }

    Show-Section "RUNNING DOWNLOAD"

    try {
        & $GalleryDL.Source --no-colors -D $Destination $Url
        $DownloadExitCode = $LASTEXITCODE
    }
    catch {
        Write-Host "$Rose gallery-dl error: $($_.Exception.Message)$Reset"
        $DownloadExitCode = 1
    }

    $FinalStatus = if ($DownloadExitCode -eq 0) {
        "Completed"
    }
    else {
        "Failed"
    }

    try {
        Update-LastHistoryStatus `
            -FinalURL $Url `
            -RunDate $RunDate `
            -NewStatus $FinalStatus
    }
    catch {
        Write-Host "$Rose Could not update history status: $($_.Exception.Message)$Reset"
    }

    Write-Host ""

    if ($DownloadExitCode -eq 0) {
        Write-Host "$Pink Download process finished successfully.$Reset"
    }
    else {
        Write-Host "$Rose gallery-dl exited with code $DownloadExitCode.$Reset"
    }

    Write-Host ""
    Write-Host "$BabyPink HTML history: $HistoryHTML$Reset"
    Write-Host "$BabyPink CSV backup: $HistoryCSV$Reset"
    Write-Host "$BabyPink Destination: $Destination$Reset"
    Write-Host ""

    Read-Host "Press Enter to return to the main menu"
}

# =========================
# STARTUP
# =========================

try {
    Initialize-History
}
catch {
    Write-Host "$Rose Startup error: $($_.Exception.Message)$Reset"
    Read-Host "Press Enter to exit"
    return
}

# =========================
# MAIN MENU
# =========================

while ($true) {
    Show-Title

    Write-Host "$BabyPink 1.$Reset Start a new download"
    Write-Host "$BabyPink 2.$Reset Rerun ALL history links in one batch"
    Write-Host "$BabyPink 3.$Reset Clear ALL history"
    Write-Host "$BabyPink 4.$Reset Clear the OLDEST HALF of history"
    Write-Host "$BabyPink 5.$Reset Open HTML history dashboard"
    Write-Host "$BabyPink 6.$Reset Manage exclusion tags"
    Write-Host "$Rose 7.$Reset Exit"
    Write-Host ""

    $MenuChoice = Read-Host "Choose an option"

    switch ($MenuChoice.Trim()) {
        "1" {
            try {
                Invoke-NewDownload
            }
            catch {
                if ($_.Exception.Message -ne "RETURN_TO_MENU") {
                    Write-Host ""
                    Write-Host "$Rose Unexpected error: $($_.Exception.Message)$Reset"
                    Read-Host "Press Enter to return to the main menu"
                }
            }
        }

        "2" {
            Invoke-HistoryBatch
            Read-Host "Press Enter to return to the main menu"
        }

        "3" {
            Clear-AllHistory
            Read-Host "Press Enter to return to the main menu"
        }

        "4" {
            Clear-OldestHalf
            Read-Host "Press Enter to return to the main menu"
        }

        "5" {
            Update-HistoryHTML
            Start-Process $HistoryHTML
            Read-Host "Press Enter to return to the main menu"
        }

        "6" {
            Manage-ExclusionTags
            Update-HistoryHTML
            Read-Host "Press Enter to return to the main menu"
        }

        "7" {
            Write-Host ""
            Write-Host "$BabyPink Thank you for using the downloader!$Reset"
            break
        }

        default {
            Write-Host "$Rose Invalid menu choice.$Reset"
            Read-Host "Press Enter to return to the main menu"
        }
    }

    if ($MenuChoice.Trim() -eq "7") {
        break
    }
}