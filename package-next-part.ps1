[CmdletBinding()]
param(
    [string]$InputPath = '',
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($InputPath)) { $InputPath = Join-Path $PSScriptRoot 'Racoon-city-courier.rbxlx' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $PSScriptRoot 'Racoon-city-courier-next-part.rbxlx' }
$inputFull = [System.IO.Path]::GetFullPath($InputPath)
$outputFull = [System.IO.Path]::GetFullPath($OutputPath)
$workspaceFull = [System.IO.Path]::GetFullPath($PSScriptRoot)
if ($inputFull -eq $outputFull) { throw 'The output must be a separate place file.' }
if ([System.IO.Path]::GetDirectoryName($outputFull) -ne $workspaceFull) {
    throw 'The output must be in the packager workspace directory.'
}

function Get-Hash([string]$Path) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [System.BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '')
    } finally {
        $stream.Dispose()
        $algorithm.Dispose()
    }
}

function Read-Place([string]$Path) {
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try { $document.Load($reader) } finally { $reader.Dispose() }
    return ,$document
}

function Get-ScriptItem($Document, [string]$Class, [string]$Name) {
    $matches = $Document.SelectNodes("//Item[@class='$Class'][Properties/string[@name='Name' and text()='$Name']]")
    if ($matches.Count -gt 1) { throw "Duplicate $Class named $Name in place file." }
    if ($matches.Count -eq 1) { return $matches[0] }
    return $null
}

function Normalize-Lines([string]$Text) {
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Set-Source($Document, $Item, [string]$Source) {
    $properties = $Item.SelectSingleNode('Properties')
    $sourceNode = $properties.SelectSingleNode("ProtectedString[@name='Source']")
    if ($null -eq $sourceNode) {
        $sourceNode = $Document.CreateElement('ProtectedString')
        $sourceNode.SetAttribute('name', 'Source')
        [void]$properties.AppendChild($sourceNode)
    }
    $sourceNode.RemoveAll()
    $sourceNode.SetAttribute('name', 'Source')
    # Split the rare CDATA terminator without changing the stored source text.
    $chunks = [System.Text.RegularExpressions.Regex]::Split($Source, '(?<=]])(?=>)')
    foreach ($chunk in $chunks) {
        [void]$sourceNode.AppendChild($Document.CreateCDataSection($chunk))
    }
}

$replacements = @(
    @{ Name = 'HospitalLayout'; Class = 'Script'; File = 'HospitalLayout.server.lua' },
    @{ Name = 'CourierGame'; Class = 'Script'; File = 'CourierGame.server.lua' },
    @{ Name = 'CourierHUD'; Class = 'LocalScript'; File = 'CourierHUD.client.lua' },
    @{ Name = 'ForestTunnelEncounter'; Class = 'Script'; File = 'ForestTunnelEncounter.server.lua' },
    @{ Name = 'SurvivalWeaponServer'; Class = 'Script'; File = 'SurvivalWeaponServer.server.lua' },
    @{ Name = 'SurvivalWeaponClient'; Class = 'LocalScript'; File = 'SurvivalWeaponClient.client.lua' }
)
$additions = @(
    @{ Name = 'EscapeHouseBuilder'; Class = 'ModuleScript'; File = 'EscapeHouseBuilder.lua' },
    @{ Name = 'CourierVehicle'; Class = 'ModuleScript'; File = 'CourierVehicle.lua' },
    @{ Name = 'EscapeMutants'; Class = 'ModuleScript'; File = 'EscapeMutants.lua' },
    @{ Name = 'EscapeChapter'; Class = 'Script'; File = 'EscapeChapter.server.lua' }
)
$allScripts = $replacements + $additions
$snapshots = @{}
foreach ($entry in $allScripts) {
    $sourcePath = Join-Path $workspaceFull $entry.File
    $source = Normalize-Lines ([System.IO.File]::ReadAllText($sourcePath))
    if ([string]::IsNullOrWhiteSpace($source)) { throw "Empty source file: $sourcePath" }
    $snapshots[$entry.Name] = $source
}

$originalHash = Get-Hash $inputFull
$place = Read-Place $inputFull
$initialItemCount = $place.SelectNodes('//Item').Count
$serverScripts = $place.SelectSingleNode("/roblox/Item[@class='ServerScriptService']")
if ($null -eq $serverScripts) { throw 'ServerScriptService is missing from the original place.' }
$forest = $place.SelectSingleNode("/roblox/Item[@class='Workspace']/Item[@class='Model'][Properties/string[@name='Name' and text()='ForestTunnel']]")
if ($null -eq $forest -or $forest.SelectNodes('.//Item').Count -eq 0) {
    throw 'ForestTunnel geometry is missing; export the current Studio place before packaging.'
}
$forestBefore = $forest.OuterXml
$forestItemCount = $forest.SelectNodes('.//Item').Count

foreach ($entry in $replacements) {
    $item = Get-ScriptItem $place $entry.Class $entry.Name
    if ($null -eq $item) { throw "Original script missing: $($entry.Name)" }
    Set-Source $place $item $snapshots[$entry.Name]
}

$addedCount = 0
foreach ($entry in $additions) {
    $item = Get-ScriptItem $place $entry.Class $entry.Name
    if ($null -eq $item) {
        $item = $place.CreateElement('Item')
        $item.SetAttribute('class', $entry.Class)
        $item.SetAttribute('referent', 'RBX' + [Guid]::NewGuid().ToString('N').ToUpperInvariant())
        $properties = $place.CreateElement('Properties')
        [void]$item.AppendChild($properties)
        $nameNode = $place.CreateElement('string')
        $nameNode.SetAttribute('name', 'Name')
        $nameNode.InnerText = $entry.Name
        [void]$properties.AppendChild($nameNode)
        if ($entry.Class -eq 'Script') {
            $disabled = $place.CreateElement('bool')
            $disabled.SetAttribute('name', 'Disabled')
            $disabled.InnerText = 'false'
            [void]$properties.AppendChild($disabled)
            $runContext = $place.CreateElement('token')
            $runContext.SetAttribute('name', 'RunContext')
            $runContext.InnerText = '0'
            [void]$properties.AppendChild($runContext)
        }
        [void]$serverScripts.AppendChild($item)
        $addedCount++
    } elseif ($item.ParentNode -ne $serverScripts) {
        throw "$($entry.Name) already exists outside ServerScriptService."
    }
    Set-Source $place $item $snapshots[$entry.Name]
}

$temporaryPath = Join-Path $workspaceFull ('.next-part-' + [Guid]::NewGuid().ToString('N') + '.rbxlx.tmp')
$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writerSettings.Indent = $false
$writerSettings.OmitXmlDeclaration = $true
$writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::None
$writer = [System.Xml.XmlWriter]::Create($temporaryPath, $writerSettings)
try { $place.Save($writer) } finally { $writer.Dispose() }

# Validate the staged file before the atomic rename/replacement.
$validation = Read-Place $temporaryPath
$finalItemCount = $validation.SelectNodes('//Item').Count
if ($finalItemCount -ne $initialItemCount + $addedCount) { throw 'Unexpected instance count after packaging.' }
$validatedForest = $validation.SelectSingleNode("/roblox/Item[@class='Workspace']/Item[@class='Model'][Properties/string[@name='Name' and text()='ForestTunnel']]")
if ($validatedForest.OuterXml -cne $forestBefore) { throw 'ForestTunnel geometry changed during packaging.' }
$report = foreach ($entry in $allScripts) {
    $item = Get-ScriptItem $validation $entry.Class $entry.Name
    if ($null -eq $item) { throw "Packaged script is missing: $($entry.Name)" }
    $embedded = Normalize-Lines $item.SelectSingleNode("Properties/ProtectedString[@name='Source']").InnerText
    if ($embedded -cne $snapshots[$entry.Name]) { throw "Source verification failed: $($entry.Name)" }
    [pscustomobject]@{ Name = $entry.Name; Class = $entry.Class; Characters = $embedded.Length }
}
if ((Get-Hash $inputFull) -ne $originalHash) { throw 'Original place changed externally while packaging; rerun with a stable input.' }
if ([System.IO.File]::Exists($outputFull)) {
    $previousOutputPath = Join-Path $workspaceFull ('.next-part-previous-' + [Guid]::NewGuid().ToString('N') + '.rbxlx.tmp')
    [System.IO.File]::Replace($temporaryPath, $outputFull, $previousOutputPath)
    [System.IO.File]::Delete($previousOutputPath)
} else {
    [System.IO.File]::Move($temporaryPath, $outputFull)
}

$report | Format-Table -AutoSize
[pscustomobject]@{
    Output = $outputFull
    Bytes = (Get-Item -LiteralPath $outputFull).Length
    OriginalItems = $initialItemCount
    PackagedItems = $finalItemCount
    AddedItems = $addedCount
    ForestTunnelItemsPreserved = $forestItemCount
    OriginalSha256 = $originalHash
    OriginalUnmodified = ((Get-Hash $inputFull) -eq $originalHash)
} | Format-List
