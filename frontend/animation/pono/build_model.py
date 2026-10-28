"""Author Pono's native vector rig. Run with Python 3, then `rive . --verify`.

Coordinates follow the approved flat-colour Pono concept. No raster tracing,
scripts, external images, or hosted Rive account are needed at runtime.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as X


root = X.Element('Rive', version='1', kind='fragment')
counter = 100
ids = {}


def node(parent, tag, name=None, **attrs):
    global counter
    if name:
        attrs['name'] = name
        attrs.setdefault('id', f'0:{counter}')
        ids[name] = attrs['id']
        counter += 1
    return X.SubElement(parent, tag, {k: str(v) for k, v in attrs.items()})


art = node(root, 'Artboard', 'Pono', width=500, height=500,
           defaultStateMachineId='0:7', viewModelId='0:40',
           viewModelInstanceId='0:41', styleId='0:5')
node(art, 'LayoutComponentStyle', id='0:5', name='Pono artboard style')


def paint(shape, fill=None, stroke=None, thickness=2.8):
    # Rive draws the first declared paint on top.
    if stroke:
        node(node(shape, 'Stroke', thickness=thickness, cap='round', join='round'),
             'SolidColor', colorValue=stroke)
    if fill:
        node(node(shape, 'Fill'), 'SolidColor', colorValue=fill)


def ellipse(parent, name, x, y, w, h, fill, stroke=None, **attrs):
    shape = node(parent, 'Shape', name, x=x, y=y, **attrs)
    node(shape, 'Ellipse', width=w, height=h)
    paint(shape, fill, stroke)
    return shape


def path(parent, name, start, segments, fill=None, stroke=None, closed=True,
         thickness=2.8, **attrs):
    """Cubic segments are (control1, control2, end), in local coordinates."""
    shape = node(parent, 'Shape', name, **attrs)
    p = node(shape, 'PointsPath', isClosed=str(closed).lower())
    points = [start] + [s[2] for s in segments]
    incoming = [None] + [s[1] for s in segments]
    outgoing = [s[0] for s in segments] + [None]
    if closed and points[-1] == points[0]:
        incoming[0] = incoming.pop()
        points.pop()
        outgoing.pop()
    for i, (x, y) in enumerate(points):
        def handle(pt):
            if pt is None:
                return 0, 0
            dx, dy = pt[0] - x, pt[1] - y
            return math.atan2(dy, dx), math.hypot(dx, dy)
        ri, di = handle(incoming[i])
        ro, do = handle(outgoing[i])
        node(p, 'CubicDetachedVertex', f'{name} v{i}', x=x, y=y,
             inRotation=ri, inDistance=di, outRotation=ro, outDistance=do)
    paint(shape, fill, stroke, thickness)
    return shape


cream, ink, outline = 'FFFFF9EF', 'FF493952', 'FF9988A4'
# Front-to-back order. Each group is independently keyed in the timelines.
orb = node(art, 'Node', 'Orb', x=390, y=157)
ellipse(orb, 'Orb shine', -9, -11, 13, 13, 'FFFFFFFF')
ellipse(orb, 'Orb cream', -1, -2, 57, 57, cream)
ellipse(orb, 'Orb outline', 0, 0, 64, 64, 'FFE7DFEF', outline)

body = node(art, 'Node', 'Body', x=250, y=440)
direction = node(body, 'Node', 'Look direction')
node(direction, 'DataBindContext', sourcePathIds='0:40-0:46', propertyKey=13)
face = node(direction, 'Node', 'Face', x=0, y=-155)
# Happy eyes and mouth are separate from the resting face.
joy = node(face, 'Node', 'Joy face', opacity=0)
for x, side in [(-49, 'L'), (49, 'R')]:
    path(joy, f'Joy eye {side}', (x-8, -3),
         [((x-5, -15), (x+5, -15), (x+8, -3))],
         stroke=ink, closed=False, thickness=4)
path(joy, 'Joy mouth', (-11, 14),
     [((-8, 32), (8, 32), (11, 14)), ((5, 17), (-5, 17), (-11, 14))],
     fill=ink)
ellipse(joy, 'Joy cheek L', -70, 15, 33, 23, 'FFFFC9D5')
ellipse(joy, 'Joy cheek R', 70, 15, 33, 23, 'FFFFC9D5')

sleep = node(face, 'Node', 'Sleep face', opacity=0)
for x, side in [(-49, 'L'), (49, 'R')]:
    path(sleep, f'Sleep eye {side}', (x-8, -3),
         [((x-4, 3), (x+4, 3), (x+8, -3))],
         stroke=ink, closed=False, thickness=3.5)
ellipse(sleep, 'Sleep mouth', 0, 17, 7, 5, ink)

eyes = node(face, 'Node', 'Eyes', y=-4)
ellipse(eyes, 'Eye L', -49, 0, 18, 27, ink)
ellipse(eyes, 'Eye R', 49, 0, 18, 27, ink)
mouth = node(face, 'Node', 'Smile')
path(mouth, 'Smile curve', (-9, 11),
     [((-5, 17), (5, 17), (9, 11))], stroke=ink, closed=False, thickness=3.5)
ellipse(face, 'Cheek L', -69, 18, 30, 20, 'FFFFD7DD')
ellipse(face, 'Cheek R', 69, 18, 30, 20, 'FFFFD7DD')

# Absolute artwork coordinates live inside a node whose pivot is at the feet.
artwork = node(body, 'Node', 'Artwork', x=-250, y=-440)
path(artwork, 'Bottom shade', (76, 393), [
    ((91, 410), (110, 397), (123, 382)),
    ((119, 423), (153, 440), (192, 404)),
    ((209, 443), (258, 456), (290, 410)),
    ((329, 440), (378, 429), (372, 369)),
    ((387, 401), (427, 411), (423, 376)),
    ((452, 402), (424, 425), (386, 412)),
    ((376, 446), (338, 453), (298, 426)),
    ((271, 450), (229, 458), (201, 430)),
    ((194, 421), (193, 421), (183, 429)),
    ((152, 450), (127, 434), (123, 412)),
    ((99, 425), (73, 416), (76, 393)),
], fill='FFEAE3F1')
path(artwork, 'Body contour', (250, 157), [
    ((168, 154), (127, 210), (111, 284)),
    ((100, 338), (100, 340), (78, 366)),
    ((50, 398), (79, 428), (123, 412)),
    ((127, 438), (154, 448), (183, 429)),
    ((193, 421), (194, 421), (201, 430)),
    ((230, 457), (269, 450), (298, 426)),
    ((334, 452), (376, 445), (386, 412)),
    ((425, 426), (453, 401), (429, 371)),
    ((407, 344), (400, 342), (391, 290)),
    ((379, 213), (337, 157), (250, 157)),
], fill=cream, stroke=outline)

machine = node(art, 'StateMachine', id='0:7', name='Pono motion')
layer = node(machine, 'StateMachineLayer', 'Motion layer')
node(layer, 'AnyState', x=0, y=-150)
node(layer, 'ExitState', x=220, y=-150)
entry = node(layer, 'EntryState', x=-180, y=0)
node(entry, 'StateTransition', stateToId='0:20')
names = ['Idle', 'Walk', 'Tap', 'Happy', 'Low energy', 'Sleep']
durations = [480, 72, 120, 120, 360, 300]
for i, name in enumerate(names):
    state = node(layer, 'AnimationState', id=f'0:{20+i}',
                 animationId=f'0:{50+i}', reset='true', x=i*210, y=0)
    for j in range(len(names)):
        if i == j:
            continue
        transition = node(state, 'StateTransition', stateToId=f'0:{20+j}',
                          duration=140 if j != 5 else 220)
        condition = node(transition, 'TransitionViewModelCondition', opValue='equal')
        comparator = node(condition, 'TransitionPropertyViewModelComparator')
        bind = node(comparator, 'BindablePropertyNumber')
        node(bind, 'DataBindContext', sourcePathIds='0:40-0:45', propertyKey=636)
        node(condition, 'TransitionValueNumberComparator', value=j)


def track(animation, target, prop, frames):
    keyed = node(animation, 'KeyedObject', objectId=ids[target])
    kp = node(keyed, 'KeyedProperty', propertyKey=prop)
    for frame, value in frames:
        kf = node(kp, 'KeyFrameDouble', frame=frame, value=value,
                  interpolationType='cubic')
        node(kf, 'CubicEaseInterpolator')


def wave(duration, center, amplitude, cycles=1, phase=0):
    # Sampling a sine through eased quarter-periods gives smooth velocity.
    return [(round(i*duration/(cycles*4)),
             center+amplitude*math.sin(i*math.pi/2+phase))
            for i in range(cycles*4+1)]


for i, (name, duration) in enumerate(zip(names, durations)):
    a = node(art, 'LinearAnimation', id=f'0:{50+i}', name=name,
             duration=duration, loopValue='loop')
    excited, sleeping = i in (2, 3), i == 5
    walk = i == 1
    cycles = 2 if walk or excited else (3 if i == 0 else 1)
    track(a, 'Body', 16, wave(duration, 1, .035 if walk else .018, cycles))
    track(a, 'Body', 17, wave(duration, .96 if sleeping else 1,
                            -.045 if walk else -.023, cycles))
    # Anticipation, lift, soft landing. The orb's corresponding beats are late.
    if excited:
        hops = ([(0,440),(8,446),(20,410),(35,443),(45,432),(58,440),
                 (70,444),(82,417),(98,442),(110,438),(120,440)] if i == 3 else
                [(0,440),(8,446),(20,420),(35,443),(45,437),(60,440),(120,440)])
        track(a, 'Body', 14, hops)
        track(a, 'Body', 15, [(0,0),(8,-.035),(20,.025),(40,-.02),(60,0),(120,0)])
        track(a, 'Orb', 14, [(0,157),(14,163),(28,136),(44,156),(60,151),(78,157),(120,157)])
    else:
        track(a, 'Body', 14, wave(duration, 440, -4 if walk else -1.5, cycles))
        track(a, 'Body', 15, wave(duration, 0, .035 if walk else .009, cycles))
        track(a, 'Orb', 14, wave(duration, 157, -6 if walk else -5,
                                 cycles, phase=-math.pi/2))
    track(a, 'Orb', 13, wave(duration, 390, 3, cycles, phase=-math.pi/2))
    track(a, 'Orb', 15, wave(duration, 0, .045, cycles))
    track(a, 'Joy face', 18, [(0, 1 if excited else 0)])
    track(a, 'Sleep face', 18, [(0, 1 if sleeping else 0)])
    track(a, 'Eyes', 18, [(0, 0 if excited or sleeping else 1)])
    track(a, 'Smile', 18, [(0, 0 if excited or sleeping else 1)])
    if i == 0:
        track(a, 'Eyes', 17, [(0,1),(94,1),(99,.06),(104,1),(299,1),(304,.06),(309,1),(480,1)])
        track(a, 'Face', 13, [(0,0),(160,0),(190,5),(245,5),(275,-4),(325,-4),(355,0),(480,0)])
        track(a, 'Face', 14, [(0,-155),(160,-155),(190,-158),(245,-158),(275,-155),(480,-155)])
    else:
        opening = .45 if i == 4 else 1
        track(a, 'Eyes', 17, [(0,opening),(duration-12,opening),
                             (duration-7,.06),(duration-2,opening),(duration,opening)])
        track(a, 'Face', 13, [(0, 3 if walk else 0)])
        track(a, 'Face', 14, [(0,-153 if sleeping or i == 4 else -155)])

vm = node(root, 'ViewModel', id='0:40', name='PonoState', defaultInstanceId='0:41')
node(vm, 'ViewModelPropertyNumber', id='0:45', name='mode')
node(vm, 'ViewModelPropertyNumber', id='0:46', name='lookX')
instance = node(vm, 'ViewModelInstance', id='0:41', name='Default', exports='true')
node(instance, 'ViewModelInstanceNumber', propertyValue=0, viewModelPropertyId='0:45')
node(instance, 'ViewModelInstanceNumber', propertyValue=0, viewModelPropertyId='0:46')

X.indent(root, space='  ')
Path(__file__).with_name('scene.rml').write_text(
    X.tostring(root, encoding='unicode') + '\n', encoding='utf-8')
