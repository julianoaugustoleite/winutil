Function Show-CTTLogo {
    <#
        .SYNOPSIS
            Displays the CTT logo in ASCII art.
        .DESCRIPTION
            This function displays the CTT logo in ASCII art format.
        .PARAMETER None
            No parameters are required for this function.
        .EXAMPLE
            Show-CTTLogo
            Prints the CTT logo in ASCII art format to the console.
    #>

    $asciiArt = @"

====BM Infotech=====

====https://www.bminfotech.com.br/====

====O nosso DNA e feito de Solucoes====

=====Windows Toolbox=====
"@

    Write-Host $asciiArt
}

