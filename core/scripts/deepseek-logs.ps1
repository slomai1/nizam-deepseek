# deepseek-logs.ps1 - monitor gateway/MCP error patterns in session history
# Usage: powershell -File deepseek-logs.ps1 [lineCount, default 5000]
# Reports distribution of 429/403/401/timeout/connection errors in last N lines of history.jsonl

param([int]$Lines = 5000)

$hist = "$env:USERPROFILE\.claude\history.jsonl"
if (-not (Test-Path $hist)) {
    Write-Host "WARNING: history.jsonl not found - no session data" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Scanning gateway/MCP error patterns in last $Lines lines ===" -ForegroundColor Cyan

# NOTE: this scans *displayed user text* in history.jsonl, not raw API responses.
# Numeric patterns alone (e.g. "429") produce false positives from timestamps/code,
# so we only match contextual error phrases.
$categories = [ordered]@{
    'rate limit'        = 'rate\s*limit|too many requests|429\s*too\s*many|hit the rate'
    'auth error'        = '403\s*forbidden|401\s*unauthorized|permission denied|access denied'
    'timeout/connection' = 'timed\s*out|connection\s*(timed|refused|closed)|ECONN|network error|offline'
    'gateway/upstream'  = 'bad gateway|502|504|upstream error|gateway error'
    'MCP not connected' = 'not connected|mcp.*(failed|error)|extension is not connected'
}

$counts = @{}
$samples = @{}

Get-Content $hist -Tail $Lines | ForEach-Object {
    $line = $_
    foreach ($cat in $categories.Keys) {
        if ($line -match $categories[$cat]) {
            $counts[$cat] = [int]$counts[$cat] + 1
            if (-not $samples[$cat]) { $samples[$cat] = $line.Substring(0, [Math]::Min(120, $line.Length)) }
        }
    }
}

$total = ($counts.Values | Measure-Object -Sum).Sum
if ($total -eq 0) {
    Write-Host "OK: no gateway/MCP error patterns in range" -ForegroundColor Green
} else {
    Write-Host "Total signals: $total" -ForegroundColor Yellow
    foreach ($cat in $categories.Keys) {
        if ($counts[$cat] -gt 0) {
            Write-Host ""
            Write-Host "[$cat] - $($counts[$cat])" -ForegroundColor Red
            Write-Host "   sample: $($samples[$cat])"
        }
    }
    Write-Host ""
    Write-Host "Hint: repeated 429 -> consider rate limits; repeated MCP disconnected -> use local CLI fallback (see OPS Fallback section)." -ForegroundColor DarkYellow
}
