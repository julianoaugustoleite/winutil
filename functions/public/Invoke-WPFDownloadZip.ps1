function Invoke-WPFDownloadZip {
    param(
        [string]$Url,
        [string]$FileName
    )

    try {
        $baseTemp = "C:\Temp"

        if (!(Test-Path $baseTemp)) {
            New-Item -Path $baseTemp -ItemType Directory -Force | Out-Null
        }

        $destino = Join-Path $baseTemp $FileName
        $extensao = [System.IO.Path]::GetExtension($FileName).ToLower()
        $nomeBase = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

        Invoke-WebRequest -Uri $Url -OutFile $destino -UseBasicParsing

        if (!(Test-Path $destino)) {
            throw "O arquivo nao foi baixado corretamente."
        }

        if ($extensao -eq ".zip") {
            $pastaExtraida = Join-Path $baseTemp $nomeBase

            if (Test-Path $pastaExtraida) {
                Remove-Item $pastaExtraida -Recurse -Force -ErrorAction SilentlyContinue
            }

            Expand-Archive -Path $destino -DestinationPath $pastaExtraida -Force
            Remove-Item $destino -Force -ErrorAction SilentlyContinue

            # CASO ESPECIAL: DDU -> baixar, extrair e executar
            if ($FileName -ieq "DDU.zip") {
                $executavelDDU = Get-ChildItem -Path $pastaExtraida -Recurse -File |
                    Where-Object {
                        $_.Extension -eq ".exe" -and (
                            $_.Name -match "DDU" -or
                            $_.Name -match "Display.?Driver.?Uninstaller"
                        )
                    } |
                    Select-Object -First 1

                if (-not $executavelDDU) {
                    throw "O DDU foi extraido, mas nenhum executavel compativel foi encontrado."
                }

                Start-Process -FilePath $executavelDDU.FullName

                [System.Windows.MessageBox]::Show(
                    "Download concluido com sucesso.`n`nDDU extraido para:`n$pastaExtraida`n`nExecutavel iniciado:`n$($executavelDDU.FullName)",
                    "BM InfoTech",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null

                return
            }

            [System.Windows.MessageBox]::Show(
                "Download concluido com sucesso.`n`nArquivo ZIP extraido para:`n$pastaExtraida`n`nO arquivo ZIP original foi removido.",
                "BM InfoTech",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        elseif ($extensao -eq ".exe") {
            # CASO ESPECIAL: NvInstall.exe -> baixar e executar
            if ($FileName -ieq "NvInstall.exe") {
                Start-Process -FilePath $destino

                [System.Windows.MessageBox]::Show(
                    "Download concluido com sucesso.`n`nNvInstall iniciado a partir de:`n$destino",
                    "BM InfoTech",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null

                return
            }

            [System.Windows.MessageBox]::Show(
                "Download concluido com sucesso.`n`nArquivo salvo em:`n$destino",
                "BM InfoTech",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
        else {
            [System.Windows.MessageBox]::Show(
                "Download concluido com sucesso.`n`nArquivo salvo em:`n$destino",
                "BM InfoTech",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Falha ao baixar ou processar o arquivo.`n`nDetalhes:`n$($_.Exception.Message)",
            "BM InfoTech",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}
