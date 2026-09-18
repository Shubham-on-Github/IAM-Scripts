# Import necessary Graph modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.Governance

# 1. Authenticate
try {
    Write-Host "Authenticating..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "User.Read.All", "RoleManagement.ReadWrite.Directory" -ErrorAction Stop
} catch {
    Write-Host "[-] Authentication Failed. Ensure you have the Graph modules installed and internet connectivity." -ForegroundColor Red
    Write-Host "    Error Details: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# 2. Get the current signed-in user's context
try {
    Write-Host "`nFetching your account details..." -ForegroundColor Cyan
    $context = Get-MgContext -ErrorAction Stop
    
    # FORCED BOUNDARIES TO PREVENT COPY-PASTE SPACE STRIPPING
    $currentUser = Get-MgUser -UserId "$($context.Account)" -ErrorAction Stop
} catch {
    Write-Host "[-] Failed to retrieve user context." -ForegroundColor Red
    Write-Host "    Error Details: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# 3. Fetch eligible PIM roles for the user
try {
    Write-Host "Fetching your eligible PIM roles..." -ForegroundColor Cyan
    $eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "PrincipalId eq '$($currentUser.Id)'" -ExpandProperty "RoleDefinition" -ErrorAction Stop
} catch {
    Write-Host "[-] Failed to fetch eligible PIM roles. Ensure you have the 'RoleManagement.ReadWrite.Directory' permission." -ForegroundColor Red
    Write-Host "    Error Details: $($_.Exception.Message)" -ForegroundColor Red
    return
}

if ($eligibleRoles.Count -eq 0) {
    Write-Host "[-] No eligible PIM roles found for your account." -ForegroundColor Yellow
    return
}

# 4. Display a selection menu
Write-Host "`nAvailable Roles for Activation:" -ForegroundColor Green
for ($i = 0; $i -lt $eligibleRoles.Count; $i++) {
    Write-Host "[$i] $($eligibleRoles[$i].RoleDefinition.DisplayName)"
}

# 5. Handle Multiple Selections 
$roleChoiceInput = Read-Host "`nEnter the numbers of the roles you want to enable (comma-separated, e.g., 0,3,5)"
$rawChoices =$roleChoiceInput -split ','

$selectedRoles = @()
for ($j = 0; $j -lt$rawChoices.Count; $j++) {$choice = $rawChoices[$j].Trim()
    if ([int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 0 -and [int]$choice -lt $eligibleRoles.Count) {$selectedRoles += $eligibleRoles[[int]$choice]
    } elseif (-not [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "[-] Skipping invalid selection: '$choice'" -ForegroundColor Yellow
    }
}

if ($selectedRoles.Count -eq 0) {
    Write-Host "[-] No valid roles selected. Please run the script again." -ForegroundColor Red
    return
}

# 6. Get Duration
$durationInput = Read-Host "`nEnter duration in hours (e.g., 4 or 8) [Default: 8]"
if ([string]::IsNullOrWhiteSpace($durationInput)) {
    $durationHours = 8
} else {
    $durationHours = [int]$durationInput
}
$durationString = "PT$($durationHours)H"

# 7. Get Justification (Applied to all selected roles)
$justification = Read-Host "Enter justification for activating these $($selectedRoles.Count) roles"

if ([string]::IsNullOrWhiteSpace($justification)) {
    Write-Host "[-] A justification is strictly required for PIM activation." -ForegroundColor Red
    return
}

Write-Host "`nStarting batch activation process..." -ForegroundColor Cyan

# 8. Loop through selected roles and activate 
for ($k = 0; $k -lt$selectedRoles.Count; $k++) {$role = $selectedRoles[$k]
    
    Write-Host "`nProcessing: $($role.RoleDefinition.DisplayName)..." -ForegroundColor Cyan
    
    $requestParams = @{
        Action = "SelfActivate"
        PrincipalId = $currentUser.Id
        RoleDefinitionId = $role.RoleDefinitionId
        DirectoryScopeId = "/"
        Justification = $justification
        ScheduleInfo = @{
            StartDateTime = (Get-Date).ToUniversalTime().ToString("O")
            Expiration = @{
                Type = "AfterDuration"
                Duration = $durationString
            }
        }
    }

    try {
        $response = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $requestParams -ErrorAction Stop
        Write-Host "[+] Success! Activated $($role.RoleDefinition.DisplayName) for $durationHours hours." -ForegroundColor Green
    } catch {
        $errorDetail = $_.ErrorDetails.Message
        
        if ([string]::IsNullOrWhiteSpace($errorDetail)) {
            $errorDetail = $_.Exception.Message
        }

        if ($errorDetail -match "conflict" -or $errorDetail -match "overlap" -or $errorDetail -match "already exists") {
            Write-Host "[-] Skipped: $($role.RoleDefinition.DisplayName) is already active or has an overlapping pending request." -ForegroundColor Yellow
        } else {
            Write-Host "[-] Failed to activate $($role.RoleDefinition.DisplayName)" -ForegroundColor Red
            Write-Host "    API Error: $errorDetail" -ForegroundColor Red
            Write-Host "    Action Required: Review your tenant's specific PIM policy for this role (e.g., maximum allowed duration, mandatory ticket numbers, or approval requirements)." -ForegroundColor DarkGray
        }
    }
}

Write-Host "`nAll requested activations have been processed. Allow 1-2 minutes for token claims to refresh." -ForegroundColor Yellow