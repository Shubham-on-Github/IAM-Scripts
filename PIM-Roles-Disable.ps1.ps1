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

# 3. Fetch currently ACTIVE PIM roles for the user
try {
    Write-Host "Fetching your active PIM roles..." -ForegroundColor Cyan
    $allAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "PrincipalId eq '$($currentUser.Id)'" -ExpandProperty "RoleDefinition" -ErrorAction Stop
    
    # Filter locally to only show roles that were temporarily "Activated" (ignoring permanent assignments)
    $activeRoles = @()
    for ($a = 0; $a -lt $allAssignments.Count; $a++) {
        if ($allAssignments[$a].AssignmentType -eq "Activated") {
            $activeRoles += $allAssignments[$a]
        }
    }

} catch {
    Write-Host "[-] Failed to fetch active PIM roles." -ForegroundColor Red
    Write-Host "    Error Details: $($_.Exception.Message)" -ForegroundColor Red
    return
}

if ($activeRoles.Count -eq 0) {
    Write-Host "[!] No active PIM roles found that can be deactivated." -ForegroundColor Yellow
    return
}

# 4. Display a selection menu
Write-Host "`nCurrently Active Roles available for Deactivation:" -ForegroundColor Green
for ($i = 0; $i -lt $activeRoles.Count; $i++) {
    Write-Host "[$i] $($activeRoles[$i].RoleDefinition.DisplayName)"
}

# 5. Handle Multiple Selections 
$roleChoiceInput = Read-Host "`nEnter the numbers of the roles you want to disable (comma-separated, e.g., 0,1)"
$rawChoices =$roleChoiceInput -split ','

$selectedRoles = @()
for ($j = 0; $j -lt$rawChoices.Count; $j++) {$choice = $rawChoices[$j].Trim()
    if ([int]::TryParse($choice, [ref]$null) -and [int]$choice -ge 0 -and [int]$choice -lt $activeRoles.Count) {$selectedRoles += $activeRoles[[int]$choice]
    } elseif (-not [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "[-] Skipping invalid selection: '$choice'" -ForegroundColor Yellow
    }
}

if ($selectedRoles.Count -eq 0) {
    Write-Host "[-] No valid roles selected. Please run the script again." -ForegroundColor Red
    return
}

# 6. Get Justification (Applied to all selected roles)
$justification = Read-Host "`nEnter justification for deactivating these roles [Default: 'Task completed']"
if ([string]::IsNullOrWhiteSpace($justification)) {
    $justification = "Task completed"
}

Write-Host "`nStarting batch deactivation process..." -ForegroundColor Cyan

# 7. Loop through selected roles and deactivate 
for ($k = 0; $k -lt$selectedRoles.Count; $k++) {$role = $selectedRoles[$k]
    
    Write-Host "`nProcessing Deactivation: $($role.RoleDefinition.DisplayName)..." -ForegroundColor Cyan
    
    # Payload for SelfDeactivate
    $requestParams = @{
        Action = "SelfDeactivate"
        PrincipalId = $currentUser.Id
        RoleDefinitionId = $role.RoleDefinitionId
        DirectoryScopeId = $role.DirectoryScopeId
        Justification = $justification
    }

    try {
        $response = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $requestParams -ErrorAction Stop
        Write-Host "[+] Success! Deactivated $($role.RoleDefinition.DisplayName)." -ForegroundColor Green
    } catch {
        $errorDetail = $_.ErrorDetails.Message
        
        if ([string]::IsNullOrWhiteSpace($errorDetail)) {
            $errorDetail = $_.Exception.Message
        }

        if ($errorDetail -match "conflict" -or $errorDetail -match "overlap") {
            Write-Host "[-] Skipped: A deactivation request for $($role.RoleDefinition.DisplayName) is already pending or processed." -ForegroundColor Yellow
        } else {
            Write-Host "[-] Failed to deactivate $($role.RoleDefinition.DisplayName)" -ForegroundColor Red
            Write-Host "    API Error: $errorDetail" -ForegroundColor Red
        }
    }
}

Write-Host "`nAll requested deactivations have been processed. Allow 1-2 minutes for token claims to refresh." -ForegroundColor Yellow