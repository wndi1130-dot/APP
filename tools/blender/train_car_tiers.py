r"""열차 살림 단계 31종 — Blender 4.5, 정점색 Col(선형), 한 메시·한 surface.

blender -b --factory-startup -P tools/blender/train_car_tiers.py -- --repo .
    [--src-open C:\dev\zombie\wt\open_assets] [--only a,b]
    [--stage-only] [--render-contact-sheet]

0 누더기: 창 아래 보수판·천·짚, 막대걸이 초, 깡통 난로, 자루 침상.
1 손봄: 벽걸이 나무함 두 크기, 드럼통 난로.
2 갖춤: 빈 끝벽·윗벽 선반, 소형 살림 12종.
3 북유럽식: 낮은 밝은 판벽·막대 전등·추상 액자·화분, 문 없는 낮은 침상.
금지: 사슬, 옷·신발·소지품·음식 더미, 군복 색, 얼굴, 글자, 창막이.
판·천은 높이 0.42 m의 창 아래 마감만 만든다. 실제 창 간섭은 배치 세션 담당.

공개 원본(저장소에 복사하지 않음):
CC0 루트 = --src-open (기본 C:\dev\zombie\wt\open_assets).
kenney_furniture/x/Models/GLTF format/{rugSquare,kitchenCabinetUpper,
  kitchenCabinetUpperLow,paneling,lampWall,pottedPlant}.glb
kenney_survival/x/Models/GLB format/{resource-planks,barrel,barrel-open,
  bedroll,bottle}.glb
kaykit_dungeon/x/KayKit-Dungeon-Remastered-1.0-main/addons/
  kaykit_dungeon_remastered/Assets/gltf/{candle_thin,shelf_small,plate_small}.gltf.glb
kaykit_furniture/x/KayKit-Furniture-Bits-1.0-main/addons/
  kaykit_furniture_bits/Assets/gltf/{pictureframe_small_A,book_single}.gltf
각 팩의 License.txt 또는 Assets/LICENSE.txt에서 CC0를 확인한다.
사용한 CC BY 4.0: G:/내 드라이브/좀비_공개자산/google_scanned_objects/
  Cole_Hardware_Mug_Classic_Blue.zip 내부 meshes/model.obj.
크레딧: Google Scanned Objects, Google Research, CC BY 4.0,
  https://research.google/resources/datasets/scanned-objects-google-research/
  https://creativecommons.org/licenses/by/4.0/ ; 면 축소·형태 맞춤·재착색.
CC0 목록에서 손잡이 컵이 없음을 먼저 확인한 뒤 CC BY 사용.
CC BY 후보 Threshold_Porcelain_Teapot_White.zip와
Crosley_Alarm_Clock_Vintage_Metal.zip은 실제 축소 렌더에서 48삼각형 이하로
형태가 보존되지 않아 제외했다. 천·실패·솔·주전자·시계는 기본 도형이다.

Piece.fit/check_glb의 기존 중앙 원점 검사를 먼저 실제 GLB에 수행하고,
새 31종만 바닥 원점으로 옮겨 다시 내보내고 바이너리 좌표·색을 검사한다.
기존 GLB와 .import, 게임 코드, 배치 파일은 쓰지 않는다. Godot은 실행 안 함.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import re
import struct
import traceback
import zipfile
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import train_interior as ti
import train_car_dress as dress
import train_car_layers as layers

SCRIPT = 'tools/blender/train_car_tiers.py'
LIMIT = 2430
KIT_LIMIT = 10000
BASE_TRIS = 7570
DEFAULT_OPEN = Path(r'C:\dev\zombie\wt\open_assets')
GSO_ROOT = Path('G:/내 드라이브/좀비_공개자산/google_scanned_objects')
CC_BY = 'Google Scanned Objects / Google Research — CC BY 4.0; 원본 면 축소·크기 조정·재착색'
CC_BY_URL = 'https://research.google/resources/datasets/scanned-objects-google-research/'
LICENSE_URL = 'https://creativecommons.org/licenses/by/4.0/'
SPECS = {
    'wall_patch': (0, (.48, .42, .02), 60, '창 아래 벽의 덧댄 판자'),
    'tarp_patch': (0, (.48, .42, .01), 16, '창 아래 벽에 못 두 개로 고정한 천 조각'),
    'straw_mat': (0, (.60, .015, .20), 24, '얇은 짚 마감'),
    'stick_candle': (0, (.13, .32, .13), 48, '사슬 없는 막대 고리의 초'),
    'tin_stove': (0, (.40, .70, .40), 120, '낡은 깡통 난로 외형'),
    'sack_bunk_upper': (0, (2.80, .14, .60), 96, '자루 침구의 얇은 위 침상'),
    'sack_bunk_lower': (0, (1.75, .48, .58), 120, '자루 침구의 다리 있는 아래 침상'),
    'wood_wall_box': (1, (.48, .42, .28), 60, '벽걸이 나무 보관함'),
    'wood_wall_box_shallow': (1, (.48, .22, .28), 60, '열차장실 얕은 벽걸이 나무 보관함'),
    'drum_stove': (1, (.40, .70, .40), 144, '띠가 있는 드럼통 난로 외형'),
    'end_shelf': (2, (.48, .90, .28), 96, '빈 끝벽 수납 선반'),
    'top_shelf': ('2·3', (.48, .24, .28), 48, '빈 윗벽 선반'),
    'pale_paneling': (3, (12., .42, .05), 96, '창 아래 낮고 밝은 나무 판벽 띠'),
    'stick_lamp': (3, (.13, .32, .13), 80, '막대 고리와 갓·전구를 갖춘 전등'),
    'small_frame': (3, (.30, .40, .025), 28, '얼굴·글자 없는 추상 그림 액자'),
    'wall_plant': (3, (.12, .20, .12), 64, '등이 -Z인 벽걸이 화분'),
    'table_plant': (3, (.12, .20, .12), 64, '탁상 작은 화분'),
    'open_bunk_upper': (3, (2.80, .14, .60), 120, '문 없는 낮은 테두리의 위 침상'),
    'open_bunk_lower': (3, (1.75, .48, .58), 160, '문 없는 낮은 테두리의 아래 침상'),
    'tiny_cup': ('2·3', (.07, .09, .07), 48, '손잡이 있는 빈 컵'),
    'tiny_bowl': ('2·3', (.11, .045, .11), 48, '빈 그릇 하나'),
    'tiny_plate': ('2·3', (.12, .015, .12), 48, '빈 접시 하나'),
    'tiny_bottle': ('2·3', (.06, .14, .06), 48, '라벨 없는 작은 병'),
    'tiny_can': ('2·3', (.07, .09, .07), 48, '라벨 없는 깡통'),
    'tiny_jar': ('2·3', (.09, .10, .09), 48, '짧은 목의 작은 단지'),
    'tiny_teapot': ('2·3', (.14, .11, .10), 48, '손잡이와 주둥이 있는 찻주전자'),
    'tiny_tray': ('2·3', (.18, .02, .12), 48, '빈 타원 쟁반'),
    'thread_spool': ('2·3', (.05, .07, .05), 48, '실을 감은 육각 실패'),
    'tiny_brush': ('2·3', (.04, .02, .14), 48, '나무 손잡이와 솔 부분'),
    'tiny_clock': ('2·3', (.09, .11, .04), 48, '글자·숫자 없는 탁상시계와 두 바늘'),
    'tiny_book': ('2·3', (.12, .025, .09), 48, '글자 없는 표지와 종이 단면의 책'),
}
CC0 = {
    'planks': ('kenney_survival', 'resource-planks.glb'),
    'mat': ('kenney_furniture', 'rugSquare.glb'),
    'candle': ('kaykit_dungeon', 'candle_thin.gltf.glb'),
    'barrel': ('kenney_survival', 'barrel.glb'),
    'jar': ('kenney_survival', 'barrel-open.glb'),
    'bedroll': ('kenney_survival', 'bedroll.glb'),
    'box': ('kenney_furniture', 'kitchenCabinetUpper.glb'),
    'shallow': ('kenney_furniture', 'kitchenCabinetUpperLow.glb'),
    'end': ('kenney_furniture', 'bookcaseOpenLow.glb'),
    'top': ('kaykit_dungeon', 'shelf_small.gltf.glb'),
    'panel': ('kenney_furniture', 'paneling.glb'),
    'lamp': ('kenney_furniture', 'lampWall.glb'),
    'frame': ('kaykit_furniture', 'pictureframe_small_A.gltf'),
    'plant': ('kenney_furniture', 'pottedPlant.glb'),
    'plate': ('kaykit_dungeon', 'plate_small.gltf.glb'),
    'bottle': ('kenney_survival', 'bottle.glb'),
    'book': ('kaykit_furniture', 'book_single.gltf'),
}
GSO = {
    'cup': 'Cole_Hardware_Mug_Classic_Blue',
    'teapot': 'Threshold_Porcelain_Teapot_White',
    'clock': 'Crosley_Alarm_Clock_Vintage_Metal',
}
SOURCE_KEYS = {
    'wall_patch': 'planks', 'straw_mat': 'mat', 'stick_candle': 'candle',
    'tin_stove': 'barrel', 'drum_stove': 'barrel', 'sack_bunk_upper': 'bedroll',
    'sack_bunk_lower': 'bedroll', 'wood_wall_box': 'box', 'wood_wall_box_shallow': 'shallow',
    'end_shelf': 'top', 'top_shelf': 'top', 'pale_paneling': 'panel', 'stick_lamp': 'lamp',
    'small_frame': 'frame', 'wall_plant': 'plant', 'table_plant': 'plant',
    'open_bunk_upper': 'bedroll', 'open_bunk_lower': 'bedroll', 'tiny_cup': 'cup',
    'tiny_bowl': 'plate', 'tiny_plate': 'plate', 'tiny_bottle': 'bottle',
    'tiny_can': 'barrel', 'tiny_jar': 'jar', 'tiny_teapot': 'teapot', 'tiny_tray': 'plate',
    'tiny_clock': 'clock', 'tiny_book': 'book',
}
SEARCH_NOTES = {
    'end_shelf': 'CC0 bookcaseOpenLow는 단순 축소 후 112삼각형으로 목표 92를 넘음. CC0 shelf_small을 위아래 두 개의 빈 벽걸이 선반으로 구성.',
    'tarp_patch': 'CC0 structure-canvas·tent-canvas는 프레임/입체 지붕이라 평평한 벽 보수 천과 다름; 드라이브 파일명 목록에서 맞는 후보를 식별하지 못함. scenario의 불투명 ID는 부재 증거가 아님.',
    'thread_spool': '네 CC0 팩 names.txt와 드라이브 파일명 목록에서 spool/thread/sewing에 맞는 소형 실패를 식별하지 못함. scenario의 불투명 ID는 부재 증거가 아님.',
    'tiny_brush': '네 CC0 팩 names.txt와 드라이브 파일명 목록에서 손잡이 솔에 맞는 brush/broom을 식별하지 못함. brushed 재질 파일은 제외. scenario의 불투명 ID는 부재 증거가 아님.',
    'tiny_cup': 'CC0 bucket은 들손 양동이이고 컵 손잡이/비례와 다름. CC BY 손잡이 컵 선택.',
    'tiny_teapot': 'CC0 teapot/kettle 후보 없음. G:/내 드라이브/좀비_공개자산/google_scanned_objects/Threshold_Porcelain_Teapot_White.zip을 실제 44면으로 축소했으나 주둥이·몸체 붕괴를 렌더에서 확인; 이 예산에 맞는 원본이 아니어서 기본 도형.',
    'tiny_clock': 'CC0 clock 후보 없음. G:/내 드라이브/좀비_공개자산/google_scanned_objects/Crosley_Alarm_Clock_Vintage_Metal.zip을 실제 38면 몸체로 축소했으나 몸체의 가시 같은 돌출을 렌더에서 확인; 이 예산에 맞지 않아 기본 도형.',
}
WALL_IDS = {'wall_patch', 'tarp_patch', 'wood_wall_box', 'wood_wall_box_shallow',
            'end_shelf', 'top_shelf', 'pale_paneling', 'small_frame', 'wall_plant'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def source_info(key, root):
    if key in CC0:
        pack, name = CC0[key]
        matches = sorted((root / pack).rglob(name))
        if len(matches) != 1:
            raise ValueError('F-INPUT-MISSING: 원본 경로가 유일하지 않음 ' + key)
        licences = [p for p in (root / pack).rglob('*') if p.is_file() and p.name.lower() == 'license.txt']
        if not licences or not any('CC0' in p.read_text(encoding='utf-8-sig') for p in licences):
            raise ValueError('F-INPUT-MISSING: CC0 라이선스 ' + pack)
        path = matches[0]
        return {'path': str(path), 'pack': pack, 'file': path.relative_to(root).as_posix(),
                'license': 'CC0-1.0', 'license_path': str(licences[0]), 'sha256': sha(path)}
    path = GSO_ROOT / (GSO[key] + '.zip')
    if not path.is_file():
        raise ValueError('F-INPUT-MISSING: ' + str(path))
    return {'path': str(path), 'pack': 'google_scanned_objects', 'file': path.name + '!meshes/model.obj',
            'license': 'CC-BY-4.0', 'credit': CC_BY, 'source_url': CC_BY_URL,
            'license_url': LICENSE_URL, 'license_evidence': '발주문에 CC BY 4.0 명시; 로컬 ZIP metadata.pbtxt도 조사 기록',
            'sha256': sha(path)}


def load_source(info):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = Path(info['path'])
    if path.suffix == '.zip':
        # OBJ를 ZIP에서 메모리로 읽는다. 원본 OBJ/질감을 작업 폴더에 추출하지 않는다.
        with zipfile.ZipFile(path) as z:
            content = z.read('meshes/model.obj').decode('utf-8')
        vs, fs = [], []
        for line in content.splitlines():
            bits = line.split()
            if not bits:
                continue
            if bits[0] == 'v':
                vs.append(tuple(float(v) for v in bits[1:4]))
            elif bits[0] == 'f':
                fs.append(tuple(int(v.split('/')[0]) - 1 for v in bits[1:]))
        mesh = bpy.data.meshes.new(path.stem)
        mesh.from_pydata(vs, [], fs)
        mesh.update()
        obj = bpy.data.objects.new(path.stem, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        raise ValueError('F-GEOMETRY: 메시 없는 원본 ' + str(path))
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        obj.select_set(True)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def simplify(obj, target):
    """props_stop01_cc0의 용접→평면 정리→collapse 순서. 부품을 임의 제거하지 않는다."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.0000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    mod = obj.modifiers.new('planar', 'DECIMATE')
    mod.decimate_type = 'DISSOLVE'
    mod.angle_limit = math.radians(.5)
    mod.delimit = {'MATERIAL'}
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    for _ in range(5):
        count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if count <= target:
            break
        mod = obj.modifiers.new('budget', 'DECIMATE')
        mod.ratio = max(.0005, target / count * .97)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if not 0 < count <= target:
        raise ValueError('F-BUDGET: 원본 축소 실패 %d/%d' % (count, target))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.0000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return before, sum(len(p.vertices) - 2 for p in obj.data.polygons)


def add_source(p, root, key, size, target, centre=(0, 0, 0), rotation=None, paint='wood', style=''):
    info = source_info(key, root)
    obj = load_source(info)
    before, after = simplify(obj, target)
    if rotation is not None:
        obj.data.transform(rotation.to_4x4())
        obj.data.update()
    vs = [v.co.copy() for v in obj.data.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    if min(hi[i] - lo[i] for i in range(3)) < 1e-8:
        raise ValueError('F-GEOMETRY: 축소 후 두께 없음 ' + key)
    # Blender XYZ -> Godot X,Y,Z. 여기서는 새 부품의 바닥과 발자국 중심을 맞춘다.
    coords = [((v.x-(lo[0]+hi[0])/2)/(hi[0]-lo[0])*size[0] + centre[0],
               (v.z-lo[2])/(hi[2]-lo[2])*size[1] + centre[1],
               -(v.y-(lo[1]+hi[1])/2)/(hi[1]-lo[1])*size[2] + centre[2]) for v in vs]
    for face in obj.data.polygons:
        pts = [coords[i] for i in face.vertices]
        mid = sum((Vector(v) for v in pts), Vector()) / len(pts)
        nx = (mid.x-centre[0])/size[0]
        ny = (mid.y-centre[1])/size[1]
        nz = (mid.z-centre[2])/size[2]
        colour = paint
        if style == 'plant':
            colour = 'wool_moss' if ny > .35 else ('iron_worn' if ny > .24 else 'wool')
        elif style == 'frame':
            colour = 'wood_worn' if abs(nx) > .34 or ny < .10 or ny > .90 else ('cloth_blue' if ny > .40 else 'slate_faded')
        elif style == 'bed':
            colour = 'wool' if ny < .25 else ('cloth' if nx < -.15 else 'wool_dark')
        elif style == 'pale_bed':
            colour = 'cloth_faded' if ny > .2 else 'slate_faded'
        elif style == 'book':
            colour = 'paper_aged' if .12 < ny < .88 else 'cloth_blue'
        elif style == 'bottle':
            colour = 'iron_worn' if ny > .88 else 'glass_dark'
        elif style == 'metal':
            colour = 'iron_worn' if ny < .08 or ny > .89 else 'iron'
        elif style == 'ceramic':
            colour = 'iron_worn' if ny < .15 else 'slate_faded'
        elif style == 'candle':
            colour = 'soot' if ny > .92 else 'cloth'
        elif style == 'planks':
            colour = 'wood_dark' if int((nx + .51)*9) % 3 == 0 else 'wood'
        elif style == 'mat':
            colour = 'rope' if face.index % 3 else 'wool_dark'
        elif style == 'panel':
            colour = 'wood_worn' if ny < .07 or ny > .92 else 'cloth_faded'
        elif style == 'lamp':
            colour = 'iron' if ny > .75 or nz < -.23 else 'slate_faded'
        normal = Vector((face.normal.x, face.normal.z, -face.normal.y))
        area_vector = sum((Vector(pts[i]).cross(Vector(pts[(i+1) % len(pts)])) for i in range(len(pts))), Vector())
        if normal.length < .001 or area_vector.length < 1e-9:
            continue
        p.face(pts, colour, normal)
    info.update(original_triangles=before, reduced_triangles=after)
    if not any(s['path'] == info['path'] for s in p.sources):
        p.sources.append(info)
    bpy.data.objects.remove(obj, do_unlink=True)


def add_radial_source(p, root, key, size, heights, sides, centre=(0, 0, 0), opened=False, paint='iron'):
    """원본의 높이별 외곽 반경을 표본화하는 회전체 리토폴로지. 찌그러진 collapse 대신 사용."""
    info = source_info(key, root)
    obj = load_source(info)
    verts = [v.co.copy() for v in obj.data.vertices]
    original = sum(len(f.vertices)-2 for f in obj.data.polygons)
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    cx, cy = (lo[0]+hi[0])/2, (lo[1]+hi[1])/2
    samples = [((v.z-lo[2])/(hi[2]-lo[2]), math.hypot(v.x-cx, v.y-cy)) for v in verts]
    max_radius = max(r for _, r in samples)
    radii = []
    for h in heights:
        distance = min(abs(y-h) for y, _ in samples)
        radii.append(max(r for y, r in samples if abs(y-h) <= distance+.012)/max_radius)
    before = set(p.bm.faces)
    if opened:
        low, high = radii[0], max(radii)
        profile = [(0, low), (.96, high), (.96, high*.75), (.08, low*.72)]
    else:
        profile = list(zip(heights, radii))
    p.lathe((centre[0], centre[2]), [(centre[1]+y*size[1], r*size[0]/2, r*size[2]/2) for y, r in profile], paint, sides=sides)
    added = set(p.bm.faces)-before
    if paint == 'iron':
        for face in added:
            if face.calc_center_median().z > centre[1]+size[1]*.89:
                for loop in face.loops:
                    loop[p.col] = ti.PALETTE['iron_worn']
                p.colours.add('iron_worn')
    info.update(original_triangles=original, reduced_triangles=sum(len(f.verts)-2 for f in added),
                reduction='원본 높이별 외곽 반경 표본 기반 회전체 리토폴로지', source_profile=list(zip(heights, radii)))
    p.sources.append(info)
    bpy.data.objects.remove(obj, do_unlink=True)


def tetra(p, pts, colour):
    centre = sum((Vector(v) for v in pts), Vector()) / 4
    for indices in ((0, 1, 2), (0, 3, 1), (1, 3, 2), (2, 3, 0)):
        face = [pts[i] for i in indices]
        mid = sum((Vector(v) for v in face), Vector()) / 3
        p.face(face, colour, mid-centre)


def build(p, root):
    pid = p.pid
    size = SPECS[pid][1]
    if pid == 'wall_patch':
        add_source(p, root, 'planks', size, 56, rotation=Matrix.Rotation(math.pi/2, 3, 'X'), style='planks')
    elif pid == 'tarp_patch':
        ring = [(-.24, 0, -.003), (.24, .008, -.005), (.23, .42, -.004), (-.24, .415, -.005)]
        middle = (.008, .20, .004)
        for i in range(4):
            pts = [ring[i], ring[(i+1)%4], middle]
            for sign in (1, -1):
                p.face(pts, 'cloth_blue' if i % 2 else 'wool_dark', (0, 0, sign))
        for x in (-.22, .21):
            tetra(p, [(x-.005, .399, .003), (x+.005, .399, .003), (x, .409, .003), (x, .404, .005)], 'iron')
    elif pid == 'straw_mat':
        add_source(p, root, 'mat', size, 24, style='mat')
    elif pid == 'stick_candle':
        add_source(p, root, 'candle', (.055, .21, .055), 20, centre=(0, 0, .027), style='candle')
        p.beam((-.055, .31, -.060), (.055, .31, .060), .006, 'iron', sides=4)
        p.beam((.055, .31, .060), (.0275, .19, .027), .006, 'iron', sides=4)
        tetra(p, [(-.003, .207, .027), (.003, .207, .027), (0, .207, .030), (0, .222, .027)], 'soot')
    elif pid in ('tin_stove', 'drum_stove'):
        drum = pid == 'drum_stove'
        add_radial_source(p, root, 'barrel', (.38, .46, .36), [0, .12, .50, .88, 1] if drum else [0, .50, 1],
                          8 if drum else 6, centre=(0, .08, 0))
        p.box((-.12, .12), (.14, .31), (.18, .20), 'soot')
        p.beam((.09, .53, -.08), (.09, .70, -.08), .055, 'iron', sides=6)
        p.box((-.20, -.14), (0, .095), (-.15, .15), 'iron')
        p.box((.14, .20), (0, .095), (-.15, .15), 'iron')
    elif 'bunk' in pid:
        opened = pid.startswith('open')
        lower = pid.endswith('lower')
        w, h, d = size
        base = .32 if lower else 0
        wood = 'wood_worn' if opened else 'wood_dark'
        p.box((-w/2, w/2), (base, base+.035), (-d/2, d/2), wood)
        if lower:
            for x in (-w/2+.045, w/2-.045):
                for z in (-d/2+.045, d/2-.045):
                    p.box((x-.025, x+.025), (0, base), (z-.025, z+.025), wood)
        if opened:
            for z in (-d/2+.012, d/2-.012):
                p.box((-w/2, w/2), (base+.035, h), (z-.012, z+.012), 'cloth_faded')
            for x in (-w/2+.015, w/2-.015):
                p.box((x-.015, x+.015), (base+.035, h), (-d/2+.024, d/2-.024), 'cloth_faded')
        add_source(p, root, 'bedroll', (w-.08, h-base-.04, d-.06), 44 if opened else 48,
                   centre=(0, base+.04, 0), rotation=Matrix.Rotation(math.pi/2, 3, 'Z'),
                   style='pale_bed' if opened else 'bed')
    elif pid == 'end_shelf':
        for bottom in (0, .60):
            add_source(p, root, 'top', (.48, .30, .28), 46, centre=(0, bottom, 0), paint='wood_worn')
    elif pid in ('wood_wall_box', 'wood_wall_box_shallow', 'top_shelf'):
        key = SOURCE_KEYS[pid]
        add_source(p, root, key, size, {'box': 60, 'shallow': 60, 'end': 92, 'top': 48}[key], paint='wood' if key in ('box', 'shallow') else 'wood_worn')
    elif pid == 'pale_paneling':
        for x in (-3., 3.):
            add_source(p, root, 'panel', (6., .42, .05), 40, centre=(x, 0, 0), style='panel')
    elif pid == 'stick_lamp':
        add_source(p, root, 'lamp', (.13, .09, .12), 42, centre=(0, .04, .005),
                   rotation=Matrix.Rotation(math.pi, 3, 'X'), style='lamp')
        p.beam((0, .12, 0), (0, .314, 0), .006, 'iron', sides=4)
        p.beam((0, .314, -.059), (0, .314, .059), .006, 'iron', sides=4)
        p.lathe((0, .02), [(0, .019, .019), (.04, .025, .025)], 'cloth_faded', sides=4)
    elif pid == 'small_frame':
        add_source(p, root, 'frame', size, 28, style='frame')
    elif pid in ('wall_plant', 'table_plant'):
        wall = pid == 'wall_plant'
        add_source(p, root, 'plant', (.12, .20, .105 if wall else .12), 48 if wall else 60,
                   centre=(0, 0, .0075 if wall else 0), style='plant')
        if wall:
            p.box((-.022, .022), (.025, .14), (-.06, -.053), 'iron')
    elif pid in ('tiny_cup', 'tiny_bowl', 'tiny_plate', 'tiny_tray'):
        add_source(p, root, SOURCE_KEYS[pid], size, 48 if pid in ('tiny_cup', 'tiny_teapot') else 44, style='ceramic')
    elif pid in ('tiny_bottle', 'tiny_can', 'tiny_jar'):
        add_radial_source(p, root, SOURCE_KEYS[pid], size, [0, .60, .82, 1] if pid == 'tiny_bottle' else [0, .5, 1],
                          8 if pid == 'tiny_can' else 6, opened=pid == 'tiny_jar',
                          paint='glass_dark' if pid == 'tiny_bottle' else 'iron' if pid == 'tiny_can' else 'slate_faded')
    elif pid == 'tiny_teapot':
        p.lathe((0, 0), [(0, .035, .045), (.08, .042, .05)], 'slate_faded', sides=6)
        p.beam((.028, .04, 0), (.075, .082, 0), .012, 'slate_faded', sides=3)
        outer = [(-.032, .017, 0), (-.065, .024, 0), (-.065, .070, 0), (-.032, .078, 0)]
        inner = [(-.038, .028, 0), (-.054, .032, 0), (-.054, .060, 0), (-.038, .067, 0)]
        for i in range(4):
            pts = [outer[i], outer[(i+1)%4], inner[(i+1)%4], inner[i]]
            for sign in (-1, 1):
                p.face(pts, 'iron_worn', (0, 0, sign))
        tetra(p, [(-.012, .08, -.01), (.012, .08, -.01), (0, .08, .012), (0, .11, 0)], 'iron_worn')
    elif pid == 'thread_spool':
        p.lathe((0, 0), [(0, .025, .025), (.012, .017, .017), (.058, .017, .017), (.07, .025, .025)], 'cloth_blue', sides=6, alternate='wool')
    elif pid == 'tiny_brush':
        p.box((-.02, .02), (.008, .02), (-.07, -.015), 'wood')
        p.box((-.006, .006), (.009, .017), (-.02, .07), 'wood_worn')
        p.box((-.018, .018), (0, .008), (-.066, -.02), 'wool_dark')
    elif pid == 'tiny_clock':
        outline = [(-.045, 0), (.045, 0), (.045, .085), (.028, .11), (-.028, .11), (-.045, .085)]
        for z, sign in ((-.02, -1), (.017, 1)):
            p.face([(x, y, z) for x, y in outline], 'iron', (0, 0, sign))
        for i in range(6):
            x0, y0 = outline[i]
            x1, y1 = outline[(i+1)%6]
            p.face([(x0, y0, -.02), (x1, y1, -.02), (x1, y1, .017), (x0, y0, .017)], 'iron', (y1-y0, x0-x1, 0))
        p.face([(-.031, .022, .018), (.031, .022, .018), (.031, .084, .018), (-.031, .084, .018)], 'slate_faded', (0, 0, 1))
        p.face([(-.002, .052, .019), (.002, .052, .019), (.002, .077, .019), (-.002, .077, .019)], 'cloth_faded', (0, 0, 1))
        p.face([(-.002, .050, .02), (.021, .050, .02), (.021, .054, .02), (-.002, .054, .02)], 'cloth_faded', (0, 0, 1))
    elif pid == 'tiny_book':
        rotation = Matrix(((0, 1, 0), (0, 0, 1), (1, 0, 0)))
        add_source(p, root, 'book', size, 44, rotation=rotation, style='book')
    else:
        raise ValueError('F-INPUT-MISSING: 빌더 ' + pid)


def read_glb(path):
    data = path.read_bytes()
    if struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise ValueError('F-GLB: 머리')
    length, kind = struct.unpack_from('<II', data, 12)
    if kind != 0x4e4f534a:
        raise ValueError('F-GLB: JSON chunk')
    book = json.loads(data[20:20+length])
    off = 20+length
    blen, bkind = struct.unpack_from('<II', data, off)
    if bkind != 0x004e4942:
        raise ValueError('F-GLB: BIN chunk')
    return book, data[off+8:off+8+blen]


def accessor(book, data, number):
    acc = book['accessors'][number]
    view = book['bufferViews'][acc['bufferView']]
    fmt, width = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}[acc['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']]
    step = view.get('byteStride', n*width)
    off = view.get('byteOffset', 0)+acc.get('byteOffset', 0)
    rows = [struct.unpack_from('<'+fmt*n, data, off+i*step) for i in range(acc['count'])]
    if acc.get('normalized'):
        den = {5121: 255., 5123: 65535.}[acc['componentType']]
        rows = [tuple(v/den for v in row) for row in rows]
    return rows


def check_floor_glb(path, pid, tris, colours):
    book, binary = read_glb(path)
    if len(book.get('meshes', [])) != 1 or sum('mesh' in n for n in book['nodes']) != 1:
        raise ValueError('F-GLB: 단일 메시')
    if len(book['meshes'][0]['primitives']) != 1:
        raise ValueError('F-GLB: 단일 surface')
    prim = book['meshes'][0]['primitives'][0]
    if any(book.get(k) for k in ('materials', 'images', 'textures', 'skins', 'animations', 'cameras')) or 'material' in prim:
        raise ValueError('F-GLB: 불필요한 자원')
    if any('uri' in b for b in book['buffers']) or book.get('extensions', {}).get('KHR_lights_punctual'):
        raise ValueError('F-GLB: 외부 자원·빛')
    if prim.get('mode', 4) != 4 or set(prim['attributes']) != {'POSITION', 'NORMAL', 'COLOR_0'}:
        raise ValueError('F-GLB: 삼각형·법선·색 전용')
    coords = accessor(book, binary, prim['attributes']['POSITION'])
    normals = accessor(book, binary, prim['attributes']['NORMAL'])
    rgba = accessor(book, binary, prim['attributes']['COLOR_0'])
    ids = [v[0] for v in accessor(book, binary, prim['indices'])]
    if len(ids) != tris*3 or not 0 < tris <= SPECS[pid][2]:
        raise ValueError('F-BUDGET: 실제 삼각형')
    if len(coords) != len(rgba) or len(coords) != len(normals):
        raise ValueError('F-GLB: 속성 길이')
    bounds = [[fn(v[i] for v in coords) for i in range(3)] for fn in (min, max)]
    size = SPECS[pid][1]
    expected = [(-size[0]/2, 0, -size[2]/2), (size[0]/2, size[1], size[2]/2)]
    if any(abs(bounds[j][i]-expected[j][i]) > 1e-5 for j in range(2) for i in range(3)):
        raise ValueError('F-GEOMETRY: 바닥 원점·실제 경계 ' + str(bounds))
    palette = [ti.PALETTE[k] for k in colours]
    if any(not all(math.isfinite(v) for v in row) or not any(max(abs(a-b) for a, b in zip(row, c)) < .004 for c in palette) for row in rgba):
        raise ValueError('F-COLOUR: 선형 팔레트/불투명 알파')
    for i in range(0, len(ids), 3):
        a, b, c = [Vector(coords[k]) for k in ids[i:i+3]]
        normal = (b-a).cross(c-a)
        if normal.length < 1e-11:
            raise ValueError('F-GEOMETRY: 퇴화 면')
        if any(normal.normalized().dot(Vector(normals[k])) < .95 for k in ids[i:i+3]):
            raise ValueError('F-GEOMETRY: 면 감김과 내보낸 법선 불일치')
    if any(abs(Vector(n).length-1) > .002 for n in normals):
        raise ValueError('F-GEOMETRY: 법선')
    for node in book['nodes']:
        if 'mesh' in node and any(k in node for k in ('matrix', 'rotation', 'scale', 'translation')):
            raise ValueError('F-GEOMETRY: 숨은 노드 변환')
    return len(path.read_bytes()), sha(path), [[round(v, 6)+0.0 for v in row] for row in bounds]


def source_text(row):
    if not row['sources']:
        return '기본 도형 (' + SCRIPT + ')'
    return '; '.join('%s / %s (%s)' % (s['pack'], s['file'], s['license']) for s in row['sources'])


def make_row(p, path, centred_digest):
    tris = len(p.bm.faces)
    count, digest, bounds = check_floor_glb(path, p.pid, tris, p.colours)
    size = [round(bounds[1][i]-bounds[0][i], 6) for i in range(3)]
    row = {'id': p.pid, 'status': 'ready', 'path': 'res://models/train_interior/'+p.pid+'.glb',
           'reference_size_m': list(SPECS[p.pid][1]), 'origin': 'floor_center',
           'triangle_limit': SPECS[p.pid][2], 'uses': 1, 'size_variants': [{'size_m': size, 'uses': 1}],
           'source_materials': {}, 'dimensions_m': size, 'bounds_m': bounds, 'use': SPECS[p.pid][3],
           'lod0_tris': tris, 'colours': sorted(p.colours), 'bytes': count, 'sha256': digest,
           'sources': p.sources, 'tier': SPECS[p.pid][0], 'generator': SCRIPT,
           'palette_extra': {k: list(ti.PALETTE[k][:3]) for k in p.colours if k in dress.EXTRA or k in layers.EXTRA},
           'source_search': SEARCH_NOTES.get(p.pid, 'CC0 names.txt에서 의미가 맞는 후보를 먼저 선택; CC BY 불필요.'),
           'verification': {'centred_check_glb_sha256': centred_digest, 'floor_binary_check': 'passed',
                            'godot': 'not_run: 발주 세션 담당'}}
    row['source_asset'] = source_text(row)
    if p.pid in WALL_IDS:
        row['wall_back'] = '-Z; back plane z = -depth / 2, floor/footprint centre origin'
    credits = [s['credit'] for s in p.sources if 'credit' in s]
    if credits:
        row['credit'] = '; '.join(credits)
    return row


def update_books(out_dir, rows):
    catalog = out_dir / 'catalog.json'
    book = json.loads(catalog.read_text(encoding='utf-8-sig'))
    for row in rows:
        if row['id'] in book['assets']:
            raise ValueError('F-EXISTS: 장부 기존 id ' + row['id'])
    for row in rows:
        book['assets'][row['id']] = {k: v for k, v in row.items() if k != 'id'}
    total = sum(r['lod0_tris'] for r in book['assets'].values() if r.get('status') == 'ready')
    if total > KIT_LIMIT:
        raise ValueError('F-BUDGET: 실내 키트 전체 상한')
    book['total_triangles'] = total
    book['total_triangle_limit'] = KIT_LIMIT
    book['tiers'] = {'script': SCRIPT, 'new_triangle_limit': LIMIT, 'base_triangles': BASE_TRIS,
                     'origin': 'floor_center', 'placement': '새 31종은 바닥 원점. 기존 자산은 개별 origin 유지.',
                     'source_priority': 'CC0 -> CC BY 4.0 -> 기본 도형'}
    write_json(catalog, book)
    path = out_dir / 'README.md'
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'^# 열차 실내 가구 \d+종', '# 열차 실내 가구 %d종' % len(book['assets']), text)
    text = text.replace('개별 상한 600, 전체 상한 8,000. 전체 삼각형: 4284.',
                        '기존 개별 상한 600, 새 살림 모형은 각 장부의 상한 적용. 전체 상한 10,000. 전체 삼각형: %d.' % total)
    text = re.sub(r'전체 삼각형: \d+\.', '전체 삼각형: %d.' % total, text)
    text += '\n\n## 살림 단계 31종\n\n'
    text += '`tools/blender/train_car_tiers.py`로 생성. 새 모형은 발자국 중앙·바닥 원점(최저 Y=0), +Y 위·+Z 앞. 벽걸이 등은 -Z. 기존 행의 원점은 유지한다.\n'
    text += '색은 기존 train_car_dress/layers의 선형 색 판. 원본 재질·질감·얼굴·글자는 내보내지 않는다. 창 아래 판·천은 높이 0.42 m.\n\n'
    text += '| 이름 | 원본 | 크기 | 삼각형 | 색 | sha256 |\n|---|---|---|---:|---|---|\n'
    for row in rows:
        text += '| %s | %s | %s | %d | %s | %s |\n' % (row['id'], row['source_asset'], ti.dimensions(row['dimensions_m']), row['lod0_tris'], ', '.join(row['colours']), row['sha256'])
    for row in rows:
        if 'credit' in row:
            text += '\n크레딧 `%s`: %s. 원본: %s ; 라이선스: %s\n' % (row['id'], row['credit'], CC_BY_URL, LICENSE_URL)
    new_total = sum(r['lod0_tris'] for r in book['assets'].values() if r.get('generator') == SCRIPT)
    text += '\n새 살림 단계 합계: %d / 2,430. 전체 삼각형: %d / 10,000.\n' % (new_total, total)
    path.write_text(text, encoding='utf-8')


def render_sheet(stage, rows, out):
    """최종 GLB를 재가져온 31종 확인용 그림. 렌더 재질은 GLB에 저장하지 않는다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = bpy.data.materials.new('preview_linear_Col_only')
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    attr = nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Col'
    shader = nodes.new('ShaderNodeBsdfPrincipled')
    shader.inputs['Roughness'].default_value = .85
    output = nodes.new('ShaderNodeOutputMaterial')
    mat.node_tree.links.new(attr.outputs['Color'], shader.inputs['Base Color'])
    mat.node_tree.links.new(shader.outputs['BSDF'], output.inputs['Surface'])
    label_mat = bpy.data.materials.new('preview_label_dark')
    label_mat.use_nodes = True
    label_mat.node_tree.nodes.clear()
    label_shader = label_mat.node_tree.nodes.new('ShaderNodeEmission')
    label_shader.inputs['Color'].default_value = (.025, .025, .025, 1)
    label_out = label_mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
    label_mat.node_tree.links.new(label_shader.outputs[0], label_out.inputs[0])
    # 각 칸은 같은 화면 크기로 정규화한다. 실제 치수는 장부에 기록한다.
    for index, row in enumerate(rows):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(stage / (row['id']+'.glb')))
        obs = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']
        col, line = index % 5, index // 5
        for obj in obs:
            obj.data.color_attributes[0].name = 'Col'
            obj.data.materials.clear()
            obj.data.materials.append(mat)
            if hasattr(obj, 'visible_shadow'):
                obj.visible_shadow = False  # 이웃 칸 모형의 그림자가 덮이지 않도록 확인 그림에서만 끈다.
            # 확인 그림에만 비스듬한 시점을 적용한다.
            scale = 1.45 / max(row['dimensions_m'])
            rot = Matrix.Rotation(math.radians(25), 4, 'X') @ Matrix.Rotation(math.radians(-25), 4, 'Z')
            obj.data.transform(rot @ Matrix.Scale(scale, 4))
            vs = [v.co for v in obj.data.vertices]
            xmin, xmax = min(v.x for v in vs), max(v.x for v in vs)
            zmin, zmax = min(v.z for v in vs), max(v.z for v in vs)
            obj.location = (col*2.2-(xmin+xmax)/2, 0, -line*2.05+.32-(zmin+zmax)/2)
        curve = bpy.data.curves.new(row['id']+'_label', 'FONT')
        curve.body = '%02d %s\n%d tris' % (index+1, row['id'], row['lod0_tris'])
        curve.size = .115
        curve.materials.append(label_mat)
        label = bpy.data.objects.new('label', curve)
        bpy.context.scene.collection.objects.link(label)
        label.rotation_euler = (math.pi/2, 0, 0)
        label.location = (col*2.2-.92, -.9, -line*2.05-.66)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 8
    scene.cycles.use_denoising = True
    scene.world = bpy.data.worlds.new('preview_world')
    scene.world.use_nodes = True
    world_nodes = scene.world.node_tree.nodes
    world_nodes.clear()
    ambient = world_nodes.new('ShaderNodeBackground')
    ambient.inputs['Color'].default_value = (.18, .18, .18, 1)
    backdrop = world_nodes.new('ShaderNodeBackground')
    backdrop.inputs['Color'].default_value = (.92, .92, .92, 1)
    ray = world_nodes.new('ShaderNodeLightPath')
    mix = world_nodes.new('ShaderNodeMixShader')
    world_out = world_nodes.new('ShaderNodeOutputWorld')
    scene.world.node_tree.links.new(ray.outputs['Is Camera Ray'], mix.inputs[0])
    scene.world.node_tree.links.new(ambient.outputs[0], mix.inputs[1])
    scene.world.node_tree.links.new(backdrop.outputs[0], mix.inputs[2])
    scene.world.node_tree.links.new(mix.outputs[0], world_out.inputs[0])
    for location, energy, size in (((2, -6, 6), 500, 8), ((8, -3, -7), 280, 7)):
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = 'DISK'
        light.data.size = size
        target = Vector((4, 0, -5))
        light.rotation_euler = (target-light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add(location=(4.4, -24, -6.0))
    camera = bpy.context.object
    camera.rotation_euler = (math.pi/2, 0, 0)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 15.8
    scene.camera = camera
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'Standard'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', required=True)
    parser.add_argument('--src-open', default=str(DEFAULT_OPEN))
    parser.add_argument('--only', default='')
    parser.add_argument('--stage-only', action='store_true')
    parser.add_argument('--render-contact-sheet', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    repo = Path(args.repo).resolve()
    out = repo / 's2/models/train_interior'
    evidence = repo / 'codex_out'
    stage = evidence / 'tiers_stage'
    stage.mkdir(parents=True, exist_ok=True)
    selected = args.only.split(',') if args.only else list(SPECS)
    if len(selected) != len(set(selected)) or any(pid not in SPECS for pid in selected):
        raise SystemExit('F-INPUT-MISSING: --only 중복/알 수 없는 이름')
    rows, failures = [], []
    base = json.loads((out / 'catalog.json').read_text(encoding='utf-8-sig'))
    old_hashes = {p.name: sha(p) for p in out.glob('*.glb')}
    for pid in selected:
        piece = None
        try:
            if not args.stage_only and ((out/(pid+'.glb')).exists() or pid in base['assets']):
                raise ValueError('F-EXISTS: 기존 GLB/장부를 덮어쓰지 않음 ' + pid)
            piece = ti.Piece(pid)
            piece.sources = []
            build(piece, Path(args.src_open).resolve())
            piece.fit(SPECS[pid][1])
            tris = len(piece.bm.faces)
            if tris > SPECS[pid][2]:
                raise ValueError('F-BUDGET: %s %d > %d' % (pid, tris, SPECS[pid][2]))
            path = stage / (pid+'.glb')
            ti.export(piece, path)
            _, centred_digest, _ = ti.check_glb(path, tris, SPECS[pid][1])
            for vertex in piece.bm.verts:
                vertex.co.z += SPECS[pid][1][1]/2
            ti.export(piece, path)
            row = make_row(piece, path, centred_digest)
            rows.append(row)
            print('TIERS_OK %s tris=%d size=%s sha256=%s' % (pid, tris, ti.dimensions(row['dimensions_m']), row['sha256']), flush=True)
        except Exception as exc:
            message = str(exc)
            code = next((s for s in ('F-INPUT-MISSING', 'F-EXISTS', 'F-BUDGET', 'F-GEOMETRY', 'F-COLOUR', 'F-GLB') if s in message), 'F-BUILD')
            failures.append({'id': pid, 'failure_code': code, 'observation': message})
            print('TIERS_FAIL', pid, code, message, flush=True)
            traceback.print_exc()
        finally:
            if piece is not None:
                piece.bm.free()
        write_json(evidence / 'tiers_build_receipt.json', {'stage_only': args.stage_only, 'rows': rows, 'failures': failures,
                    'blender': bpy.app.version_string, 'argv': sys.argv, 'total_new_triangles': sum(r['lod0_tris'] for r in rows)})
    total = sum(r['lod0_tris'] for r in rows)
    existing_new = sum(r['lod0_tris'] for r in base['assets'].values() if r.get('generator') == SCRIPT)
    if total+existing_new > LIMIT:
        failures.append({'id': 'total', 'failure_code': 'F-BUDGET', 'observation': str(total+existing_new)})
    if sum(r['lod0_tris'] for r in base['assets'].values()) + total > KIT_LIMIT:
        failures.append({'id': 'kit', 'failure_code': 'F-BUDGET', 'observation': '전체 10,000 초과'})
    installed = []
    if not args.stage_only and not any(f['id'] in ('total', 'kit') for f in failures):
        for row in rows:
            target = out / (row['id']+'.glb')
            with target.open('xb') as stream:
                stream.write((stage / target.name).read_bytes())
            installed.append(row['id'])
        update_books(out, rows)
    for name, digest in old_hashes.items():
        if sha(out/name) != digest:
            failures.append({'id': name, 'failure_code': 'F-PRESERVATION', 'observation': '기존 GLB 해시 변경'})
    write_json(evidence / 'tiers_build_receipt.json', {'stage_only': args.stage_only, 'rows': rows, 'failures': failures,
                'blender': bpy.app.version_string, 'argv': sys.argv, 'total_new_triangles': total,
                'installed': installed, 'old_glb_hashes_preserved': not any(f['failure_code'] == 'F-PRESERVATION' for f in failures)})
    if args.render_contact_sheet and rows:
        render_sheet(stage, rows, evidence / 'tiers_contact_sheet.png')
    print('TIERS_COMPLETE ready=%d/%d triangles=%d/%d installed=%d failures=%d' % (len(rows), len(selected), total, LIMIT, len(installed), len(failures)), flush=True)
    if failures:
        # Blender는 Python 예외에도 0을 반환할 수 있으므로 호출에 --python-exit-code 1 사용 권장.
        raise RuntimeError('F-BUILD: 위 failures 참조')


if __name__ == '__main__':
    main()
