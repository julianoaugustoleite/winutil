function Show-BMFixMessage {
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

function Confirm-BMFixAction {
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

function Get-BMEmbeddedFix0011bReg {
@'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Print]
"RpcAuthnLevelPrivacyEnabled"=dword:00000000
'@
}

function Get-BMEmbeddedFix25022503Reg {
@'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System]
"EnableLUA"=dword:00000000
'@
}

function Import-BMEmbeddedRegFix {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegContent,

        [Parameter(Mandatory = $true)]
        [string]$FixName
    )

    $tempRegFile = Join-Path $env:TEMP ("BM_FIX_" + [guid]::NewGuid().ToString() + ".reg")

    try {
        Set-Content -Path $tempRegFile -Value $RegContent -Encoding Unicode

        & reg.exe import "$tempRegFile" | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "O Windows retornou erro ao importar o arquivo .reg temporario."
        }

        Show-BMFixMessage `
            -Message "$FixName aplicado com sucesso." `
            -Title "BM InfoTech - Fix" `
            -Icon ([System.Windows.MessageBoxImage]::Information)
    }
    finally {
        Remove-Item $tempRegFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WPFPrintFix0011b {
    try {
        $confirmMessage = @"
Voce esta prestes a aplicar o fix 0x0000011b.

Deseja continuar?
"@

        if (-not (Confirm-BMFixAction -Message $confirmMessage -Title "BM InfoTech - Confirmar fix")) {
            return
        }

        Import-BMEmbeddedRegFix `
            -RegContent (Get-BMEmbeddedFix0011bReg) `
            -FixName "Fix 0x0000011b"
    }
    catch {
        Show-BMFixMessage `
            -Message "Falha ao aplicar o Fix 0x0000011b.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}

function Invoke-WPFPrintFix25022503 {
    try {
        $confirmMessage = @"
Voce esta prestes a aplicar o fix 2502 - 2503.

Deseja continuar?
"@

        if (-not (Confirm-BMFixAction -Message $confirmMessage -Title "BM InfoTech - Confirmar fix")) {
            return
        }

        Import-BMEmbeddedRegFix `
            -RegContent (Get-BMEmbeddedFix25022503Reg) `
            -FixName "Fix 2502 - 2503"
    }
    catch {
        Show-BMFixMessage `
            -Message "Falha ao aplicar o Fix 2502 - 2503.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}

function Get-BMTempResetTool {
    $url = "COLE_AQUI_A_URL_DO_EXE"
    $tempExe = Join-Path $env:TEMP ("BM_ResetDNS_" + [guid]::NewGuid().ToString() + ".exe")

    Invoke-WebRequest -Uri $url -OutFile $tempExe -UseBasicParsing

    if (!(Test-Path $tempExe)) {
        throw "Nao foi possivel baixar a ferramenta de reset DNS."
    }

    return $tempExe
}

function Invoke-WPFPrintResetTool {
    try {
        $confirmMessage = @"
Voce esta prestes a executar a rotina de reset de rede e DNS.

Essa acao ira:
- renovar o IP da maquina
- limpar a tabela ARP
- recarregar nomes NetBIOS
- limpar o cache DNS
- registrar o DNS novamente

Deseja continuar?
"@

        if (-not (Confirm-BMFixAction -Message $confirmMessage -Title "BM InfoTech - Confirmar reset DNS")) {
            return
        }

        ipconfig /release | Out-Null
        ipconfig /renew | Out-Null
        arp -d * | Out-Null
        nbtstat -R | Out-Null
        nbtstat -RR | Out-Null
        ipconfig /flushdns | Out-Null
        ipconfig /registerdns | Out-Null

        Show-BMFixMessage `
            -Message "Reset de rede e DNS executado com sucesso." `
            -Title "BM InfoTech - Reset DNS" `
            -Icon ([System.Windows.MessageBoxImage]::Information)
    }
    catch {
        Show-BMFixMessage `
            -Message "Falha ao executar o reset de rede e DNS.`n`nDetalhes:`n$($_.Exception.Message)" `
            -Title "BM InfoTech - Erro" `
            -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}
