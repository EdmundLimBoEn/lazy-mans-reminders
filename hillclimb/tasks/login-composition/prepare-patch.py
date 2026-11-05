"""Source patch from verified frozen S bytes, without repairing shared Git.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import hashlib,difflib,json
p=Path(__file__).parent
current=Path('ios/App/SignInView.swift').read_text()
s=current.replace('private var signInButtonHeight: CGFloat = 48','private var signInButtonHeight: CGFloat = 44').replace('.font(.title2.weight(.semibold))','.font(.subheadline.weight(.semibold))').replace('.navigationBarTitleDisplayMode(.inline)','.navigationBarTitleDisplayMode(.large)')
s=s.replace('''            if appearanceFixture && HillclimbDemo.argument("--hillclimb-signin-filled") == "yes" {
                email = "you@example.com"
                if usesPassword { password = "Demo-password" }
            }
''','')
s=s.replace('''            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, signInButtonHeight))
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary, lineWidth: 1))''','''            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, signInButtonHeight))''')
s=s.replace('''    private var submitIsDisabled: Bool {
        disablesDemoControls || !emailIsPlausible || busy || (usesPassword && password.isEmpty)
    }

''','')
s=s.replace('''                        .foregroundColor(colorScheme == .dark && !submitIsDisabled ? Color(.systemBackground) : nil)
''','')
s=s.replace('.disabled(submitIsDisabled)', '.disabled(\n                        disablesDemoControls || !emailIsPlausible || busy || (usesPassword && password.isEmpty))')
s=s.replace('prompt: Text(verbatim: \"you@example.com\").foregroundColor(Color(.secondaryLabel))', 'prompt: Text(\"you@example.com\").foregroundStyle(.secondary)')
s=s.replace('.foregroundStyle(.primary.opacity(0.75))','.foregroundStyle(.primary)').replace('TextField("you@example.com", text: $email, prompt: Text("you@example.com").foregroundStyle(.secondary))','TextField("you@example.com", text: $email)')
a=s.index('    private var emailField:');b=s.index('    private var passwordField:');s=s[:a]+s[a:b].replace('.frame(minHeight: 48)','.frame(minHeight: 44)')+s[b:]
assert hashlib.sha256(s.encode()).hexdigest()=='c67fe2c4d0936b608c79394e627c62c1bea1e296150c45f87753b5c3ca86a473'
import collections,re
literals=lambda text:collections.Counter(re.findall(r'"(?:[^"\\]|\\.)*"',text))
assert not (literals(s)-literals(current))
patch=''
def add(file,before,after):
 global patch
 patch+=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+file if before else '/dev/null',tofile='b/'+file))
add('ios/App/SignInView.swift',s,current)
raw=Path('hillclimb/tasks/signin-density/candidate.patch').read_text().split('diff --git a/ios/UITests/SignInDensityUITests.swift')[1]
old=''.join(line[1:]+'\n' for line in raw.splitlines() if line.startswith('+') and not line.startswith('+++'))
add('ios/UITests/SignInDensityUITests.swift',old,Path('ios/UITests/SignInDensityUITests.swift').read_text())
add('ios/UITests/LoginCompositionUITests.swift','',Path('ios/UITests/LoginCompositionUITests.swift').read_text())
(p/'composition.patch').write_text(patch)
(p/'copy-integrity.json').write_text(json.dumps(dict(frozenSSHA256=hashlib.sha256(s.encode()).hexdigest(),correctedSHA256=hashlib.sha256(current.encode()).hexdigest(),allOriginalStringLiteralsRetained=True,method='Exact reconstruction of S validates its recorded SHA256 before producing bounded U diff; patch exposes every modification.'),indent=2))
print('Verified frozen S source; wrote U-only patch')
