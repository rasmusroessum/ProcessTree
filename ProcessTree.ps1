﻿[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") |Out-Null
[reflection.assembly]::LoadWithPartialName("System.Drawing") |Out-Null
$form = New-Object System.Windows.Forms.Form -Property @{
    Name = 'WinWat'
    Text = 'WinWat'
    Size = New-Object System.Drawing.Size -Property @{Height = 600; Width = 500}
}
$timer = New-Object System.Windows.Forms.Timer -Property @{Interval = 500; Enabled = 1}
$ctxMenu = New-Object System.Windows.Forms.ContextMenu
$ctxMenuExpand = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Expand All' }
$ctxMenuStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start' }
$ctxMenuRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart' }
$ctxMenuClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Stop' }
$ctxMenuClosed = New-Object System.Windows.Forms.ContextMenu
$ctxMenuCloseExpand = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Expand All' }
$ctxMenuClosedStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start' }
$ctxMenuClosedRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart'; Enabled = 0 }
$ctxMenuClosedClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Stop'; Enabled = 0 }
$ctxMenuNoPath = New-Object System.Windows.Forms.ContextMenu
$ctxMenuNoPathExpand = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Expand All' }
$ctxMenuNoPathStart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Start'; Enabled = 0 }
$ctxMenuNoPathRestart = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Restart'; Enabled = 0 }
$ctxMenuNoPathClose = New-Object System.Windows.Forms.MenuItem -Property @{ Text = 'Stop'; Enabled = 0 }
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

$ctxMenuExpand.add_Click({
    $global:selectedNode.ExpandAll()
})
$ctxMenuCloseExpand.add_Click({
    $global:selectedNode.ExpandAll()
})
$ctxMenuNoPathExpand.add_Click({
    $global:selectedNode.ExpandAll()
})

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
$ctxMenu.MenuItems.AddRange(@($ctxMenuExpand))
$ctxMenu.MenuItems.AddRange(@($ctxMenuStart))
$ctxMenu.MenuItems.AddRange(@($ctxMenuRestart))
$ctxMenu.MenuItems.AddRange(@($ctxMenuClose))
$ctxMenuClosedStart.add_Click({
    $Path = $global:selectedNode.Text.Split(':')
    if($Path[1]){
        . $startProcess
    }
})
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuCloseExpand))
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathStart))
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathRestart))
$ctxMenuNoPath.MenuItems.AddRange(@($ctxMenuNoPathClose))

$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuNoPathExpand))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedStart))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedRestart))
$ctxMenuClosed.MenuItems.AddRange(@($ctxMenuClosedClose)) 
$tree = New-Object System.Windows.Forms.TreeView -Property @{
    Anchor = 15; Size = New-Object System.Drawing.Size -Property @{Height = 561; Width = 485}
}
$tree.ContextMenu = $ctxMenu
$tree.Add_AfterSelect({
    $global:selectedNode = $_.Node
})
$tree.add_NodeMouseClick({
    $this.SelectedNode = $_.Node #Select the node (Helpful when using a ContextMenuStrip)
})
$tree.add_NodeMouseDoubleClick({
    $this.SelectedNode = $_.Node #Select the node (Helpful when using a ContextMenuStrip)
    ($p |where ProcessId -eq $this.SelectedNode.Name)|select * |Out-GridView
})
$getProcess = { Get-CimInstance Win32_Process }
$global:p = . $getProcess
$count = $p.Count
$global:p = $global:p |sort CreationDate |select *, @{
    N = 'ParentIsOpen'
    E = { [bool](Get-Process -Id $_.ParentProcessId -Ea SilentlyContinue) }
}
$root = $global:p |where ProcessId -eq 0
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

function Enable-ProcessDeletionEvent
{
    $identifier = "WMI.ProcessStopped"
    $query = "SELECT * FROM __instancedeletionevent " +
                 "WITHIN 5 " +
                 "WHERE targetinstance isa 'win32_process'"
    Register-CimIndicationEvent -Query $query -SourceIdentifier $identifier `
        -SupportEvent -Action {
            [void] (New-Event "PowerShell.ProcessStopped" `
                -Sender $sender `
                -EventArguments $EventArgs.NewEvent.TargetInstance)
        }
}
function Disable-ProcessDeletionEvent
{
   Unregister-Event -Force -SourceIdentifier "WMI.ProcessStopped"
}
Enable-ProcessDeletionEvent

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
        if($_.SourceIdentifier -eq 'PowerShell.ProcessCreated'){
            # Program opened
            $global:p += Get-CimInstance Win32_Process -Filter "ProcessID=$($_.SourceArgs.ProcessId)"
            $find = $tree.Nodes.Find($_.SourceArgs.ParentProcessId, 1)
            $newNode = New-Object System.Windows.Forms.TreeNode -Property @{Text = ($_.SourceArgs.ProcessName + ': ' + $_.SourceArgs.Path); Name = $_.SourceArgs.ProcessId}
            $newNode.ForeColor = [System.Drawing.Color]::Green
            $find[0].Nodes.Add($newNode)
        }else{
            # Program closed
            $find = $tree.Nodes.Find($_.SourceArgs.ProcessId, 1)
            $find[0].ForeColor = [System.Drawing.Color]::Red
            $find[0].ContextMenu = $ctxMenuClosed
        }
        $_ | Remove-Event
    }
})
$form.Add_Closing({
    $timer.Enabled = 0
    Disable-ProcessCreationEvent    Disable-ProcessDeletionEvent
})
[void]$form.ShowDialog()