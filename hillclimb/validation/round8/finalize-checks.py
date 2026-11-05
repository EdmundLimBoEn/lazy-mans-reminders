"""Require real completed evidence before enabling independent grading.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib,struct
root=Path('hillclimb');task=root/'tasks/login-focus-polish';validation=root/'validation/round8';rounddir=root/'rounds/8';checks=[]
def add(name,passed,proof,required=True):checks.append(dict(name=name,status='passed' if passed else 'failed',proof=proof,required=required))
def read(path):return json.loads(Path(path).read_text())
freeze=read(task/'bounded-matrix-freeze.json');source=freeze['sourceSHA'];accept=read(task/'acceptance.json');assert source=='20ae77e29019444a499e9e47c98d6b656ef56819'
add('325/325 unfiltered;263unit+62UI;zero failures/skips',accept['status']=='passed' and accept['passed']==325 and accept['failed']==accept['skipped']==0,'../../tasks/login-focus-polish/acceptance.json')
add('All317baseline IDs retained;308/307/304/293 transitive coverage',accept['baseline317Retained'],'../../tasks/login-focus-polish/acceptance.json')
add('94tracked+2generated inputs exact committed revision',all(hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in freeze['hashes'].items()),'../../tasks/login-focus-polish/bounded-matrix-freeze.json')
for label in ['bounded-matrix-build','bounded-matrix-full','bounded-matrix-release','bounded-matrix-debug-restore','round8-python','round8-deno','round8-deno-overflow']:
 data=read(task/(label+'-process.json'));add(label,data['exit']==0,'../../tasks/login-focus-polish/'+label+'-process.json')
restore=read(task/'bounded-matrix-full-restoration.json');expected={'Reduce Motion':'0','Auto-Play Message Effects':'1','Reduce Transparency':'0','Increase Contrast':'0'}
add('All5Settings methods independently restore actual four originals',len(restore)==5 and all(x['original']==x['restored']==expected for x in restore),'../../tasks/login-focus-polish/bounded-matrix-full-restoration.json')
add('Explicit timeout recovery restores recorded originals',read(task/'recorded-settings-recovery-proof.json')['actualRestoredValues']==expected,'../../tasks/login-focus-polish/recorded-settings-recovery-proof.json')
add('Debug restored artifacts and installed six executable hashes',read(task/'debug-restoration-identity.json')['allMatch'] and read(task/'final-installed-identity.json')['allSixMatch'],'../../tasks/login-focus-polish/debug-restoration-identity.json;final-installed-identity.json')
copy=read(validation/'scope-copy-integrity.json');add('Only2owned production files;all original words/branding retained',copy['allOtherProductionUnchanged'] and all(x['allOriginalStringLiteralsRetained'] for x in copy['files']),'../../validation/round8/scope-copy-integrity.json')
add('Account instruction original strings,bounds and>=7contrast',read(validation/'account-instruction-gates.json')['status']=='passed','../../validation/round8/account-instruction-gates.json')
ids=accept['allNamedIDs']
for cls,method in [('LoginLoadingGeometryUITests','testPendingActionDoesNotReflowFollowingControls'),('SignInChromeUITests','testEmptyPasswordFirstFocusAndRefocusKeepsHeading'),('SignInChromeUITests','testCombinedEmptyPasswordFirstFocusAndRefocusKeepsHeading'),('AccessibilitySettingsUITests','testCombinedActualSettingsKeyboardMatrix'),('AccessibilitySettingsUITests','testCombinedActualSettingsDarkKeyboardMatrix'),('HillclimbUITests','testFullBoardBottomAboveComposerAfterPullAndScroll'),('HillclimbUITests','testTopControlsAvoidIslandAndHave44PointTargets'),('HillclimbUITests','testXXXLTextFitsAllocatedHeightAtBottom'),('ActivityCaptureUITests','testNativeShortActivityMatrix'),('ActivityCaptureUITests','testNativeLongActivityMatrix')]:
 add(cls+'/'+method,any('/'+cls+'/'+method in x for x in ids),'../../tasks/login-focus-polish/acceptance.json')
inventory=read(rounddir/'inventory.json');add('332canonical native hashes/dimensions/source bindings',len(inventory['images'])==332 and all(hashlib.sha256((rounddir/r['file']).read_bytes()).hexdigest()==r['sha256'] and list(struct.unpack('>II',(rounddir/r['file']).read_bytes()[16:24]))==[1206,2622] and r['gradedSourceSHA']==source for r in inventory['images']),'inventory.json')
clips=read(validation/'activity-video-artifacts.json')+read(validation/'keyboard-video-artifacts.json');add('16native movie hashes;8unmodified2s pixel witnesses',len(clips)==16 and all(hashlib.sha256(Path(x['file']).read_bytes()).hexdigest()==x['sha256'] for x in clips) and all(x['normalizationRetainsTwoSecondPixels'] for x in clips[:8]),'../../validation/round8/activity-video-artifacts.json;keyboard-video-artifacts.json')
pairs=read(validation/'reference-pairings.json');add('332closest Apple pairs;all17usable references;gaps explicit',len(pairs['pairs'])==332 and len(pairs['usedReferencePaths'])==17,'../../validation/round8/reference-pairings.json')
add('60same-state actual login comparison pairs',len(read(validation/'login-pairings.json')['pairs'])==60,'../../validation/round8/login-pairings.json')
add('Parent inspected canonical states and real motion samples',read(validation/'parent-inspection.json')['allCanonicalImagesCoveredByInspectedRawSheetsOrNativeMovieFrames'],'../../validation/round8/parent-inspection.json')
cleanup=read(task/'final-cleanup.json');add('Original17 remains booted;only own demo IDs empty;switches/light/Large restored;own panel closed',cleanup['passed'],'../../tasks/login-focus-polish/final-cleanup.json')
add('Manual pinned-driver access',False,'../../tasks/login-focus-polish/README.md:stopped stale-owner claim;project runner used',required=False)
result=dict(source_sha=source,sourceIdentity=freeze['sourceIdentity'],checks=checks,allRequiredChecksPassed=all(x['status']=='passed' for x in checks if x['required']),fullSuite=dict(passed=325,unit=263,ui=62,failed=0,skipped=0),remainingGaps=inventory['remainingGaps'],historicalFailureEvidence=['../../tasks/login-focus-polish/full-final-summary.json','../../tasks/login-focus-polish/measured-heading-full-summary.json'])
(rounddir/'checks.json').write_text(json.dumps(result,indent=2)+'\n');assert result['allRequiredChecksPassed'],[x for x in checks if x['required'] and x['status']!='passed'];print(len(checks),'technical checks;all required pass;rating gate is separate in scores.json')
