"""Highlight-free facial shapes, separate from the painted puppet parts."""
from rig_writer import Rig, n
INK = 'FF624C52'

class FaceRig(Rig):
    def expressions(self, head):
        spec=self.spec
        cx=sum(e[0] for e in spec['eyes'])/len(spec['eyes'])
        cy=sum(e[1] for e in spec['eyes'])/len(spec['eyes'])
        hx,hy=spec['head']
        face=self.group(head,'Face',cx-hx,cy-hy)
        joy=self.group(face,'Joy face',opacity=0)
        sleep=self.group(face,'Sleep face',opacity=0)
        eyes=self.group(face,'Eyes')
        wander=self.group(eyes,'Wander gaze')
        def look(parent,name):
            group=self.group(parent,name)
            n(group,'DataBindContext',sourcePathIds='0:40-0:46',propertyKey=13)
            return group
        neutral_look=look(wander,'Look direction')
        joy_look=look(joy,'Joy gaze')
        sleep_look=look(sleep,'Sleep gaze')
        for i,(ex,ey,w,h) in enumerate(spec['eyes']):
            x,y=ex-cx,ey-cy
            self.ellipse(neutral_look,f'Eye {i}',x,y,w,h,INK)
            self.path(joy_look,f'Joy eye {i}',(x-w*.43,y+1),[
                ((x-w*.25,y-h*.38),(x+w*.25,y-h*.38),(x+w*.43,y+1)),
            ],stroke=INK,closed=False,width=3.4)
            self.path(sleep_look,f'Sleep eye {i}',(x-w*.43,y),[
                ((x-w*.18,y+4),(x+w*.18,y+4),(x+w*.43,y)),
            ],stroke=INK,closed=False,width=2.8)
        smile=self.group(face,'Smile')
        if spec['kind']=='cooperation':
            return
        mx,my,mouth_style=spec['mouth']
        mx,my=mx-cx,my-cy
        self.path(joy,'Joy mouth',(mx-7,my-3),[
            ((mx-5,my+10),(mx+5,my+10),(mx+7,my-3)),
            ((mx+3,my-1),(mx-3,my-1),(mx-7,my-3)),
        ],INK)
        self.ellipse(sleep,'Sleep mouth',mx,my,4,3,INK)
        if mouth_style in ('cat','sheep'):
            if mouth_style=='sheep':
                self.path(smile,'Sheep nose',(mx-5,my-12),[
                    ((mx-5,my-17),(mx+5,my-17),(mx+5,my-12)),
                    ((mx+2,my-8),(mx-2,my-8),(mx-5,my-12)),
                ],'FFAD8073')
            self.path(smile,'Mouth stem',(mx,my-8),[
                ((mx,my-5),(mx,my-3),(mx,my-2)),
            ],stroke=INK,closed=False,width=2.3)
            self.path(smile,'Small W smile',(mx-8,my),[
                ((mx-4,my+4),(mx,my+1),(mx,my-3)),
                ((mx,my+1),(mx+4,my+4),(mx+8,my)),
            ],stroke=INK,closed=False,width=2.5)
        else:
            self.path(smile,'Smile curve',(mx-6,my-2),[
                ((mx-3,my+3),(mx+3,my+3),(mx+6,my-2)),
            ],stroke=INK,closed=False,width=2.8)
