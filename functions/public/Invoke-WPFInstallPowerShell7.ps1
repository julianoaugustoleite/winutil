function Invoke-WPFInstallPowerShell7 {

    try {

        # ===============================
        # Verifica se já está instalado
        # ===============================
        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            [System.Windows.MessageBox]::Show(
                "PowerShell 7 ja esta instalado neste computador.",
                "BM InfoTech",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
            return
        }

        # ===============================
        # Confirmação do usuário
        # ===============================
        $confirm = [System.Windows.MessageBox]::Show(
            "Deseja instalar o PowerShell 7 neste computador?",
            "BM InfoTech",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($confirm -ne "Yes") { return }

        # ===============================
        # Tenta instalar via WINGET
        # ===============================
        if (Get-Command winget -ErrorAction SilentlyContinue) {

            Start-Process -FilePath "winget" `
                -ArgumentList "install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements -e" `
                -Wait -NoNewWindow

            if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                [System.Windows.MessageBox]::Show(
                    "PowerShell 7 instalado com sucesso via Winget.",
                    "BM InfoTech",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null
                return
            }
        }

        # ===============================
        # FALLBACK — download MSI oficial
        # ===============================
        $url = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.1-win-x64.msi"
        $dest = "$env:TEMP\PowerShell7.msi"

        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing

        Start-Process "msiexec.exe" -ArgumentList "/i `"$dest`" /quiet /norestart" -Wait

        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            [System.Windows.MessageBox]::Show(
                "PowerShell 7 instalado com sucesso.",
                "BM InfoTech",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            throw "Falha na instalacao."
        }

    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Erro ao instalar PowerShell 7:`n$($_.Exception.Message)",
            "BM InfoTech",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}
