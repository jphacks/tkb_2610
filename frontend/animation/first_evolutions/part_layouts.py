"""Rest positions in the shared 500px character canvas; front-to-back order."""
# name, asset, bounds, joint, parent; optional rotation amplitude and phase.
LAYOUTS = {
'kindness': [
 ('Cap','jelly_cap',(40,74,458,337),(245,310),'Head'),
 ('Tentacle far left','jelly_far_left',(40,309,207,478),(180,315),'Head',.11,0),
 ('Tentacle inner left','jelly_inner_left',(141,310,234,482),(216,318),'Head',.11,1.2),
 ('Tentacle inner right','jelly_inner_right',(236,310,337,482),(262,318),'Head',.11,3.6),
 ('Tentacle far right','jelly_far_right',(285,309,456,472),(310,315),'Head',.11,4.8),
 ('Tentacle centre','jelly_centre',(215,311,290,477),(247,319),'Head',.11,2.4),
],
'environment': [
 ('Head paint','deer_head',(91,153,270,327),(221,299),'Head'),
 ('Ear near','deer_near_ear',(225,139,355,240),(259,222),'Head',.035,0),
 ('Ear far','deer_far_ear',(100,123,180,218),(160,207),'Head',.035,2),
 ('Antler near','deer_near_antler',(217,89,296,192),(235,182),'Head',.018,1),
 ('Antler far','deer_far_antler',(164,75,214,182),(185,174),'Head',.018,3),
 ('Torso','deer_body',(165,285,379,433),(270,350),'Artwork'),
 ('Leaf tail','deer_tail',(340,250,411,352),(351,334),'Artwork',.07,1),
],
'gratitude': [
 ('Head paint','sheep_head',(91,101,298,343),(204,329),'Head'),
 ('Horn near','sheep_near_horn',(273,164,371,260),(302,211),'Head',.018,1),
 ('Horn far','sheep_far_horn',(77,145,133,215),(111,184),'Head',.018,2),
 ('Ear near','sheep_near_ear',(292,260,390,328),(309,277),'Head',.07,0),
 ('Ear far','sheep_far_ear',(40,248,113,288),(106,264),'Head',.05,2),
 ('Torso','sheep_body',(112,246,459,449),(285,350),'Artwork'),
],
'courage': [
 ('Head paint','lion_head',(78,199,299,348),(205,362),'Head'),
 ('Ear near','lion_near_ear',(233,188,304,268),(259,253),'Head',.04,0),
 ('Ear far','lion_far_ear',(68,190,132,266),(110,251),'Head',.04,2),
 ('Mane','lion_mane',(40,80,383,417),(205,303),'Head',.014,1),
 ('Torso','lion_body',(175,323,411,443),(290,380),'Artwork'),
 ('Tail','lion_tail',(348,249,444,393),(365,362),'Artwork',.065,1),
 ('Tail flame','lion_flame',(374,183,461,300),(429,256),'Tail',.09,2),
],
'cooperation': [
 ('Fin near','whale_near_fin',(236,377,367,482),(238,388),'Head',.14,.8),
 ('Torso','whale_body',(40,218,398,473),(192,343),'Head'),
 ('Fin far','whale_far_fin',(57,410,157,474),(100,444),'Head',.09,2),
 ('Tail stem','whale_tail_stem',(336,285,403,409),(359,368),'Head',.10,1),
 ('Tail flukes','whale_flukes',(309,207,460,323),(382,315),'Tail stem',.12,2.1),
],
'honesty': [
 ('Head paint','turtle_head',(41,240,229,407),(196,373),'Head'),
 ('Crystal','turtle_crystal',(229,130,325,235),(255,215),'Artwork',.008,1),
 ('Shell','turtle_shell',(140,203,463,451),(300,350),'Artwork'),
 ('Torso','turtle_body',(112,381,438,462),(270,420),'Artwork'),
 ('Tail','turtle_tail',(435,382,473,428),(444,401),'Artwork',.025,1),
],
'self_care': [
 ('Head paint','cat_head',(81,128,339,341),(211,327),'Head'),
 ('Ear left','cat_right_ear',(82,70,179,208),(128,166),'Head',.055,0),
 ('Ear right','cat_left_ear',(265,78,375,210),(291,165),'Head',.055,2),
 ('Seated torso','cat_seated_body',(177,318,337,480),(250,400),'Seated pose'),
 ('Paw left','cat_seated_left_leg',(167,367,221,480),(196,376),'Seated pose'),
 ('Paw right','cat_seated_right_leg',(213,367,266,480),(241,376),'Seated pose'),
 ('Paw near back','cat_near_hind_paw',(274,435,327,480),(299,449),'Seated pose'),
 ('Paw far back','cat_far_hind_paw',(169,423,222,480),(195,441),'Seated pose'),
 ('Standing torso','cat_walk_body',(170,304,384,431),(275,360),'Standing pose'),
 ('Tail','cat_tail',(302,247,443,467),(325,432),'Artwork',.07,1),
],
}

LEGS = {
'environment': ('deer', [((200,376,258,480),(241,379)),((159,376,218,472),(205,380)),((343,379,388,475),(357,389)),((274,377,326,470),(306,390))]),
'gratitude': ('sheep', [((201,395,253,480),(233,413)),((143,395,195,472),(176,410)),((340,401,397,480),(365,416)),((278,402,327,468),(310,417))]),
'courage': ('lion', [((173,382,252,480),(204,410)),((125,366,191,472),(164,390)),((348,386,419,477),(370,418)),((265,398,317,465),(300,413))]),
'honesty': ('turtle', [((206,375,276,480),(240,408)),((62,373,141,472),(117,398)),((375,386,441,474),(394,414)),((294,413,340,472),(320,425))]),
'self_care': ('cat_walk', [((194,372,246,480),(218,391)),((160,377,204,473),(183,395)),((335,371,402,480),(367,391)),((285,378,330,474),(306,398))]),
}
