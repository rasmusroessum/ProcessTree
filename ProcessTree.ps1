[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") |Out-Null
[reflection.assembly]::LoadWithPartialName("System.Drawing") |Out-Null
$form = New-Object System.Windows.Forms.Form -Property @{
    Name = 'WinWat'
    Text = 'WinWat'
    Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$timer = New-Object System.Windows.Forms.Timer -Property @{Interval = 1000; Enabled = 1}
$tree = New-Object System.Windows.Forms.TreeView -Property @{
    Anchor = 15
    Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$getProcess = { Get-CimInstance Win32_Process }
$p = . $getProcess
$count = $p.Count
$p = $p |sort CreationDate |select Name, ProcessId, Path, CreationDate, ParentProcessId, @{
    N = 'ParentIsOpen'
    E = { [bool](Get-Process -Id $_.ParentProcessId -Ea SilentlyContinue) }
}
[void]$tree.Nodes.Add(0, (($p |where ProcessId -eq 0).Name + ': ' + ($p |where ProcessId -eq 0).Path))
$p |where ProcessId -ne 0 |foreach {
    if($_.ParentProcessId -eq 0 -or $_.ParentIsOpen -eq 0){
        [void]$tree.Nodes[0].Nodes.Add($_.ProcessId, ($_.Name + ': ' + $_.Path))
    }else{
        $find = $tree.Nodes.Find($_.ParentProcessId, 1)
        if($find){
            [void]$find[0].Nodes.Add($_.ProcessId, ($_.Name + ': ' + $_.Path))
        }else{
            [array]$forLater += $_
        }
    }
}
$forLater |foreach {
    $find = $tree.Nodes.Find($_.ParentProcessId, 1)
    [void]$find[0].Nodes.Add($_.ProcessId, ($_.Name + ': ' + $_.Path))
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
            }
        }
    }
})
$form.Add_Closing({
    $timer.Enabled = 0
    Disable-ProcessCreationEvent
})
[void]$form.ShowDialog()
