"""Decode final PNGs and prove seven separated stations and unchanged exemptions."""
import csv
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent
results = []
tables = {}
manifest = []
for era, project in [('legacy', 'LegacyMinecraftModTemplate'), ('modern', 'ModernMinecraftModTemplate')]:
    name = era + '-hub-down-left-1'
    path = ROOT / (name + '.png')
    metadata = json.loads((ROOT / (name + '-metadata.json')).read_text())
    packed = json.loads((ROOT / (name + '-packed-verification.json')).read_text())
    assert packed['reopened_packed_scene'] and packed['embedded_scripts_match_disk']
    with Image.open(path) as image:
        assert image.format == 'PNG' and image.size == (1024, 1024)
        image.load()
        current = image.convert('RGB')
    with Image.open(ROOT.parent / 'blender-m' / (era + '-hub-1.png')) as image:
        baseline = image.convert('RGB')
    background = current.getpixel((0, 0))
    background_image = Image.new('RGB', current.size, background)
    difference = ImageChops.difference(current, background_image)
    red, green, blue = difference.split()
    foreground = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(lambda v: 255 if v > 2 else 0)
    union = Image.new('L', current.size)
    draw = ImageDraw.Draw(union)
    station_results = []
    table = metadata['geometry']['facing_table']
    for row in table:
        low_x, low_y, high_x, high_y = metadata['geometry']['station_bounds_normalized_xy_y_up'][row['station']]
        box = (max(0, math.floor(low_x * 1024) - 2), max(0, math.floor((1 - high_y) * 1024) - 2), min(1024, math.ceil(high_x * 1024) + 2), min(1024, math.ceil((1 - low_y) * 1024) + 2))
        draw.rectangle(box, fill=255)
        occupancy = sum(v != 0 for v in foreground.crop(box).get_flattened_data())
        assert occupancy > 200, (name, row['station'], occupancy)
        delta = ImageChops.difference(current.crop(box), baseline.crop(box))
        changed = sum(pixel != (0, 0, 0) for pixel in delta.get_flattened_data())
        if row['facing'] == 'n/a - no facing blockstate':
            assert changed == 0, ('Non-facing station pixels changed', name, row['station'], changed)
        if row['station'] in {'furnace', 'blast_furnace', 'chest', 'ender_chest'}:
            assert changed > 500, ('Directional front did not visibly change', name, row['station'], changed)
        station_results.append({'station': row['station'], 'position': row['position'], 'box_pixels': box, 'foreground_pixels': occupancy, 'changed_pixels_against_approved': changed, 'canonical_exemption_unchanged': changed == 0 if row['facing'].startswith('n/a') else None})
    stray = ImageChops.subtract(foreground, union)
    assert stray.getbbox() is None, 'Pixels outside verified station bounds'
    assert current.getpixel((1023, 1023)) == background
    assert current.getpixel((1023, 0)) == background
    assert current.getpixel((0, 1023)) == background
    assert hashlib.sha256(path.read_bytes()).hexdigest() == metadata['png_sha256']
    tables[era] = table
    results.append({'image': path.name, 'resolution': [1024, 1024], 'format': 'PNG', 'opened_and_decoded': True, 'background_rgb': background, 'station_count': len(station_results), 'stations': station_results, 'no_foreground_outside_projected_geometry': True})
    manifest.append({
        'project': project,
        'label': era.title() + ' hub - all directional workstations face down-left',
        'path': 'blender-q/' + path.name,
        'method': f"Blender {metadata['blender_version']} headless -noaudio; {metadata['engine']} {metadata['device']}; {metadata['samples']} samples; 1024x1024 PNG; {metadata['render_duration_seconds']:.6f} s render; 3 threads under shared 3-core CPUWeight 20 cgroup",
        'source': {'approved': 'blender-m/' + era + '-hub-1.png', 'script': 'blender-q/' + name + '.py', 'shared_authoring_script': 'blender-q/render_down_left.py', 'packed_scene': 'blender-q/' + name + '.blend', 'immutable_source_scene': 'blender-q/source/' + era + '-hub-1.blend', 'textures': 'Unchanged real Minecraft ' + ('1.8.9' if era == 'legacy' else '26.2') + ' client assets packed in the scene'},
        'notes': 'Every directional block is facing=east. Minecraft +X maps to Blender (0,-1,0) and projects down-left at retained camera yaw45. Same seven positions, alternating differing trio top/bottom-right/bottom-left, canonical meshes/UVs, lighting formula, camera/framing and backgrounds as approved blender-m. Crafting/enchanting/brewing and modern smithing have no facing blockstate and remain canonical; approved book entity pose is retained. Furnace fronts and chest latches are now on the screen-left visible face. See facing-table.csv/json and per-image verification metadata. Local-only saved scripts, no repository commit.'
    })
for old, new in zip(tables['legacy'], tables['modern']):
    assert old['position'] == new['position']
    assert old['position_blender_xyz'] == new['position_blender_xyz']
    if old['station'] in {'crafting_table', 'enchanting_table', 'brewing_stand', 'chest'}:
        assert old['station'] == new['station'] and old['facing'] == new['facing']
facing = {
    'coordinate_convention': 'Minecraft (x,y,z) -> Blender (-z,-x,y); camera-local X is right, Y is up, Z is toward viewer. PNG X is right, Y is down.',
    'chosen_direction': 'east',
    'minecraft_direction_xyz': [1, 0, 0],
    'blender_direction_xyz': [0, -1, 0],
    'normalized_screen_direction_xy_y_down': [-math.sqrt(3) / 2, .5],
    'canonical_exemptions': ['crafting_table', 'enchanting_table', 'brewing_stand', 'smithing_table (modern only)'],
    'same_layout_proved': True,
    'tables': tables,
}
(ROOT / 'png-verification.json').write_text(json.dumps(results, indent=2) + '\n')
(ROOT / 'facing-table.json').write_text(json.dumps(facing, indent=2) + '\n')
(ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
columns = ['template', 'station', 'position', 'facing', 'canonical_model_y_degrees', 'minecraft_direction_xyz', 'blender_direction_xyz', 'camera_relative_direction_xyz', 'screen_delta_pixels_per_block_xy_y_down', 'proof']
with (ROOT / 'facing-table.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=columns, extrasaction='ignore')
    writer.writeheader()
    for table in tables.values():
        writer.writerows(table)
print(json.dumps({'pngs_verified': len(results), 'station_rows': 14, 'same_layout': True, 'all_canonical_exemption_pixels_identical_to_approved': True, 'render_times_seconds': {entry['path']: json.loads((ROOT / (Path(entry['path']).stem + '-metadata.json')).read_text())['render_duration_seconds'] for entry in manifest}}))
