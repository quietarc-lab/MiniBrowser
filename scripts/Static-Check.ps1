[CmdletBinding()]
param(
    [switch]$PublicMetadata
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Description)
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($content -notmatch $Pattern) {
        throw "Missing requirement: $Description ($Path)"
    }
}

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Description)
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($content -match $Pattern) {
        throw "Unexpected content: $Description ($Path)"
    }
}

$projectFile = Join-Path $projectRoot 'project.yml'
$uaFile = Join-Path $projectRoot 'MiniBrowser\Models\BrowserUserAgent.swift'
$viewModelFile = Join-Path $projectRoot 'MiniBrowser\ViewModels\BrowserViewModel.swift'
$webViewFile = Join-Path $projectRoot 'MiniBrowser\Web\BrowserWebView.swift'
$inputZoomFile = Join-Path $projectRoot 'MiniBrowser\Services\InputAutoZoomPreventionService.swift'
$focusModeFile = Join-Path $projectRoot 'MiniBrowser\Services\CompactPageModeService.swift'
$handwritingServiceFile = Join-Path $projectRoot 'MiniBrowser\Services\CanvasImageSessionService.swift'
$listServiceFile = Join-Path $projectRoot 'MiniBrowser\Services\ThreadListService.swift'
$listViewFile = Join-Path $projectRoot 'MiniBrowser\Views\ThreadListView.swift'
$listViewModelFile = Join-Path $projectRoot 'MiniBrowser\ViewModels\ThreadListViewModel.swift'
$infoFile = Join-Path $projectRoot 'MiniBrowser\Info.plist'
$workflowFile = Join-Path $projectRoot '.github\workflows\reusable-ios-unsigned-build-deliver.yml'
$deliveryScriptFile = Join-Path $projectRoot 'scripts\Deliver-Ipa.ps1'
$javaScriptValidationFile = Join-Path $projectRoot 'scripts\Validate-InjectedJavaScript.mjs'
$specFile = Join-Path $projectRoot 'MiniBrowser_Codex_Spec.md'
$agentsFile = Join-Path $projectRoot 'AGENTS.md'

Assert-Contains $projectFile 'iOS:\s*"26\.0"' 'iOS 26 deployment target'
Assert-Contains $webViewFile 'WKWebViewConfiguration' 'WKWebView configuration'
Assert-Contains $webViewFile 'websiteDataStore\s*=\s*\.default\(\)' 'persistent website data store'
Assert-Contains $webViewFile 'InputAutoZoomPreventionService\.install' 'input focus auto-zoom prevention'
Assert-Contains $inputZoomFile 'fontSize\s*<\s*16' 'small input font-size guard'
Assert-Contains $inputZoomFile 'forMainFrameOnly:\s*false' 'input auto-zoom prevention in subframes'
Assert-Contains $focusModeFile 'MiniBrowser\.TargetPageDraftEnabled' 'global TargetPage draft setting'
Assert-Contains $focusModeFile 'clearEmail' 'empty TargetPage email guard'
Assert-Contains $focusModeFile 'preserveDeleteKey' 'preserved TargetPage deletion key'
Assert-NotContains $focusModeFile 'fixedDeleteKey' 'no forced TargetPage deletion key'
Assert-NotContains $focusModeFile 'deleteInput\.readOnly\s*=\s*true' 'editable TargetPage deletion key'
Assert-Contains $focusModeFile 'textarea\.rows\s*=\s*2' 'compact TargetPage comment field'
Assert-Contains $focusModeFile 'disableFormPositionToggle' 'disabled TargetPage form position switch'
Assert-Contains $focusModeFile 'localStorage\.removeItem\("MiniBrowser\.TargetPageFormPlacement"\)' 'cleared legacy TargetPage form placement setting'
Assert-NotContains $focusModeFile 'minibrowser-targetpage-form-placement' 'no MiniBrowser form placement control'
Assert-NotContains $focusModeFile 'latestOwnResponse\.table\.after\(form\)' 'no bottom placement after own response'
Assert-NotContains $focusModeFile 'minibrowser-targetpage-submit-status' 'no MiniBrowser submit status slot'
Assert-Contains $focusModeFile '#retmestip' 'hidden TargetPage submit status'
Assert-Contains $focusModeFile 'capturePostState' 'TargetPage draft capture on posting'
Assert-Contains $focusModeFile 'postCompleted' 'TargetPage post completion handwriting bridge'
Assert-Contains $focusModeFile 'initializeCompactPage' 'retryable TargetPage compact-page initialization'
Assert-Contains $listServiceFile 'bytes=0-32767' 'bounded TargetPage opener request'
Assert-Contains $listServiceFile 'limit:\s*Int\s*=\s*60' 'sixty-item TargetPage list limit'
Assert-Contains $listServiceFile 'replyCount\s*<\s*1_000' 'completed TargetPage thread exclusion'
Assert-Contains $listViewModelFile 'listItemLimit\s*=\s*60' 'sixty-item TargetPage list request'
Assert-Contains $listViewModelFile 'mergingDisplayState' 'list thumbnail state preservation across refresh'
Assert-Contains $listViewFile 'LazyVGrid' 'native two-column TargetPage list'
Assert-Contains $listViewFile 'model\.recordOpen\(item\)' 'persistent TargetPage list open counter'
Assert-Contains $listViewFile 'thumbnailData' 'explicit TargetPage thumbnail rendering'
Assert-Contains $listServiceFile 'makeThumbnailRequest' 'explicit TargetPage thumbnail request'
Assert-Contains $listServiceFile 'updateUserAgent' 'selected UA propagation to TargetPage list requests'
Assert-Contains $listViewModelFile 'setNetworkActivityAllowed' 'TargetPage list pause during identity refresh'
Assert-Contains $focusModeFile 'modeHeader\.classList\.add' 'hidden TargetPage response-mode header'
Assert-Contains $webViewFile 'CanvasImageSessionService\.install' 'TargetPage handwriting session bridge installation'
Assert-Contains $webViewFile 'WKScriptMessageHandler' 'TargetPage handwriting native message receiver'
Assert-Contains $handwritingServiceFile 'miniBrowserHandwriting' 'TargetPage handwriting message handler'
Assert-Contains $handwritingServiceFile 'input\.id !== "itgkfile"' 'existing handwriting input-only image capture'
Assert-Contains $handwritingServiceFile 'canvas#oejs' 'existing handwriting canvas-only restoration'
Assert-Contains $handwritingServiceFile 'pageReady' 'TargetPage handwriting page-ready signal'
Assert-Contains $handwritingServiceFile 'openExistingCanvasScript' 'existing handwriting control opener'
Assert-Contains $webViewFile 'case "postCompleted"' 'TargetPage post-completion handwriting receiver'
Assert-Contains $handwritingServiceFile 'context\.fillRect\(x, y, 1, 1\)' 'single-pixel handwriting image variation'
Assert-Contains $handwritingServiceFile 'maximumImageDataByteCount = 3_000_000' 'bounded in-memory handwriting image size'
Assert-Contains $projectFile 'ASSETCATALOG_COMPILER_APPICON_NAME:\s*AppIcon' 'AppIcon asset compiler setting'

$listViewModelText = Get-Content -LiteralPath $listViewModelFile -Raw -Encoding UTF8
if ($listViewModelText -match 'withTaskGroup|withThrowingTaskGroup') {
    throw 'TargetPage opener loading must avoid the task-group completion crash seen on iOS 26.5.2.'
}
Assert-Contains $viewModelFile 'CookieDomainMatcher' 'site-related cookie filter'
Assert-Contains $viewModelFile 'minibrowser://return' 'MiniBrowser callback URL'
Assert-Contains $viewModelFile 'isIdentityRefreshInProgress' 'UA identity refresh state'
Assert-Contains $viewModelFile 'deleteRelatedCookiesForRefresh' 'UA cookie deletion before AP reconnect'
Assert-Contains $viewModelFile 'evaluateJavaScript' 'bookmarklet execution'
Assert-Contains $workflowFile 'CODE_SIGNING_ALLOWED=NO' 'unsigned build'
Assert-Contains $workflowFile 'actions/download-artifact@v8' 'artifact download on Windows'
Assert-Contains $deliveryScriptFile 'MINIBROWSER_DELIVERY_DIRECTORY' 'runner-local delivery directory'
Assert-Contains $specFile '# MiniBrowser 実装仕様書' 'canonical product specification'
Assert-Contains $agentsFile 'quietarc-lab/MiniBrowser' 'canonical repository rule'
Assert-Contains $agentsFile 'GitHub Issues' 'issue handoff rule'

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw 'Node.js is required to validate injected JavaScript.'
}
& $node.Source $javaScriptValidationFile $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw 'Injected JavaScript syntax validation failed.'
}

$uaText = Get-Content -LiteralPath $uaFile -Raw -Encoding UTF8
$uaCount = ([regex]::Matches($uaText, '\.init\(id:\s*\d+')).Count
if ($uaCount -ne 10) {
    throw "Expected exactly 10 user agents, found $uaCount."
}
$uaValues = [regex]::Matches($uaText, 'value:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if (($uaValues | Select-Object -Unique).Count -ne 10) {
    throw 'Expected 10 distinct user-agent strings.'
}
if ($uaValues -match 'CPU (iPhone )?OS 26_') {
    throw 'iOS 26 UA profiles must use the frozen iOS 18 OS token.'
}

[xml]$plist = Get-Content -LiteralPath $infoFile -Raw -Encoding UTF8
if ($plist.plist.dict.key -notcontains 'CFBundleURLTypes') {
    throw 'CFBundleURLTypes is missing from Info.plist.'
}
if ($plist.plist.dict.key -notcontains 'UISupportedInterfaceOrientations') {
    throw 'Portrait orientation declaration is missing from Info.plist.'
}

if ($plist.plist.dict.key -notcontains 'CFBundleIconName') {
    throw 'CFBundleIconName is missing from Info.plist.'
}

$appIconContents = Join-Path $projectRoot 'MiniBrowser\Assets.xcassets\AppIcon.appiconset\Contents.json'
if (-not (Test-Path -LiteralPath $appIconContents)) {
    throw 'AppIcon asset list is missing.'
}
$marketingIcon = Join-Path $projectRoot 'MiniBrowser\Assets.xcassets\AppIcon.appiconset\Icon-1024.png'
if (-not (Test-Path -LiteralPath $marketingIcon)) {
    throw '1024px App Store icon is missing.'
}

$inputZoomText = Get-Content -LiteralPath $inputZoomFile -Raw -Encoding UTF8
if ($inputZoomText -match 'maximum-scale|user-scalable|pinchGestureRecognizer') {
    throw 'Manual pinch zoom must remain enabled.'
}

$cookieValueLeaks = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'MiniBrowser') -Filter '*.swift' -Recurse |
    Select-String -Pattern 'cookie\.value' -CaseSensitive:$false
if ($cookieValueLeaks) {
    throw 'Cookie values must not be accessed or logged.'
}

if ($PublicMetadata) {
    # Construct audit needles without retaining legacy identifiers as searchable text.
    $legacySiteTerm = -join [char[]](102, 117, 116, 97, 98, 97)
    $legacyJapaneseTerm = -join [char[]](0x3075, 0x305f, 0x3070)
    $legacyBoardTerm = -join [char[]](0x4e8c, 0x6b21, 0x5143, 0x88cf)
    $legacyCompanionTerm = -join [char[]](102, 117, 116, 97, 107, 117, 114, 111)
    $legacyAccountTerm = -join [char[]](115, 116, 97, 107, 97, 110, 111, 49, 50, 51, 45, 97, 49, 49, 121)
    $legacyHostToken = -join [char[]](50, 99, 104, 97, 110)
    $legacyLocalUser = -join [char[]](115, 116, 97, 107, 97)
    $legacyPathTerm = "C:\Users\$legacyLocalUser"
    $forbiddenTerms = @($legacySiteTerm, $legacyJapaneseTerm, $legacyBoardTerm, $legacyCompanionTerm, $legacyAccountTerm, $legacyPathTerm)
    $forbiddenPattern = '(?i)' + (($forbiddenTerms | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $allowedHostPattern = '(?i)(?:[a-z0-9-]+\.)*' + [regex]::Escape("$legacyHostToken.net")
    $allowedEndpoint = "$legacySiteTerm.php"
    $textFiles = @(git -C $projectRoot ls-files | Where-Object { $_ -notmatch '\.(png|jpe?g|gif|webp|ipa|zip)$' })
    foreach ($relativePath in $textFiles) {
        $path = Join-Path $projectRoot $relativePath
        $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        $content = $content -replace $allowedHostPattern, ''
        $content = $content.Replace($allowedEndpoint, '')
        if ($content -match $forbiddenPattern) {
            throw "Public metadata check found a forbidden term in $relativePath."
        }
    }

    $historyMetadata = git -C $projectRoot log --all --format='%an%n%ae%n%s'
    if ($historyMetadata -match $forbiddenPattern) {
        throw 'Public metadata check found a forbidden term in reachable Git history.'
    }
}

Write-Host 'Static checks passed.'
Write-Host "User agents: $uaCount"
Write-Host 'Distinct user-agent strings: 10'
Write-Host 'Cookie value access: none'
Write-Host 'Deployment target: iOS 26.0'
if ($PublicMetadata) {
    Write-Host 'Public metadata audit: passed'
}
