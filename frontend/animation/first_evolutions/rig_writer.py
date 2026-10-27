"""Shared native Rive geometry and state-machine writer; no runtime scripts."""
import math
from pathlib import Path
import xml.etree.ElementTree as X
ROOT = X.Element('Rive', version='1', kind='fragment')
NEXT = 100
INK = 'FF493D4E'
CREAM = 'FFFFF4D9'
PINK = 'FFFFCED8'

def key():
    global NEXT
    NEXT += 1
    return f'0:{NEXT}'

def n(parent, tag, name=None, **attrs):
    if name:
        attrs.update(name=name)
        attrs.setdefault('id', key())
    return X.SubElement(parent, tag, {k: str(v) for (k, v) in attrs.items()})

class Rig:

    def __init__(self, kind, index, walk_duration, floating=False):
        (self.kind, self.index, self.walk_duration) = (kind, index, walk_duration)
        self.floating = floating
        (self.ids, self.groups, self.accents, self.legs) = ({}, {}, [], [])
        (self.machine_id, self.style_id) = (key(), key())
        self.art = n(ROOT, 'Artboard', kind, width=500, height=500, x=index % 4 * 560, y=index // 4 * 560, defaultStateMachineId=self.machine_id, styleId=self.style_id, viewModelId='0:40', viewModelInstanceId='0:41')
        n(self.art, 'LayoutComponentStyle', 'Artboard style', id=self.style_id)
        self.body = self.group(self.art, 'Body', 250, 480)
        self.canvas = self.group(self.body, 'Artwork', -250, -480)

    def add(self, parent, tag, name=None, **attrs):
        obj = n(parent, tag, name, **attrs)
        if name:
            self.ids[name] = obj.attrib['id']
        return obj

    def group(self, parent, name, x=0, y=0, **attrs):
        obj = self.add(parent, 'Node', name, x=x, y=y, **attrs)
        self.groups[name] = (x, y, float(attrs.get('rotation', 0)))
        return obj

    def paint(self, shape, fill, stroke=None, width=2.6):
        if stroke:
            n(n(shape, 'Stroke', thickness=width, cap='round', join='round'), 'SolidColor', colorValue=stroke)
        if fill:
            n(n(shape, 'Fill'), 'SolidColor', colorValue=fill)

    def ellipse(self, parent, name, x, y, w, h, fill, stroke=None, **attrs):
        shape = self.add(parent, 'Shape', name, x=x, y=y, **attrs)
        n(shape, 'Ellipse', width=w, height=h)
        self.paint(shape, fill, stroke)
        return shape

    def path(self, parent, name, start, segments, fill=None, stroke=None, closed=True, width=2.6, **attrs):
        shape = self.add(parent, 'Shape', name, **attrs)
        path = n(shape, 'PointsPath', isClosed=str(closed).lower())
        pts = [start] + [seg[2] for seg in segments]
        ins = [None] + [seg[1] for seg in segments]
        outs = [seg[0] for seg in segments] + [None]
        if closed and pts[0] == pts[-1]:
            ins[0] = ins.pop()
            pts.pop()
            outs.pop()
        for (i, (x, y)) in enumerate(pts):

            def handle(pt):
                (dx, dy) = (pt[0] - x, pt[1] - y) if pt else (0, 0)
                return (math.atan2(dy, dx), math.hypot(dx, dy))
            (ri, di) = handle(ins[i])
            (ro, do) = handle(outs[i])
            n(path, 'CubicDetachedVertex', x=x, y=y, inRotation=ri, inDistance=di, outRotation=ro, outDistance=do)
        self.paint(shape, fill, stroke, width)
        return shape

    def animations(self):
        machine = n(self.art, 'StateMachine', 'Companion motion', id=self.machine_id)
        layer = n(machine, 'StateMachineLayer', 'Motion layer')
        (states, timelines) = ([key() for _ in range(6)], [key() for _ in range(6)])
        n(layer, 'AnyState', x=0, y=-150)
        n(layer, 'ExitState', x=220, y=-150)
        n(n(layer, 'EntryState', x=-180, y=0), 'StateTransition', stateToId=states[0])
        names = ['Idle', 'Walk', 'Tap', 'Happy', 'Low energy', 'Sleep']
        for i in range(6):
            state = n(layer, 'AnimationState', id=states[i], animationId=timelines[i], reset='true', x=i * 210, y=0)
            for j in range(6):
                if i == j:
                    continue
                trans = n(state, 'StateTransition', stateToId=states[j], duration=140 if j != 5 else 220)
                comp = n(n(trans, 'TransitionViewModelCondition', opValue='equal'), 'TransitionPropertyViewModelComparator')
                n(n(comp, 'BindablePropertyNumber'), 'DataBindContext', sourcePathIds='0:40-0:45', propertyKey=636)
                n(trans[-1], 'TransitionValueNumberComparator', value=j)

        def track(a, name, prop, values):
            target = n(a, 'KeyedObject', objectId=self.ids[name])
            kp = n(target, 'KeyedProperty', propertyKey=prop)
            for (frame, value) in values:
                kf = n(kp, 'KeyFrameDouble', frame=frame, value=value, interpolationType='cubic')
                n(kf, 'CubicEaseInterpolator')

        def wave(duration, center, amp, cycles=1, phase=0):
            return [(round(i * duration / (cycles * 4)), center + amp * math.sin(i * math.pi / 2 + phase)) for i in range(cycles * 4 + 1)]
        for (i, name) in enumerate(names):
            duration = [480, self.walk_duration, 120, 120, 360, 300][i]
            a = n(self.art, 'LinearAnimation', name, id=timelines[i], duration=duration, loopValue='loop')
            (walk, excited, sleepy) = (i == 1, i in (2, 3), i == 5)
            cycles = 2 if walk or excited else 3 if i == 0 else 1
            energy = 0.35 if i == 4 else 1
            track(a, 'Body', 16, wave(duration, 1, (0.022 if self.floating else 0.01) * energy, cycles))
            track(a, 'Body', 17, wave(duration, 0.97 if sleepy else 1, (-0.028 if self.floating else -0.015) * energy, cycles))
            if excited:
                hops = [(0, 480), (8, 485), (20, 453), (35, 481), (48, 475), (60, 480)]
                hops += [(70, 484), (82, 460), (98, 481), (110, 478), (120, 480)] if i == 3 else [(120, 480)]
                track(a, 'Body', 14, hops)
            else:
                amp = 6 if self.floating else [1.8, 3, 5, 3, 6, 1, 2][self.index]
                if not walk:
                    amp *= 0.55
                track(a, 'Body', 14, wave(duration, 480, -amp * energy, cycles))
            track(a, 'Body', 15, wave(duration, 0, 0.025 if walk else 0.007, cycles))
            (hx, hy, hr) = self.groups['Head']
            track(a, 'Head', 14, wave(duration, hy, 2 * energy, cycles, -0.7))
            track(a, 'Head', 15, wave(duration, hr, 0.025 if excited else 0.012, cycles, -0.5))
            for (part, amplitude, phase) in self.accents:
                base = self.groups[part][2]
                track(a, part, 15, wave(duration, base, amplitude * (2 if excited else 1 if walk else 0.4) * energy, cycles, phase))
            for (leg, phase) in self.legs:
                track(a, leg, 15, wave(duration, 0, (0.13 if walk else 0.07 if excited else 0.003) * energy, cycles, phase))
            track(a, 'Joy face', 18, [(0, 1 if excited else 0)])
            track(a, 'Sleep face', 18, [(0, 1 if sleepy else 0)])
            track(a, 'Eyes', 18, [(0, 0 if excited or sleepy else 1)])
            track(a, 'Smile', 18, [(0, 0 if excited or sleepy else 1)])
            if i == 0:
                b = 90 + self.index * 3
                track(a, 'Eyes', 17, [(0, 1), (b, 1), (b + 5, 0.05), (b + 10, 1), (b + 200, 1), (b + 205, 0.05), (b + 210, 1), (480, 1)])
            else:
                opening = 0.45 if i == 4 else 1
                track(a, 'Eyes', 17, [(0, opening), (duration - 12, opening), (duration - 7, 0.05), (duration - 2, opening), (duration, opening)])
            fx = self.groups['Face'][0]
            track(a, 'Face', 13, [(0, fx), (round(duration * 0.4), fx + 3), (round(duration * 0.7), fx - 2), (duration, fx)] if i == 0 else [(0, fx)])
