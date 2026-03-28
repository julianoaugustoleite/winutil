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

            [System.Windows.MessageBox]::Show(
                "Download concluido com sucesso.`n`nArquivo ZIP extraido para:`n$pastaExtraida`n`nO arquivo ZIP original foi removido.",
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
