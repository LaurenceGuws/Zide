param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ScriptPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = 'Stop'

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & $python.Source $ScriptPath @ScriptArgs
    exit $LASTEXITCODE
}

$py = Get-Command py -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source -3 $ScriptPath @ScriptArgs
    exit $LASTEXITCODE
}

throw "Python 3 was not found on PATH. Install Python or ensure `python`/`py` is available."
