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
    Confidence        = $Confidence
    Reason            = $Reason
    Diagnostics       = $Diagnostics
    NextSteps         = $NextSteps
    TimestampUtc      = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  }
}

# RULE-BASED ENGINE
# Replace this mock signal input with real EXO cmdlet output for production use.
$signals = @{
  MicrosoftDelayPct = 0.0
  ExternalDelayPct  = 0.0
  PolicyHits        = 0
  RetryEvents       = 0
  AuthFailures      = 0
  RuleConflicts     = 0
}

if ($InputPath -and (Test-Path $InputPath)) {
  $raw = Get-Content $InputPath -Raw
  if ($raw.Trim().StartsWith("{")) {
    $obj = $raw | ConvertFrom-Json
    foreach ($k in $signals.Keys) {
      if ($obj.PSObject.Properties.Name -contains $k) { $signals[$k] = [double]$obj.$k }
    }
  }
}

# Decision logic placeholder (project-specific rules expected)
if ($signals.MicrosoftDelayPct -ge 60) {
  $result = New-RcaResult -Category "Microsoft-side processing" -Confidence 0.82 -Reason "Delay profile indicates majority of latency occurred inside EXO pipeline." -Diagnostics @(
    "Inspect message trace detail internal hop durations",
    "Correlate with Service Health incident timeline",
    "Sample multiple Message IDs for consistency"
  ) -NextSteps @(
    "Open Microsoft support case with trace evidence pack",
    "Attach UTC timeline and affected domains",
    "Enable temporary SLA alert for >X minutes latency"
  )
}
elseif ($signals.ExternalDelayPct -ge 60) {
  $result = New-RcaResult -Category "Internet/remote domain" -Confidence 0.79 -Reason "Majority of latency is outside Microsoft handoff boundary." -Diagnostics @(
    "Validate recipient MX and TLS endpoint responsiveness",
    "Review remote deferral patterns and retry windows",
    "Compare delays across destination domains"
  ) -NextSteps @(
    "Share evidence with recipient admin",
    "Tune retry communications and user expectation",
    "Track external domain delay as separate KPI"
  )
}
else {
  $result = New-RcaResult -Category "Configuration/policy interplay" -Confidence 0.67 -Reason "No dominant path latency; likely policy/rule/connector interaction." -Diagnostics @(
    "Audit rule priority and stop-processing semantics",
    "Validate connector scope/cert/domain alignment",
    "Check auth/policy hit counters"
  ) -NextSteps @(
    "Run controlled before/after test with one variable change",
    "Remove overlapping conditions and re-measure",
    "Document final stable routing path"
  )
}

if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
