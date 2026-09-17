"""Load approved packed hubs and change only legal workstation facing to east.
Run with Blender --background -noaudio --threads 3 --python <template>.py.
Local-only saved authorship: do not commit this portfolio working directory.
"""
import bpy
import csv
import hashlib
import json
import math
import os
import sys
import time
from array import array
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'source'))
import render_hubs as approved

DIRECTIONAL = {'furnace', 'blast_furnace', 'anvil', 'chest', 'ender_chest', 'grindstone'}
TARGET = Vector((0, -1, 0))
SAMPLES = 32
THREADS = 3
STATELESS = 'n/a - no facing blockstate'


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def wait_for_shared_cpu_cap():
    """The existing watchdog owns process migration; never create a new slice."""
    deadline = time.monotonic() + 90
    while True:
        cgroup = Path('/proc/self/cgroup').read_text().strip()
        if 'render-blender.service' in cgroup:
            relative = next(row.split(':', 2)[2] for row in cgroup.splitlines() if row.startswith('0:'))
            path = Path('/sys/fs/cgroup') / relative.lstrip('/')
            cpu_max = (path / 'cpu.max').read_text().strip()
            weight = int((path / 'cpu.weight').read_text())
            quota, period = map(int, cpu_max.split())
            assert quota / period <= 3 and weight == 20, (cpu_max, weight)
            affinity = sorted(os.sched_getaffinity(0))
            assert len(affinity) <= 3, affinity
            return {'cgroup': relative, 'cpu_max': cpu_max, 'cpu_weight': weight, 'affinity': affinity}
        if time.monotonic() > deadline:
            raise RuntimeError('Watchdog did not move Blender into shared capped render-blender.service: ' + cgroup)
        time.sleep(.25)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def matrix_rows(matrix):
    return [list(row) for row in matrix]


def mesh_signature(obj):
    mesh = obj.data
    return digest({
        'vertices': [list(v.co) for v in mesh.vertices],
        'faces': [list(p.vertices) for p in mesh.polygons],
        'uv_layers': {uv.name: [list(item.uv) for item in uv.data] for uv in mesh.uv_layers},
        'face_materials': [mesh.materials[p.material_index].name for p in mesh.polygons],
    })


def stations():
    return sorted((obj for obj in bpy.context.scene.objects if obj.get('station')), key=lambda obj: obj['slot_index'])


def snapshot():
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    return {
        'geometry': {obj.name: mesh_signature(obj) for obj in scene.objects if obj.type == 'MESH'},
        'positions': {obj['station']: list(obj.matrix_world.translation) for obj in stations()},
        'local_transforms': {obj.name: matrix_rows(obj.matrix_basis) for obj in scene.objects},
        'parent_inverse': {obj.name: matrix_rows(obj.matrix_parent_inverse) for obj in scene.objects},
        'camera_matrix': matrix_rows(scene.camera.matrix_world),
        'camera_scale': scene.camera.data.ortho_scale,
        'camera_yaw_degrees': scene['camera_yaw_degrees'],
        'background': list(scene.world.node_tree.nodes['Background'].inputs[0].default_value),
        'world_strength': scene.world.node_tree.nodes['Background'].inputs[1].default_value,
        'view': [scene.view_settings.view_transform, scene.view_settings.look, scene.view_settings.exposure, scene.view_settings.gamma],
        'lighting': json.loads(scene['lighting_parameters_json']),
        'textures': {image.name: hashlib.sha256(image.packed_file.data).hexdigest() for image in bpy.data.images if image.source == 'FILE'},
        'object_names': sorted(obj.name for obj in scene.objects),
    }


def blockstate_evidence(era, name):
    filename = ROOT / 'evidence' / era / (name + '-blockstate.json')
    if name in {'chest', 'ender_chest'}:
        return {'kind': 'vanilla entity-rendered block', 'proof': 'The approved canonical north-facing latch has local Minecraft -Z normal; legal cardinal block facing is applied to the whole chest, not inferred from entity blockstate JSON.', 'json': str(filename.relative_to(ROOT)) if filename.exists() else None}
    data = json.loads(filename.read_text())
    if name not in DIRECTIONAL:
        assert 'facing' not in json.dumps(data), name
        return {'json': str(filename.relative_to(ROOT)), 'proof': 'Official blockstate contains no facing property; canonical parent rotation remains zero.'}
    variants = {key: value for key, value in data['variants'].items() if 'facing=east' in key and ('face=floor' in key if name == 'grindstone' else 'damage=0' in key if name == 'anvil' else 'lit=false' in key if name == 'blast_furnace' else True)}
    assert len(variants) == 1, (name, variants)
    return {'json': str(filename.relative_to(ROOT)), 'selected_variant': variants}


def projection(scene, origin, direction):
    a = world_to_camera_view(scene, scene.camera, origin)
    b = world_to_camera_view(scene, scene.camera, origin + direction)
    return [(b.x - a.x) * 1024, -(b.y - a.y) * 1024]


def verify(before, era):
    scene = bpy.context.scene
    after = snapshot()
    for key in ['geometry', 'positions', 'parent_inverse', 'camera_matrix', 'camera_scale', 'camera_yaw_degrees', 'background', 'world_strength', 'view', 'textures', 'object_names']:
        assert before[key] == after[key], ('Unexpected approved-scene change', key)
    for key, value in before['lighting'].items():
        if key != 'block_levels_sampled':
            assert value == after['lighting'][key], ('lighting', key)
    changed_parents = {obj.name for obj in stations() if obj['station'] in DIRECTIONAL}
    for name, matrix in before['local_transforms'].items():
        if name not in changed_parents:
            assert after['local_transforms'][name] == matrix, ('Non-facing transform changed', name)
    assert scene['camera_yaw_degrees'] == 45
    assert scene.render.engine == 'CYCLES' and scene.cycles.device == 'CPU'
    assert scene.render.threads_mode == 'FIXED' and scene.render.threads == THREADS
    assert scene.cycles.samples == SAMPLES
    assert scene.render.resolution_x == scene.render.resolution_y == 1024
    assert not any(obj.type == 'LIGHT' for obj in scene.objects)
    assert all(image.packed_file for image in bpy.data.images if image.source == 'FILE')
    camera_inverse = scene.camera.matrix_world.to_3x3().inverted()
    camera_direction = camera_inverse @ TARGET
    assert camera_direction.x < 0 and camera_direction.y < 0
    table = []
    bounds = {}
    for obj in stations():
        name = obj['station']
        loc = obj.matrix_world.translation
        directional = name in DIRECTIONAL
        if directional:
            actual = (obj.matrix_world.to_3x3() @ Vector((1, 0, 0))).normalized()
            assert (actual - TARGET).length < 1e-6, (name, list(actual))
            assert obj['facing'] == 'east'
            assert abs(obj.rotation_euler.z + math.pi / 2) < 1e-6
            delta = projection(scene, loc, actual)
            assert delta[0] < 0 and delta[1] > 0
        else:
            assert max(abs(angle) for angle in obj.rotation_euler) < 1e-7
            assert obj['facing'] == STATELESS
            delta = None
        row = {
            'template': era, 'station': name, 'position': obj['position'],
            'position_blender_xyz': list(loc), 'position_minecraft_xyz': [-loc.y, loc.z, -loc.x],
            'facing': obj['facing'], 'applied_rotation_degrees_blender_z': -90 if directional else 0,
            'canonical_model_y_degrees': obj['canonical_model_y_degrees'],
            'minecraft_direction_xyz': [1, 0, 0] if directional else None,
            'blender_direction_xyz': list(TARGET) if directional else None,
            'camera_relative_direction_xyz': list(camera_direction) if directional else None,
            'screen_delta_pixels_per_block_xy_y_down': delta,
            'proof': 'Minecraft east (+X) -> Blender (0,-1,0); camera-relative X<0 and Y<0, hence left and down. PNG coordinate Y grows downward.' if directional else 'No facing blockstate. Approved canonical rotation and all child transforms retained.',
            'blockstate_evidence': blockstate_evidence(era, name),
        }
        if name in {'chest', 'ender_chest'}:
            latch = next(child for child in obj.children_recursive if child.name.startswith('North-facing vanilla latch'))
            latch_center = sum((vertex.co for vertex in latch.data.vertices), Vector()) / len(latch.data.vertices)
            latch_direction = latch.matrix_world @ latch_center - loc
            latch_direction.z = 0
            assert latch_direction.normalized().dot(TARGET) > .999999
            row['visible_front_proof'] = {'latch_horizontal_direction': list(latch_direction.normalized()), 'normal_points_toward_camera': TARGET.dot((scene.camera.location - loc).normalized()) > 0}
            assert row['visible_front_proof']['normal_points_toward_camera']
        if name in {'furnace', 'blast_furnace'}:
            front_normals = []
            for child in obj.children_recursive:
                if child.type != 'MESH':
                    continue
                for polygon in child.data.polygons:
                    if 'furnace_front' in child.data.materials[polygon.material_index].name:
                        normal = (child.matrix_world.to_3x3().inverted().transposed() @ polygon.normal).normalized()
                        assert normal.dot(TARGET) > .999999
                        front_normals.append(list(normal))
            assert front_normals
            row['visible_front_proof'] = {'textured_front_polygon_normals': front_normals}
        if name in {'anvil', 'grindstone'}:
            row['note'] = 'Canonical geometry is symmetric under 180 degrees: semantic east is proven by the legal blockstate/model transform, not a fabricated front marker.'
        if name == 'enchanting_table':
            row['note'] = 'The table has no facing blockstate. Its separate book entity retains the approved toward-centre pose, not an invented table facing.'
        points = [world_to_camera_view(scene, scene.camera, child.matrix_world @ vertex.co) for child in obj.children_recursive if child.type == 'MESH' for vertex in child.data.vertices]
        bound = [min(p.x for p in points), min(p.y for p in points), max(p.x for p in points), max(p.y for p in points)]
        assert all(.035 < value < .965 for value in bound), (name, bound)
        bounds[name] = bound
        table.append(row)
    assert len(table) == 7 and table[0]['station'] == 'crafting_table'
    assert [row['position'] for row in table] == ['center', 'top', 'top-right', 'bottom-right', 'bottom', 'bottom-left', 'top-left']
    for first, a in bounds.items():
        for second, b in bounds.items():
            if first >= second:
                continue
            assert min(a[2], b[2]) <= max(a[0], b[0]) or min(a[3], b[3]) <= max(a[1], b[1]), ('Overlap', first, second)
    brew = next(obj for obj in stations() if obj['station'] == 'brewing_stand')
    meshes = [obj for obj in brew.children_recursive if obj.type == 'MESH']
    feet = [obj for obj in meshes if len(obj.data.polygons) == 6 and abs(max(v.co.z for v in obj.data.vertices) - 2/16) < 1e-7]
    arms = [obj for obj in meshes if len(obj.data.polygons) == 1]
    assert len(feet) == len(arms) == 3
    return {
        'facing_table': table, 'station_bounds_normalized_xy_y_up': bounds,
        'all_mesh_vertices_topology_uvs_material_assignments_unchanged': True,
        'all_station_positions_unchanged': True, 'all_non_facing_transforms_unchanged_including_book': True,
        'camera_yaw45_projection_world_color_management_unchanged': True,
        'lighting_formula_and_parameters_unchanged': True, 'packed_texture_bytes_unchanged': True,
        'station_projected_bounds_disjoint': True, 'all_geometry_fully_in_frame': True,
        'brewing_feet': len(feet), 'brewing_arm_planes': len(arms),
        'mesh_count': len(after['geometry']), 'packed_texture_count': len(after['textures']),
        'camera_relative_east_direction_xyz': list(camera_direction),
    }


def render(era):
    assert era in {'legacy', 'modern'}
    resources = wait_for_shared_cpu_cap()
    name = era + '-hub-down-left-1'
    baseline = ROOT / 'source' / (era + '-hub-1.blend')
    bpy.ops.wm.open_mainfile(filepath=str(baseline))
    before = snapshot()
    scene = bpy.context.scene
    for obj in stations():
        directional = obj['station'] in DIRECTIONAL
        if directional:
            obj.rotation_euler.z = -math.pi / 2
        obj['facing'] = 'east' if directional else STATELESS
        obj['placement_rotation_degrees'] = 90 if directional else 0
        obj['canonical_model_y_degrees'] = 270 if obj['station'] == 'anvil' else 90 if directional else 0
        for obsolete in ['center_alignment_dot', 'center_error_degrees']:
            if obsolete in obj:
                del obj[obsolete]
    # Keep the identical world-relative vanilla lighting formula. Recalculate the
    # per-face shade after rotation rather than rotating previously baked light.
    for obj in scene.objects:
        if obj.type == 'MESH':
            attribute = obj.data.color_attributes.get('vanilla_daylight')
            if attribute:
                obj.data.color_attributes.remove(attribute)
    approved.mc.ERA = era
    approved.apply_daylight()
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = SAMPLES
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = THREADS
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(ROOT / (name + '.png'))
    scene['facing_rule'] = 'Every directional workstation is east (down-left at camera yaw45); no-facing blocks remain canonical.'
    scene['source_approved_png'] = 'blender-m/' + era + '-hub-1.png'
    geometry = verify(before, era)
    scene['verification_json'] = json.dumps(geometry)
    # Preserve the baseline authoring texts and add the executable cutover scripts.
    for filename in ['render_down_left.py', name + '.py']:
        text = bpy.data.texts.get(filename)
        if text:
            bpy.data.texts.remove(text)
        text = bpy.data.texts.load(str(ROOT / filename))
        text.use_fake_user = True
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / (name + '.blend')))
    start = time.perf_counter()
    bpy.ops.render.render(write_still=True)
    elapsed = time.perf_counter() - start
    image = bpy.data.images.load(str(ROOT / (name + '.png')), check_existing=False)
    assert list(image.size) == [1024, 1024]
    pixels = array('f', [0]) * len(image.pixels)
    image.pixels.foreach_get(pixels)
    assert max(pixels[0::4]) > .1
    bpy.data.images.remove(image)
    metadata = {
        'name': name, 'template': era, 'source': scene['source_approved_png'],
        'blender_version': bpy.app.version_string, 'engine': scene.render.engine,
        'device': scene.cycles.device, 'samples': scene.cycles.samples,
        'render_duration_seconds': elapsed, 'resolution': [1024, 1024],
        'png_sha256': hashlib.sha256((ROOT / (name + '.png')).read_bytes()).hexdigest(),
        'author_script_sha256': hashlib.sha256((ROOT / 'render_down_left.py').read_bytes()).hexdigest(),
        'geometry': geometry, 'png_decoded_after_render': True,
        'resources': {**resources, 'threads': THREADS, 'background': True, 'display': None, 'audio': None, 'gpu': None},
        'lighting_parameters': json.loads(scene['lighting_parameters_json']),
    }
    dump(ROOT / (name + '-metadata.json'), metadata)
    # Re-open the delivered packed scene, proving the saved artifact, not just memory.
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / (name + '.blend')))
    saved = verify(before, era)
    for filename in ['render_down_left.py', name + '.py']:
        assert bpy.data.texts[filename].as_string() == (ROOT / filename).read_text()
    dump(ROOT / (name + '-packed-verification.json'), {'reopened_packed_scene': True, 'embedded_scripts_match_disk': True, **saved})
    print('RENDER_COMPLETE ' + json.dumps({key: metadata[key] for key in ['name', 'blender_version', 'engine', 'device', 'samples', 'render_duration_seconds']}), flush=True)
    return metadata


if __name__ == '__main__':
    for template in sys.argv[sys.argv.index('--') + 1:]:
        render(template)
