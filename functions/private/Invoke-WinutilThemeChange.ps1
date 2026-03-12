function Invoke-WinutilThemeChange {
    param (
        [string]$theme = "Dark"
    )

    function Set-WinutilTheme {
        param (
            [string]$currentTheme
        )

        function Set-ThemeResourceProperty {
            param($Name, $Value, $Type)
            try {
                $sync.Form.Resources[$Name] = switch ($Type) {
                    "ColorBrush" { [Windows.Media.SolidColorBrush]::new($Value) }
                    "Color" {
                        $hexColor = $Value.TrimStart("#")
                        $r = [Convert]::ToInt32($hexColor.Substring(0,2), 16)
                        $g = [Convert]::ToInt32($hexColor.Substring(2,2), 16)
                        $b = [Convert]::ToInt32($hexColor.Substring(4,2), 16)
                        [Windows.Media.Color]::FromRgb($r, $g, $b)
                    }
                    "CornerRadius" { [System.Windows.CornerRadius]::new($Value) }
                    "GridLength" { [System.Windows.GridLength]::new($Value) }
                    "Thickness" {
                        $values = $Value -split ","
                        switch ($values.Count) {
                            1 { [System.Windows.Thickness]::new([double]$values[0]) }
                            2 { [System.Windows.Thickness]::new([double]$values[0], [double]$values[1]) }
                            4 { [System.Windows.Thickness]::new([double]$values[0], [double]$values[1], [double]$values[2], [double]$values[3]) }
                        }
                    }
                    "FontFamily" { [Windows.Media.FontFamily]::new($Value) }
                    "Double" { [double]$Value }
                    default { $Value }
                }
            }
            catch {
                Write-Warning "Failed to set property $($Name): $_"
            }
        }

        $themeProperties = $sync.configs.themes.$currentTheme.PSObject.Properties
        foreach ($_ in $themeProperties) {
            if ($_.Name -like "*color*") {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "ColorBrush"
                if ($_.Name -in @("BorderColor", "ButtonBackgroundMouseoverColor")) {
                    Set-ThemeResourceProperty -Name "C$($_.Name)" -Value $_.Value -Type "Color"
                }
            }
            elseif ($_.Name -like "*Radius*") {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "CornerRadius"
            }
            elseif ($_.Name -like "*RowHeight*") {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "GridLength"
            }
            elseif (($_.Name -like "*Thickness*") -or ($_.Name -like "*margin")) {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "Thickness"
            }
            elseif ($_.Name -like "*FontFamily*") {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "FontFamily"
            }
            else {
                Set-ThemeResourceProperty -Name $_.Name -Value $_.Value -Type "Double"
            }
        }
    }

    $sync.preferences.theme = "Dark"
    Set-Preferences -save

    Set-WinutilTheme -currentTheme "shared"
    Set-WinutilTheme -currentTheme "Dark"

    $fossEnabled = $true
    if ($sync.WPFToggleFOSSHighlight) {
        $fossEnabled = $sync.WPFToggleFOSSHighlight.IsChecked
    }

    if ($fossEnabled) {
        $sync.Form.Resources["FOSSColor"] = [Windows.Media.SolidColorBrush]::new(
            [Windows.Media.Color]::FromRgb(76, 175, 80)
        )
    }
    else {
        $sync.Form.Resources["FOSSColor"] = $sync.Form.Resources["MainForegroundColor"]
    }
}
