"""Three independent runner launches; stop on failure, retain every result.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess, sys
from pathlib import Path
p=Path(__file__).parent
for mode in ['matrix1','matrix2','matrix3']:
    result=subprocess.run([sys.executable,str(p/'run-validation.py'),mode])
    subprocess.run([sys.executable,str(p/'collect.py'),mode],check=True)
    if result.returncode: sys.exit(result.returncode)
subprocess.run([sys.executable,str(p/'verify-matrices.py'),'combined','matrix1','matrix2','matrix3'],check=True)
