"""Replay the bounded INV154 ETW analysis without executing the game."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--traces', type=Path, required=True,
                        help='Artifact directory containing trial-*-enabled')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--symbols', type=Path,
                        help='Directory containing the exact matching Rapier PDB')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    project = root / 'tools/performance/rapier_thread_state/RapierThreadState.csproj'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    build = subprocess.run(['dotnet', 'build', str(project), '-c', 'Release'],
                           capture_output=True, text=True, timeout=120)
    (output / 'build.log').write_text(build.stdout + build.stderr, encoding='utf-8')
    build.check_returncode()
    assembly = project.parent / 'bin/Release/net10.0/RapierThreadState.dll'
    symbol_path = None
    if args.symbols:
        pdb = args.symbols.resolve() / 'godot_rapier.pdb'
        expected = '4d8a135baf94b65d0870400a4fbbb0da2d39c47b169a26298c74a29eac3a8d4f'
        if hashlib.sha256(pdb.read_bytes()).hexdigest() != expected:
            raise ValueError('Rapier PDB does not match the executed runtime')
        symbol_path = str(pdb.parent) + ';SRV*' + str(output / 'symbols-cache') + '*https://msdl.microsoft.com/download/symbols'
    receipts = []
    trials = sorted(args.traces.resolve().glob('trial-*-enabled'))
    if len(trials) != 3:
        raise ValueError('Expected the three retained enabled trials')
    for trial in trials:
        destination = output / trial.name
        destination.mkdir(exist_ok=True)
        command = ['dotnet', str(assembly), str(trial / 'trace.etl'),
                   str(trial / 'physics-thread-cpu.json'), str(destination), '--stacks']
        receipt = {'command': command, 'timeout_seconds': 180}
        environment = dict(os.environ)
        if symbol_path:
            environment['CYBERSAND_ETW_SYMBOL_PATH'] = symbol_path
        try:
            with (destination / 'console.log').open('w', encoding='utf-8') as log:
                result = subprocess.run(command, env=environment, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=180)
            receipt['exit_code'] = result.returncode
            result.check_returncode()
            for name in ('thread-state.json', 'stacks.json'):
                if not (destination / name).is_file():
                    raise ValueError('Incomplete ETW analysis: ' + name)
        except subprocess.TimeoutExpired:
            receipt['exit_code'] = 'timeout'
            raise
        finally:
            (destination / 'exit.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        receipts.append(receipt)
    (output / 'commands.json').write_text(json.dumps(receipts, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
