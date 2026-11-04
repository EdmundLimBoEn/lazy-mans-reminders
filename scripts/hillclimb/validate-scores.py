#!/usr/bin/env python3
"""Validate an evidence packet and compute the requested hillclimb stop gate."""
import argparse
import json
from pathlib import Path
from statistics import mean

MODELS = ('gpt-6.1-sol', 'gpt-6-astra', 'claude-opus-5.5')

def validate(root):
    result = {'graders': {}, 'gate_passed': False, 'errors': []}
    for model in MODELS:
        path = root / f'scores-{model}.json'
        if not path.exists():
            result['errors'].append(f'Missing {path.name}')
            continue
        data = json.loads(path.read_text())
        categories = data.get('categories', [])
        errors = []
        if data.get('model') != model:
            errors.append('Model identity mismatch')
        if len(categories) < 25 or len({c['name'] for c in categories}) != len(categories):
            errors.append('Require at least 25 unique categories')
        values = [c.get('score') for c in categories]
        if not values or any(type(v) not in (int, float) or not 1 <= v <= 10 for v in values):
            errors.append('Scores must be numeric, between 1 and 10')
            overall = None
        else:
            overall = round(mean(values), 2)
            if data.get('overall') != overall:
                errors.append(f'Overall must equal arithmetic mean {overall}')
        if not data.get('source_sha'):
            errors.append('Missing source SHA')
        for key in ('screenshots', 'references'):
            paths = data.get(key, [])
            if not paths:
                errors.append(f'Missing {key}')
            for name in paths:
                if not (root / name).is_file():
                    errors.append(f'Missing evidence file: {name}')
        result['graders'][model] = {'overall': overall, 'minimum': min(values) if overall else None, 'errors': errors, 'evidence_gaps': data.get('evidence_gaps', [])}
        result['errors'].extend(f'{model}: {error}' for error in errors)
    checks_path = root / 'checks.json'
    if not checks_path.exists():
        result['errors'].append('Missing checks.json')
    else:
        checks = json.loads(checks_path.read_text())
        required_checks = [c for c in checks.get('checks', []) if c.get('required', True)]
        if not required_checks or any(c.get('status') != 'passed' for c in required_checks):
            result['errors'].append('Required programmatic checks have not all passed')
        if not checks.get('source_sha'):
            result['errors'].append('Checks missing source SHA')
        for model, grade in result['graders'].items():
            source = json.loads((root / f'scores-{model}.json').read_text()).get('source_sha')
            if source != checks.get('source_sha'):
                result['errors'].append(f'{model}: checks and grading source SHA differ')
    result['gate_passed'] = not result['errors'] and len(result['graders']) == 3 and all(
        g['overall'] >= 9 and g['minimum'] >= 7 for g in result['graders'].values())
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('round', type=Path)
    args = parser.parse_args()
    result = validate(args.round)
    (args.round / 'scores.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['gate_passed'] else 1)
