function Invoke-WPFDownloadZip {
    param(
        [string]$Url,
        [string]$FileName
    )

    try {
        $destino = Join-Path $env:USERPROFILE "Downloads\$FileName"

        Invoke-WebRequest -Uri $Url -OutFile $destino -UseBasicParsing

        [System.Windows.MessageBox]::Show(
            "Download concluido:`n$destino",
            "BM InfoTech",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Falha ao baixar o arquivo:`n$($_.Exception.Message)",
            "BM InfoTech",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}
