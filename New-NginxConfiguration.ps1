[CmdletBinding( DefaultParameterSetName = 'WorkingDirectory' )]
param (
    [Parameter( ParameterSetName = 'WorkingDirectory' )]
    [ValidateScript({
        -not [string]::IsNullOrEmpty( $_ ) -and ( Test-Path -Path $_ ) -and ( Test-Path -Path $_ -PathType Container )
    })]
    [string]
    $WorkingDirectory = $PSScriptRoot,
    
    [Parameter( ParameterSetName = 'WorkingDirectory' )]
    [ValidateNotNullOrEmpty()]
    [string]
    $NginxConfigurationFileName = 'nginx.template',
    
    [Parameter( ParameterSetName = 'WorkingDirectory' )]
    [ValidateNotNullOrEmpty()]
    [string]
    $NginxConfigurationDestinationFileName = 'nginx.conf',

    [Parameter( ParameterSetName = 'FilePath' )]
    [ValidateScript({
        -not [string]::IsNullOrEmpty( $_ ) -and ( Test-Path -Path $_ ) -and ( Test-Path -Path $_ -PathType Leaf )
    })]
    [string]
    $NginxConfigurationFile,

    [Parameter( ParameterSetName = 'FilePath' )]
    [ValidateScript({
        -not [string]::IsNullOrEmpty( $_ ) -and ( Test-Path -Path $_ ) -and ( Test-Path -Path $_ -PathType Leaf )
    })]
    [string]
    $NginxConfigurationDestinationFile,

    # Maximum recursion depth for includes. -1 disables the limit. Default is 99.
    [ValidateRange( -1, [int]::MaxValue )]
    [int]
    $Depth = 99
)
begin {
    #region VARIABLES
    $Keywords = @{
        'include' = 'file'
    }
    switch ( $PSCmdlet.ParameterSetName ) {
        'WorkingDirectory' {
            $ScriptNginxConfigurationFile = Join-Path -Path $WorkingDirectory -ChildPath $NginxConfigurationFileName
            $ScriptNginxConfigurationDestinationFile = Join-Path -Path $WorkingDirectory -ChildPath $NginxConfigurationDestinationFileName
            break
        }
        'FilePath' {
            $ScriptNginxConfigurationFile = $NginxConfigurationFile
            $ScriptNginxConfigurationDestinationFile = $NginxConfigurationDestinationFile
            break
        }
    }

    #region PREREQUISITES
    if ( -not ( Test-Path -Path $ScriptNginxConfigurationFile ) ) {
        throw [System.IO.FileNotFoundException]::new( "Nginx configuration file not found at path: $( $ScriptNginxConfigurationFile )" )
    }

    #region FUNCTIONS
    function Parse-Content {
        [OutputType( [string] )]
        param (
            [System.Object[]]
            $Content
        )
        begin {
            $CallStackDepth = ( Get-PSCallStack | Where-Object -Property Command -EQ -Value 'Parse-Content' | Measure-Object ).Count - 1  # Subtract 1 to not count initial call
            if ( $Depth -ge 0 -and $CallStackDepth -gt $Depth ) {
                throw [System.InvalidOperationException]::new( "Maximum include depth of $( $Depth ) exceeded." )
            }
        }
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
                        try {
                            $RecursiveContent = Parse-Content -Content ( Get-Content -LiteralPath $FilePath )
                            $RecursiveContent = "# Included from file: $( $Value )", $RecursiveContent -join [System.Environment]::NewLine
                        } catch [System.InvalidOperationException] {
                            Write-Warning "Maximum include depth of $( $Depth ) exceeded."
                            $RecursiveContent = "#$( $Line )"
                        }
                        $Content[ $Index ] = $RecursiveContent
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
}
process {
    #region SCRIPT
    $NginxConfiguration = Parse-Content -Content ( Get-Content -LiteralPath $ScriptNginxConfigurationFile )
    New-Item -ItemType File -Path $ScriptNginxConfigurationDestinationFile -Value $NginxConfiguration -Force | Out-Null
}