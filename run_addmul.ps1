# Run the addmul waveform simulation without including the default testbench.v
Set-Location "$PSScriptRoot"

$iverilog = "D:\FYP\iverilog\bin\iverilog.exe"
$vvp = "D:\FYP\iverilog\bin\vvp.exe"
$files = @(
    'adder.v',
    'alu.v',
    'aludec.v',
    'controller.v',
    'datapath.v',
    'dmem.v',
    'extend.v',
    'flopr.v',
    'imem.v',
    'maindec.v',
    'mux2.v',
    'mux3.v',
    'regfile.v',
    'riscvsingle.v',
    'top.v',
    'testbench_addmul.v'
)

Write-Host "Compiling addmul waveform simulation..."
& $iverilog -g2005-sv -o simv @files
if ($LASTEXITCODE -ne 0) {
    Write-Host "iverilog failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Running simulation..."
& $vvp simv
if ($LASTEXITCODE -ne 0) {
    Write-Host "vvp failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Done. Generated addmul.vcd" -ForegroundColor Green
