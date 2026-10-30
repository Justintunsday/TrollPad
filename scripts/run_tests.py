#!/usr/bin/env python3
"""Run actual C geometry tests with clang/cc or a caller-supplied compiler command."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cc', nargs='+', help='compiler executable followed by optional driver arguments')
    args = parser.parse_args()
    compiler = args.cc or [shutil.which('clang') or shutil.which('cc') or 'clang']
    with tempfile.TemporaryDirectory(prefix='trollpad-tests-') as temp:
        for name in ('test_vertical_geometry', 'test_vertical_host_projection', 'test_vertical_transition_geometry'):
            binary = Path(temp) / (name + ('.exe' if os.name == 'nt' else ''))
            command = compiler + ['-std=c11', '-Wall', '-Wextra', '-Werror',
                                 str(ROOT / 'VerticalSplit/TPVerticalGeometry.c'),
                                 str(ROOT / 'tests' / (name + '.c')), '-o', str(binary)]
            if os.name != 'nt':
                command.append('-lm')
            subprocess.run(command, check=True, cwd=ROOT)
            subprocess.run([str(binary)], check=True, cwd=ROOT)

if __name__ == '__main__':
    main()
