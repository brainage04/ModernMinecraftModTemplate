"""Compare every delivered packed texture to the actual official client jar."""
import bpy
import hashlib
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from render_down_left import wait_for_shared_cpu_cap
resources = wait_for_shared_cpu_cap()
jars = {
    'legacy': ROOT.parent / 'minecraft-1.8.9-client.jar',
    'modern': Path('/home/thomas/.gradle/caches/fabric-loom/26.2/minecraft-merged.jar'),
}
results = []
for era in ['legacy', 'modern']:
    name = era + '-hub-down-left-1'
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / (name + '.blend')))
    textures = []
    states = []
    with zipfile.ZipFile(jars[era]) as archive:
        for image in bpy.data.images:
            if image.source != 'FILE':
                continue
            assert image.packed_file, image.name
            member = 'assets/minecraft/' + image.filepath.split('assets/minecraft/', 1)[1]
            packed = image.packed_file.data
            original = archive.read(member)
            assert packed == original, (image.name, member)
            textures.append({'image': image.name, 'jar_member': member, 'sha256': hashlib.sha256(packed).hexdigest(), 'packed_bytes': len(packed), 'exact_jar_byte_match': True})
        for path in sorted((ROOT / 'evidence' / era).glob('*-blockstate.json')):
            member = 'assets/minecraft/blockstates/' + path.name.replace('-blockstate.json', '.json')
            assert path.read_bytes() == archive.read(member), path.name
            states.append({'file': str(path.relative_to(ROOT)), 'jar_member': member, 'exact_jar_byte_match': True})
    results.append({'image': name + '.png', 'packed_scene': name + '.blend', 'source_jar': str(jars[era]), 'textures': textures, 'official_blockstates': states})
(ROOT / 'asset-verification.json').write_text(json.dumps({'resources': resources, 'renders': results}, indent=2) + '\n')
print('OFFICIAL_ASSET_VERIFIED ' + json.dumps({row['image']: len(row['textures']) for row in results}))
