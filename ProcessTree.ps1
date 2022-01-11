[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") |Out-Null
[reflection.assembly]::LoadWithPartialName("System.Drawing") |Out-Null
$form = New-Object System.Windows.Forms.Form -Property @{
    Name = 'WinWat'
    Text = 'WinWat'
    Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$timer = New-Object System.Windows.Forms.Timer -Property @{Interval = 1000; Enabled = 1}
$ctxMenu = New-Object System.Windows.Forms.ContextMenu
$ctxMenuStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start' }
$ctxMenuRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart' }
$ctxMenuClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Close' }
$ctxMenuClosed = New-Object System.Windows.Forms.ContextMenu
$ctxMenuClosedStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start' }
$ctxMenuClosedRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart'; Enabled = 0 }
$ctxMenuClosedClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Close'; Enabled = 0 }
$ctxMenuNoPath = New-Object System.Windows.Forms.ContextMenu
$ctxMenuNoPathStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start'; Enabled = 0 }
$ctxMenuNoPathRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart'; Enabled = 0 }
$ctxMenuNoPathClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Close'; Enabled = 0 }
$closeProcess = {
    $Form.Text = 'Closing ' + $global:selectedNode.Text
    $stopProcess = Stop-Process $global:selectedNode.Name -ErrorAction SilentlyContinue -Force -PassThru
    if($stopProcess.HasExited){
        $Form.Text = $global:selectedNode.Name + ' closed'
        $global:selectedNode.ContextMenu = $ctxMenuClosedProcess
        $global:selectedNode.ForeColor = [System.Drawing.Color]::Red
        $global:selectedNode.ContextMenu = $ctxMenuClosed
    }else{
        $Form.Text = $global:selectedNode.Text + ' could not be closed'
    }
}
$startProcess = {
    $Path = $global:selectedNode.Text.Split(':')
    $StartProcess = Start-Process -FilePath ($Path[1..2] -join ':') -ErrorAction SilentlyContinue -PassThru
    if($StartProcess){
        $Form.Text = $global:selectedNode.Text + ' was started'
    }else{
        $Form.Text = $global:selectedNode.Text + ' could not be started after close'
    }
}
$ctxMenuStart.add_Click({
    $Path = $global:selectedNode.Text.Split(':')
    if($Path[1]){
        . $startProcess
    }
})
$ctxMenuRestart.add_Click({
    $Path = $global:selectedNode.Text.Split(':')
    if($Path[1]){
        . $closeProcess
        . $startProcess
    }
})
$ctxMenuClose.add_Click(
    $closeProcess
)
$ctxMenu.MenuItems.AddRange(@($ctxMenuStart))
$ctxMenu.MenuItems.AddRange(@($ctxMenuRestart))
$ctxMenu.MenuItems.AddRange(@($ctxMenuClose))
$ctxMenuClosedStart.add_Click({
    $Path = $global:selectedNode.Text.Split(':')
    if($Path[1]){
        . $startProcess
    }
})
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathStart))
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathRestart))
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathClose))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedStart))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedRestart))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedClose)) 
$tree = New-Object System.Windows.Forms.TreeView -Property @{
    Anchor = 15; Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$tree.ContextMenu = $ctxMenu
$tree.Add_AfterSelect({
    $global:selectedNode = $_.Node
})
$tree.add_NodeMouseDoubleClick({
    Write-Host ('Double Click: ' +  $_.Node.Name)
    $this.SelectedNode = $_.Node #Select the node (Helpful when using a ContextMenuStrip)
})
$tree.add_NodeMouseClick({
    Write-Host ($_.Button.ToString() + ': ' + $_.Node.Name)
    $this.SelectedNode = $_.Node #Select the node (Helpful when using a ContextMenuStrip)
})
$getProcess = { Get-CimInstance Win32_Process }
$p = . $getProcess
$count = $p.Count
$p = $p |sort CreationDate |select *, @{
    N = 'ParentIsOpen'
    E = { [bool](Get-Process -Id $_.ParentProcessId -Ea SilentlyContinue) }
}
$root = $p |where ProcessId -eq 0
$root = New-Object System.Windows.Forms.TreeNode -Property @{Name = $root.ProcessId;Text = $root.Name; ContextMenu = $ctxMenuNoPath}
[void]$tree.Nodes.Add($root)
$p |where ProcessId -ne 0 |foreach {
    $Path = if($_.Path){': ' + $_.Path}
    $ContextMenu = if($Path){
        $ctxMenu
    }else{
        $ctxMenuNoPath
    }
    if($_.ParentProcessId -eq 0 -or $_.ParentIsOpen -eq 0){
        $newNode = New-Object System.Windows.Forms.TreeNode -Property @{Name = $_.ProcessId;Text = ($_.Name + $Path); ContextMenu = $ContextMenu}
        [void]$tree.Nodes[0].Nodes.Add($newNode) 
    }else{
        $find = $tree.Nodes.Find($_.ParentProcessId, 1)
        if($find){
            $newNode = New-Object System.Windows.Forms.TreeNode -Property @{Name = $_.ProcessId;Text = ($_.Name + $Path); ContextMenu = $ContextMenu}
            [void]$find[0].Nodes.Add($newNode)
        }else{
            [array]$forLater += $_
        }
    }
}
$forLater |foreach {
    $find = $tree.Nodes.Find($_.ParentProcessId, 1)
    [void]$find[0].Nodes.Add($_.ProcessId, ($_.Name + $(if($_.Path){': ' + $_.Path })))
}
$form.Controls.Add($tree)
function Enable-ProcessCreationEvent
{
    $identifier = "WMI.ProcessCreated"
    $query = "SELECT * FROM __instancecreationevent " +
                 "WITHIN 5 " +
                 "WHERE targetinstance isa 'win32_process'"
    Register-CimIndicationEvent -Query $query -SourceIdentifier $identifier `
        -SupportEvent -Action {
            [void] (New-Event "PowerShell.ProcessCreated" `
                -Sender $sender `
                -EventArguments $EventArgs.NewEvent.TargetInstance)
        }
}
function Disable-ProcessCreationEvent
{
   Unregister-Event -Force -SourceIdentifier "WMI.ProcessCreated"
}
Enable-ProcessCreationEvent
function Show-Nodes($tree){
    function Show-NodeCheckChild($tree){
        if($tree.Nodes.Name){
            $tree.Nodes.Name
        }
        If($tree.Nodes.Count -ge 1){
            Show-Nodes $tree.Nodes
        }
    }
    $array = [array]@()
    Show-NodeCheckChild -tree $tree |foreach {
        $array += [int]$_
    }
    $array
}
$timer.add_Tick({
    Get-Event |foreach {
        # Program opened
        $find = $tree.Nodes.Find($_.SourceArgs.ParentProcessId, 1)
        $newNode = New-Object System.Windows.Forms.TreeNode -Property @{Text = ($_.SourceArgs.ProcessName + ': ' + $_.SourceArgs.Path); Name = $_.SourceArgs.ProcessId}
        $newNode.ForeColor = [System.Drawing.Color]::Green
        $find[0].Nodes.Add($newNode)
        $_ | Remove-Event
    }
    $diff = diff (. $getProcess).ProcessId (Show-Nodes -tree $tree)
    if($diff){
        $diff |foreach {
            if($_.SideIndicator -eq '=>'){
                # Program closed
                $find = $tree.Nodes.Find($_.InputObject, 1)
                $find[0].ForeColor = [System.Drawing.Color]::Red
                $find[0].ContextMenu = $ctxMenuClosed
            }
        }
    }
})
$form.Add_Closing({
    $timer.Enabled = 0
    Disable-ProcessCreationEvent
})
[void]$form.ShowDialog()
