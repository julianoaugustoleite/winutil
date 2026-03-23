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
        [string]$RegFile,

        [Parameter(Mandatory = $true)]
        [string]$PresetName
    )

    try {
        if (-not (Assert-BMNvidiaInstalled)) {
            return
        }

        if (!(Test-Path $RegFile)) {
            throw "Arquivo nao encontrado:`n$RegFile"
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

        & reg.exe import "$RegFile" | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "O Windows retornou erro ao importar o arquivo .reg."
        }

        Show-BMInfoMessage `
            -Message "Preset NVIDIA aplicado com sucesso:`n$PresetName`n`nRecomendacao: execute o botao 'Reset NVIDIA' ou reinicie o computador para garantir a recarga completa do driver." `
            -Title "BM InfoTech - NVIDIA" `
            -Icon ([System.Windows.MessageBoxImage]::Information)
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
    try {
        if (-not (Assert-BMNvidiaInstalled)) {
            return
        }

        $paths = Get-BMNvidiaPaths
        $npi = $paths.NpiExe
        $nip = $paths.NipProfile

        if (!(Test-Path $npi)) {
            throw "NVIDIA Profile Inspector nao encontrado:`n$npi"
        }

        if (!(Test-Path $nip)) {
            throw "Perfil .NIP nao encontrado:`n$nip"
        }

        $confirmMessage = @"
Voce esta prestes a importar o perfil NVIDIA da BM InfoTech.

Arquivo:
$nip

Deseja continuar?
"@

        if (-not (Confirm-BMAction -Message $confirmMessage -Title "BM InfoTech - Confirmar importacao")) {
            return
        }

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
                -Title "BM InfoTech - Atenção NVIDIA" `
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
    $paths = Get-BMNvidiaPaths
    Invoke-BMNvidiaRegImport -RegFile $paths.RegFull -PresetName "Apply GPU Tweaks (FULL)"
}

function Invoke-WPFNvidiaRegSimple {
    $paths = Get-BMNvidiaPaths
    Invoke-BMNvidiaRegImport -RegFile $paths.RegSimple -PresetName "Apply GPU Tweaks (SIMPLE)"
}

function Invoke-WPFNvidiaRegRemove {
    $paths = Get-BMNvidiaPaths
    Invoke-BMNvidiaRegImport -RegFile $paths.RegRemove -PresetName "Remove GPU Tweaks (GPU Only)"
}
