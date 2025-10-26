#region VARIABLES
$WorkingDirectory = $PSScriptRoot
$NginxConfigurationFile = Join-Path -Path $WorkingDirectory -ChildPath 'nginx.template'
$NginxConfigurationDestinationFile = Join-Path -Path $WorkingDirectory -ChildPath 'nginx.conf'
$Keywords = @{
    'include' = 'file'
}

#region PREREQUISITES
if ( -not ( Test-Path -Path $NginxConfigurationFile ) ) {
    throw [System.IO.FileNotFoundException]::new( "Nginx configuration file not found at path: $( $NginxConfigurationFile )" )
}

#region FUNCTIONS
function Parse-Content {
    [OutputType( [string] )]
    param (
        [System.Object[]]
        $Content
    )
    process {
        $Index = -1  # Initialize line index at -1, because we increment at the start of the loop
        foreach ( $Line in $Content.Clone() ) {
            $Index++
            $Line = $Line.Trim()
            if ( $Line -like '#*' -or [string]::IsNullOrWhiteSpace( $Line ) ) { continue }
            $Match = [regex]::Match( $Line, '^(?<Keyword>\w+)\s+(?<Value>.+?);$' )
            if ( -not $Match.Success ) { continue }
            $Keyword = $Match.Groups['Keyword'].Value
            if ( $Keyword -notin $Keywords.Keys ) { continue }
            $Value = $Match.Groups['Value'].Value
            switch ( $Keywords[ $Keyword] ) {
                'file' {
                    $FilePath = Join-Path -Path $WorkingDirectory -ChildPath $Value
                    if ( -not ( Test-Path -Path $FilePath ) ) {
                        throw [System.IO.FileNotFoundException]::new( "Included file not found at path: $( $FilePath )" )
                        continue
                    }
                    $Content[ $Index ] = @"
# Included from file: $( $Value )
$( Parse-Content -Content ( Get-Content -LiteralPath $FilePath ) )
"@
                    break
                }
                default {
                    Write-Warning "Unhandled keyword type: $( $Keywords[ $Keyword ] )"
                    break
                }
            }
        }
        $Content -join [System.Environment]::NewLine
    }
}

#region SCRIPT
$NginxConfiguration = Parse-Content -Content ( Get-Content -LiteralPath $NginxConfigurationFile )
New-Item -ItemType File -Path $NginxConfigurationDestinationFile -Value $NginxConfiguration -Force | Out-Null