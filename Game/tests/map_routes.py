"""Player footprint and nearest-E checks shared by map asset acceptance tests."""
from collections import deque


def can_stand(data, px, py, extra=()):
    blockers = data.get('blockers', []) + [p['collision'] for p in data['props'] + data['actors'] + list(extra) if 'collision' in p]
    return (24 <= px-9 and px+9 <= data['width']*48-24 and 24 <= py-11 and py+1 <= data['height']*48-24
            and not any(px+9>x and px-9<x+w and py+1>y and py-11<y+h for x, y, w, h in blockers))


def reachable(data, extra=()):
    start = tuple(round(n/12) for n in data['spawn'])
    visited, queue = {start}, deque([start])
    while queue:
        x, y = queue.popleft()
        for point in [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]:
            if point not in visited and can_stand(data, point[0]*12, point[1]*12, extra):
                visited.add(point); queue.append(point)
    return visited


def interaction_reachable(data, actor, visited, actors=None):
    anchor = actor.get('interactionPosition', actor['position'])
    others = [p.get('interactionPosition', p['position']) for p in (data['actors'] if actors is None else actors)
              if p.get('id') != actor.get('id')]
    for x, y in visited:
        distance = (x*12-anchor[0])**2 + (y*12-anchor[1])**2
        if distance < 86**2 and all(distance < (x*12-a[0])**2 + (y*12-a[1])**2 for a in others): return True
    return False
