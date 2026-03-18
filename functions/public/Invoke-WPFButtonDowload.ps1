function Invoke-WPFDownloadInstallers {
    Invoke-WPFDownloadZip -Url "https://raw.githubusercontent.com/julianoaugustoleite/winutil/main/downloads/installers.zip" -FileName "installers.zip"
}

function Invoke-WPFDownloadSoftwares {
    Invoke-WPFDownloadZip -Url "https://raw.githubusercontent.com/julianoaugustoleite/winutil/main/downloads/softwares.zip" -FileName "softwares.zip"
}
