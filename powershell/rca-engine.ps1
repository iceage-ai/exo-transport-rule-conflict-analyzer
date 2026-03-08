param(
  [string]$InputPath,
  [string]$AffectedUser = "Any User",
  [string]$AffectedUserEmail = "any.user@example.com",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function New-RcaResult {
  param(
    [string]$Category,
    [double]$Confidence,
    [string]$Reason,
    [string[]]$Diagnostics,
    [string[]]$NextSteps
  )

  [PSCustomObject]@{
    AffectedUser      = $AffectedUser
    AffectedUserEmail = $AffectedUserEmail
    Category          = $Category
    Confidence        = [math]::Round($Confidence,2)
    Reason            = $Reason
    Diagnostics       = $Diagnostics
    NextSteps         = $NextSteps
    TimestampUtc      = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  }
}

$signals = @{
  MicrosoftDelayPct = 0.0
  ExternalDelayPct  = 0.0
  PolicyHits        = 0
  RetryEvents       = 0
  AuthFailures      = 0
  RuleConflicts     = 0
}

try {
  if ($InputPath) {
    if (-not (Test-Path $InputPath)) { throw "Input file not found: $InputPath" }
    $obj = Get-Content $InputPath -Raw | ConvertFrom-Json
    foreach ($k in $signals.Keys) {
      if ($obj.PSObject.Properties.Name -contains $k) { $signals[$k] = [double]$obj.$k }
    }
  }

  $result = $null

  if ($signals.AuthFailures -ge 3) {
    $result = New-RcaResult -Category "Auth/identity path failure" -Confidence 0.86 -Reason "Authentication failures crossed threshold and likely drive incident." -Diagnostics @(
      "Validate sign-in logs and protocol used",
      "Check conditional access / MFA / legacy auth blocks",
      "Confirm token/client freshness"
    ) -NextSteps @(
      "Move client path to modern auth only",
      "Re-authenticate affected principal and retest",
      "Create guardrail alert for repeated auth failures"
    )
  }
  elseif ($signals.RuleConflicts -ge 1) {
    $result = New-RcaResult -Category "Configuration/rule conflict" -Confidence 0.81 -Reason "Detected rule conflict signal; deterministic policy path is broken." -Diagnostics @(
      "Export and sort rule priority",
      "Inspect stop-processing and overlapping conditions",
      "Run controlled A/B message path test"
    ) -NextSteps @(
      "Disable or reorder conflicting rule set",
      "Re-test with same sample and compare latency/outcome",
      "Document final intended rule precedence"
    )
  }
  elseif ($signals.MicrosoftDelayPct -ge 60) {
    $result = New-RcaResult -Category "Microsoft-side processing" -Confidence 0.82 -Reason "Majority of delay occurred inside EXO processing stages." -Diagnostics @(
      "Correlate internal hop durations",
      "Check service health timeline",
      "Build evidence pack with UTC timestamps"
    ) -NextSteps @(
      "Open Microsoft support case with evidence",
      "Track SLA breach window and affected domains",
      "Enable temporary alerting for similar latency"
    )
  }
  elseif ($signals.ExternalDelayPct -ge 60) {
    $result = New-RcaResult -Category "External/Internet path" -Confidence 0.79 -Reason "Dominant delay is after Microsoft handoff." -Diagnostics @(
      "Validate remote MX and TLS handshake timings",
      "Review deferral/retry patterns",
      "Compare latency by destination domain"
    ) -NextSteps @(
      "Share trace evidence with recipient admin",
      "Tune retry expectations and communications",
      "Separate external latency KPI from EXO processing KPI"
    )
  }
  elseif ($signals.PolicyHits -ge 2 -or $signals.RetryEvents -ge 3) {
    $result = New-RcaResult -Category "Policy/throttling pressure" -Confidence 0.73 -Reason "Policy hits and retry events indicate control-plane pressure." -Diagnostics @(
      "Inspect anti-spam/transport policy hit counters",
      "Check automation concurrency and backoff behavior",
      "Audit connector and sender reputation context"
    ) -NextSteps @(
      "Apply scoped policy tuning with safety limits",
      "Introduce exponential backoff + jitter for automation",
      "Re-run triage after 1 hour to verify stability"
    )
  }
  else {
    $result = New-RcaResult -Category "Mixed/low-signal" -Confidence 0.58 -Reason "No dominant root cause from provided signals." -Diagnostics @(
      "Collect longer time window",
      "Increase sample size and include control messages",
      "Cross-check client-vs-server behavior"
    ) -NextSteps @(
      "Run targeted test matrix (one variable at a time)",
      "Capture before/after evidence per change",
      "Promote the first stable path as baseline"
    )
  }

  if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
}
catch {
  Write-Error "RCA engine failed: $($_.Exception.Message)"
  exit 1
}
