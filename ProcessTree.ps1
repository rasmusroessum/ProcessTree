[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") |Out-Null
[reflection.assembly]::LoadWithPartialName("System.Drawing") |Out-Null
$form = New-Object System.Windows.Forms.Form -Property @{
    Name = 'WinWat'
    Text = 'WinWat'
    Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$tree = New-Object System.Windows.Forms.TreeView -Property @{
    Anchor = 15
    Size = New-Object System.Drawing.Size -Property @{Height = 300; Width = 300}
}
$p = Get-CimInstance Win32_Process
$count = $p.Count
$p = $p |sort CreationDate |select Name, ProcessId, CreationDate, ParentProcessId, @{
    N = 'ParentIsOpen'
    E = { [bool](Get-Process -Id $_.ParentProcessId -Ea SilentlyContinue) }
}
[void]$tree.Nodes.Add(0, ($p |where ProcessId -eq 0).Name)
$p |where ProcessId -ne 0 |foreach {
    if($_.ParentProcessId -eq 0 -or $_.ParentIsOpen -eq 0){
        [void]$tree.Nodes[0].Nodes.Add($_.ProcessId, $_.Name)
    }else{
        $find = $tree.Nodes.Find($_.ParentProcessId, 1)
        if($find){
            [void]$find[0].Nodes.Add($_.ProcessId, $_.Name)
        }else{
            $forLater += $_
        }
    }
}
$forLater |foreach {
    $find = $tree.Nodes.Find($_.ParentProcessId, 1)
    [void]$find[0].Nodes.Add($_.ProcessId, $_.Name)
}
$form.Controls.Add($tree)
[void]$form.ShowDialog()