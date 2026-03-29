function Get-BMWinUtilBasePath {

    if ($global:BMWinUtilBasePath) {
        return $global:BMWinUtilBasePath
    }

    if ($sync -and $sync.PSScriptRoot) {
        return $sync.PSScriptRoot
    }

    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($PSCommandPath) {
        return (Split-Path -Parent $PSCommandPath)
    }

    throw "Nao foi possivel localizar a pasta base do BM InfoTech Toolbox."
}

function Get-BMNvidiaPaths {
    $base = Get-BMWinUtilBasePath
    Write-Host "BM NVIDIA BASE: $base"

    @{
        Base       = $base
        NpiExe     = Join-Path $base "npi\nvidiaProfileInspector.exe"
        NipProfile = Join-Path $base "profiles\BM_Profile.nip"
        RegFull    = Join-Path $base "reg\Full.reg"
        RegSimple  = Join-Path $base "reg\Simple.reg"
        RegRemove  = Join-Path $base "reg\Remove.reg"
    }
}

function Test-BMNvidiaDriverInstalled {
    try {
        $displayDevices = pnputil /enum-devices /connected /class Display 2>$null
        if (-not $displayDevices) {
            return $false
        }

        $joined = ($displayDevices | Out-String)
        return ($joined -match "NVIDIA")
    }
    catch {
        return $false
    }
}

function Get-BMNvidiaDisplayInstanceId {
    try {
        $lines = pnputil /enum-devices /connected /class Display 2>$null
        if (-not $lines) {
            return $null
        }

        $currentBlock = @()
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                if (($currentBlock | Out-String) -match "NVIDIA") {
                    $idLine = $currentBlock | Where-Object { $_ -match "Instance ID" } | Select-Object -First 1
                    if ($idLine) {
                        return (($idLine -split ":", 2)[1].Trim())
                    }
                }
                $currentBlock = @()
            }
            else {
                $currentBlock += $line
            }
        }

        if (($currentBlock | Out-String) -match "NVIDIA") {
            $idLine = $currentBlock | Where-Object { $_ -match "Instance ID" } | Select-Object -First 1
            if ($idLine) {
                return (($idLine -split ":", 2)[1].Trim())
            }
        }

        return $null
    }
    catch {
        return $null
    }
}

function Show-BMInfoMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Title = "BM InfoTech",

        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )

    [System.Windows.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.MessageBoxButton]::OK,
        $Icon
    ) | Out-Null
}

function Confirm-BMAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Title = "BM InfoTech"
    )

    $result = [System.Windows.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

function Assert-BMNvidiaInstalled {
    if (-not (Test-BMNvidiaDriverInstalled)) {
        Show-BMInfoMessage `
            -Message "Nenhum driver NVIDIA ativo foi encontrado neste computador.`n`nEssa acao esta disponivel apenas para maquinas com placa/driver NVIDIA instalado." `
            -Title "BM InfoTech - NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Warning)

        return $false
    }

    return $true
}

function Invoke-BMNvidiaRegImport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegContent,

        [Parameter(Mandatory = $true)]
        [string]$PresetName
    )

    try {
        if (-not (Assert-BMNvidiaInstalled)) {
            return
        }

        $confirmMessage = @"
Voce esta prestes a aplicar o preset NVIDIA:

$PresetName

Essa acao altera configuracoes do Windows/driver por arquivo .reg.

Deseja continuar?
"@

        if (-not (Confirm-BMAction -Message $confirmMessage -Title "BM InfoTech - Confirmar aplicacao")) {
            return
        }

        Import-BMEmbeddedRegContent -RegContent $RegContent -PresetName $PresetName
    }
    catch {
        Show-BMInfoMessage `
            -Message "Nao foi possivel aplicar o preset NVIDIA.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}

function Invoke-WPFNvidiaResetSettings {
    try {
        if (-not (Assert-BMNvidiaInstalled)) {
            return
        }

        $confirmMessage = @"
Voce esta prestes a resetar as configuracoes do driver NVIDIA.

Essa acao ira:
- remover os bancos de perfis DRS da NVIDIA
- solicitar a recriacao desses arquivos pelo driver
- tentar reiniciar o dispositivo de video NVIDIA

Deseja continuar?
"@

        if (-not (Confirm-BMAction -Message $confirmMessage -Title "BM InfoTech - Confirmar reset NVIDIA")) {
            return
        }

        Remove-Item "$env:ProgramData\NVIDIA Corporation\Drs\nvdrsdb0.bin" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:ProgramData\NVIDIA Corporation\Drs\nvdrsdb1.bin" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:ProgramData\NVIDIA Corporation\Drs\nvdrssel.bin" -Force -ErrorAction SilentlyContinue

        $instanceId = Get-BMNvidiaDisplayInstanceId
        if ($instanceId) {
            pnputil /restart-device $instanceId | Out-Null
        }

        Show-BMInfoMessage `
            -Message "Reset NVIDIA concluido com sucesso.`n`nSe perceber qualquer comportamento diferente, reinicie o computador para finalizar a recarga do driver." `
            -Title "BM InfoTech - NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Information)
    }
    catch {
        Show-BMInfoMessage `
            -Message "Falha ao resetar as configuracoes da NVIDIA.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}

function Invoke-WPFNvidiaImportProfile {
    $npi = $null
    $nip = $null

    try {
        if (-not (Assert-BMNvidiaInstalled)) {
            return
        }

        $confirmMessage = @"
Voce esta prestes a importar o perfil NVIDIA da BM InfoTech.

O utilitario necessario sera baixado temporariamente, executado e removido ao final.

Deseja continuar?
"@

        if (-not (Confirm-BMAction -Message $confirmMessage -Title "BM InfoTech - Confirmar importacao")) {
            return
        }

        $npi = Get-BMTempNvidiaProfileInspector
        $nip = New-BMTempNipFile

        & $npi -import $nip 2>$null
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            & $npi /import $nip 2>$null
            $exitCode = $LASTEXITCODE
        }

        if ($exitCode -ne 0) {
            Start-Process $npi -ArgumentList "`"$nip`""
            Start-Process explorer.exe "/select,`"$nip`""

            Show-BMInfoMessage `
                -Message "O NVIDIA Profile Inspector desta versao nao aceitou a importacao automatica.`n`nO programa foi aberto e o arquivo de perfil foi destacado para importacao manual." `
                -Title "BM InfoTech - Atencao NVIDIA" `
                -Icon ([System.Windows.MessageBoxImage]::Warning)
        }
        else {
            Show-BMInfoMessage `
                -Message "Perfil NVIDIA importado com sucesso." `
                -Title "BM InfoTech - NVIDIA" `
                -Icon ([System.Windows.MessageBoxImage]::Information)
        }
    }
    catch {
        Show-BMInfoMessage `
            -Message "Falha ao importar o perfil NVIDIA.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }

}

function Invoke-WPFNvidiaRegFull {
    Invoke-BMNvidiaRegImport `
        -RegContent (Get-BMEmbeddedRegFull) `
        -PresetName "Apply GPU Tweaks (FULL)"
}

function Invoke-WPFNvidiaRegSimple {
    Invoke-BMNvidiaRegImport `
        -RegContent (Get-BMEmbeddedRegSimple) `
        -PresetName "Apply GPU Tweaks (SIMPLE)"
}

function Invoke-WPFNvidiaRegRemove {
    Invoke-BMNvidiaRegImport `
        -RegContent (Get-BMEmbeddedRegRemove) `
        -PresetName "Remove GPU Tweaks (GPU Only)"
}


function Get-BMEmbeddedRegFull {
@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\GameBar]
"ShowStartupPanel"=dword:00000000
"GamePanelStartupTipIndex"=dword:00000003
"AllowAutoGameMode"=dword:00000000
"AutoGameModeEnabled"=dword:00000000
"UseNexusForGameBarEnabled"=dword:00000000

[HKEY_CURRENT_USER\System\GameConfigStore]
"GameDVR_Enabled"=dword:00000000
"GameDVR_FSEBehaviorMode"=dword:00000002
"GameDVR_FSEBehavior"=dword:00000002
"GameDVR_HonorUserFSEBehaviorMode"=dword:00000001
"GameDVR_DXGIHonorFSEWindowsCompatible"=dword:00000001
"GameDVR_EFSEFeatureFlags"=dword:00000000
"GameDVR_DSEBehavior"=dword:00000002

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
"AllowGameDVR"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR]
"AppCaptureEnabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters]
"EnablePrefetcher"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters]
"EnableSuperfetch"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000]
"DisableDynamicPstate"=dword:00000001
"EnablePerformanceMode"=dword:00000001
"PerfLevelSrc"=dword:00002222
"PowerMizerEnable"=dword:00000001
"PowerMizerLevel"=dword:00000001
"PowerMizerLevelAC"=dword:00000001
"PowerMizerDefault"=dword:00000001
"PowerMizerDefaultAC"=dword:00000001
"PowerMizerHardLevel"=dword:00000001
"PowerMizerHardLevelAC"=dword:00000001
"PP_DisableULPS"=dword:00000001
"EnableUlps"=dword:00000000
"EnableUlps_NA"=dword:00000000
'@
}

function Get-BMEmbeddedRegSimple {
@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\System\GameConfigStore]
"GameDVR_Enabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
"AllowGameDVR"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR]
"AppCaptureEnabled"=dword:00000000
'@
}

function Get-BMEmbeddedRegRemove {
@'
Windows Registry Editor Version 5.00

; Remove todos os tweaks do Full.reg

[HKEY_CURRENT_USER\Software\Microsoft\GameBar]
"ShowStartupPanel"=-
"GamePanelStartupTipIndex"=-
"AllowAutoGameMode"=-
"AutoGameModeEnabled"=-
"UseNexusForGameBarEnabled"=-

[HKEY_CURRENT_USER\System\GameConfigStore]
"GameDVR_Enabled"=-
"GameDVR_FSEBehaviorMode"=-
"GameDVR_FSEBehavior"=-
"GameDVR_HonorUserFSEBehaviorMode"=-
"GameDVR_DXGIHonorFSEWindowsCompatible"=-
"GameDVR_EFSEFeatureFlags"=-
"GameDVR_DSEBehavior"=-

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
"AllowGameDVR"=-

[HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR]
"AppCaptureEnabled"=-

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters]
"EnablePrefetcher"=-
"EnableSuperfetch"=-

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000]
"DisableDynamicPstate"=-
"EnablePerformanceMode"=-
"PerfLevelSrc"=-
"PowerMizerEnable"=-
"PowerMizerLevel"=-
"PowerMizerLevelAC"=-
"PowerMizerDefault"=-
"PowerMizerDefaultAC"=-
"PowerMizerHardLevel"=-
"PowerMizerHardLevelAC"=-
"PP_DisableULPS"=-
"EnableUlps"=-
"EnableUlps_NA"=-
'@
}

function Get-BMEmbeddedNipProfile {
@'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>523190</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Negative LOD bias</SettingNameInfo>
        <SettingID>1686376</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync Tear Control</SettingNameInfo>
        <SettingID>5912412</SettingID>
        <SettingValue>2525368439</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Driver Controlled LOD Bias</SettingNameInfo>
        <SettingID>6524559</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred refresh rate</SettingNameInfo>
        <SettingID>6600001</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Ambient Occlusion</SettingNameInfo>
        <SettingID>6714153</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Maximum pre-rendered frames</SettingNameInfo>
        <SettingID>8102046</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Enable sample interleaving (MFAA)</SettingNameInfo>
        <SettingID>10011052</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync</SettingNameInfo>
        <SettingID>11041231</SettingID>
        <SettingValue>138504007</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>12991097</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Quality</SettingNameInfo>
        <SettingID>13510289</SettingID>
        <SettingValue>20</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>14366803</SettingID>
        <SettingValue>3</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>14366808</SettingID>
        <SettingValue>128</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture filtering - Anisotropic sample optimization</SettingNameInfo>
        <SettingID>15151633</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Flag to control smooth AFR behavior</SettingNameInfo>
        <SettingID>270198627</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Power management mode</SettingNameInfo>
        <SettingID>274197361</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Enable FXAA</SettingNameInfo>
        <SettingID>276089202</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Gamma correction</SettingNameInfo>
        <SettingID>276652957</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Mode</SettingNameInfo>
        <SettingID>276757595</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>VRR requested state</SettingNameInfo>
        <SettingID>278196727</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>G-SYNC</SettingNameInfo>
        <SettingID>279476687</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Enable G-SYNC globally</SettingNameInfo>
        <SettingID>294973784</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Event Log Tmon Severity Threshold</SettingNameInfo>
        <SettingID>539527361</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>OpenGL default swap interval</SettingNameInfo>
        <SettingID>543843714</SettingID>
        <SettingValue>4026531840</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>High level control of the rendering quality on OpenGL</SettingNameInfo>
        <SettingID>544832876</SettingID>
        <SettingValue>20</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Line gamma</SettingNameInfo>
        <SettingID>545898348</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Maximum frames allowed</SettingNameInfo>
        <SettingID>546199011</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Event Log Severity Threshold</SettingNameInfo>
        <SettingID>547222078</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo>
        <SettingID>550564838</SettingID>
        <SettingValue>id,2.0:250410DE,00000700,GF - (368,6,161,12288) @ (0)</SettingValue>
        <ValueType>String</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>550870746</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>552789362</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Triple buffering</SettingNameInfo>
        <SettingID>553505273</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo />
        <SettingID>1343646814</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@
}

function Import-BMEmbeddedRegContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegContent,

        [Parameter(Mandatory = $true)]
        [string]$PresetName
    )

    $tempRegFile = Join-Path $env:TEMP ("BM_NVIDIA_" + [guid]::NewGuid().ToString() + ".reg")

    try {
        Set-Content -Path $tempRegFile -Value $RegContent -Encoding Unicode

        & reg.exe import "$tempRegFile" | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "O Windows retornou erro ao importar o arquivo .reg temporario."
        }

        Show-BMInfoMessage `
            -Message "Preset NVIDIA aplicado com sucesso:`n$PresetName`n`nRecomendacao: execute o botao 'Reset NVIDIA' ou reinicie o computador para garantir a recarga completa do driver." `
            -Title "BM InfoTech - NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Information)
    }
    finally {
        Remove-Item $tempRegFile -Force -ErrorAction SilentlyContinue
    }
}

function New-BMTempNipFile {
    $tempNipFile = Join-Path $env:TEMP ("BM_Profile_" + [guid]::NewGuid().ToString() + ".nip")
    Set-Content -Path $tempNipFile -Value (Get-BMEmbeddedNipProfile) -Encoding ASCII
    return $tempNipFile
}

function Get-BMTempNvidiaProfileInspector {

    $url = "https://github.com/julianoaugustoleite/winutil/raw/main/npi/nvidiaProfileInspector.exe"

    $tempDir = "C:\Temp"
    $tempExe = Join-Path $tempDir "nvidiaProfileInspector.exe"

    if (!(Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory | Out-Null
    }

    # FORÇA baixar sempre (sobrescreve)
    Invoke-WebRequest -Uri $url -OutFile $tempExe -UseBasicParsing

    if (!(Test-Path $tempExe)) {
        throw "Falha ao baixar o NVIDIA Profile Inspector."
    }

    # valida tamanho mínimo (evita arquivo corrompido)
    if ((Get-Item $tempExe).Length -lt 500000) {
        Remove-Item $tempExe -Force
        throw "Arquivo baixado corrompido."
    }

    return $tempExe
}

