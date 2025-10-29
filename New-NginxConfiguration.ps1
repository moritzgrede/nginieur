[CmdletBinding( DefaultParameterSetName = 'WorkingDirectory' )]
param (
    [Parameter( ParameterSetName = 'WorkingDirectory' )]
    [ValidateScript({
        -not [string]::IsNullOrEmpty( $_ ) -and ( Test-Path -Path $_ ) -and ( Test-Path -Path $_ -PathType Container )
    })]
    [string]
    $WorkingDirectory = $PWD.Path,
    
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
    $Depth = 99,

    # Hide metadata information from top of file
    [switch]
    $NoMetadata
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
        [OutputType( [string[]] )]
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
            $NewContent = @()
            foreach ( $Line in $Content.Clone() ) {
                $Index++
                if ( $Line -match '^\s*#' -or [string]::IsNullOrWhiteSpace( $Line ) ) {
                    # Line is empty or a comment, preserve as-is with correct indentation
                    $NewContent += $Line
                    continue
                }
                $Match = [regex]::Match( $Line, '^(?<Indentation>\s*)(?<Keyword>\w+)\s+(?<Value>.+?);$' )
                if ( -not $Match.Success ) {
                    # Line does not match expected pattern, preserve as-is with correct indentation
                    $NewContent += $Line
                    continue
                }
                $Keyword = $Match.Groups['Keyword'].Value
                if ( $Keyword -notin $Keywords.Keys ) {
                    # Line does not contain a recognized keyword, preserve as-is with correct indentation
                    $NewContent += $Line
                    continue
                }
                $Indentation = $Match.Groups['Indentation'].Value
                $Value = $Match.Groups['Value'].Value
                switch ( $Keywords[ $Keyword] ) {
                    'file' {
                        # Handle file include
                        $FilePath = Join-Path -Path $WorkingDirectory -ChildPath $Value
                        try {
                            if ( -not ( Test-Path -Path $FilePath ) ) {
                                throw [System.IO.FileNotFoundException]::new( "Included file not found at path: $( $FilePath )" )
                            }
                            # File found, parse its content recursively
                            $NewContent += "$( $Indentation )# $( '>' * ( $CallStackDepth + 1 ) ) Included from file: $( $Value )"
                            Parse-Content -Content ( Get-Content -LiteralPath $FilePath ) | ForEach-Object { $NewContent += "$( $Indentation )$( $_ )" }
                            $NewContent += "$( $Indentation )# $( '<' * ( $CallStackDepth + 1 ) ) $( $Value )"
                        } catch [System.IO.FileNotFoundException] {
                            # File not found, comment out the include line
                            Write-Error $_.Exception.Message
                            $NewContent += "$( $Indentation )#$( $Line )  # File not found!"
                        } catch [System.InvalidOperationException] {
                            # Maximum depth exceeded, comment out the include line
                            Write-Warning "Maximum include depth of $( $Depth ) exceeded."
                            $NewContent += "$( $Indentation )#$( $Line )  # Maximum depth exceeded!"
                        }
                        break
                    }
                    default {
                        Write-Warning "Unhandled keyword type: $( $Keywords[ $Keyword ] )"
                        $NewContent += $Line
                        break
                    }
                }
            }
            $NewContent
        }
    }
}
process {
    #region SCRIPT
    $NginxConfiguration = ''
    if ( -not $NoMetadata ) {
        $NginxConfiguration = @"
# Generated on: $( Get-Date -UFormat '%FT%T%Z' )
# Generated by: $( [System.Environment]::UserName )

"@
    }
    $NginxConfiguration += ( ( Parse-Content -Content ( Get-Content -LiteralPath $ScriptNginxConfigurationFile ) ) -join [System.Environment]::NewLine )
    New-Item -ItemType File -Path $ScriptNginxConfigurationDestinationFile -Value $NginxConfiguration -Force | Out-Null
}