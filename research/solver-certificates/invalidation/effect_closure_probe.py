"""B2-REGION-010: effect-aware fixed-point invalidation, research-only.

Pure synchronous radius-one toy stage. The emitted signed contact ledger is a
model of observable effects, NOT native CyberSand impulse or Water physics.
Run: python3 effect_closure_probe.py (Python 3.10+, standard library only).
"""
from __future__ import annotations
from dataclasses import dataclass
import json
import random

EMPTY, SAND, WATER, ROCK, WOOD, FIRE, ASH, STEAM = range(8)


@dataclass
class World:
    w: int
    h: int
    cells: list[int]
    body: frozenset[int] = frozenset()
    pressure: int = 0
    tick: int = 0

    def clone(self):
        return World(self.w, self.h, self.cells.copy(), self.body,
                     self.pressure, self.tick)

    def index(self, x, y):
        if not (0 <= x < self.w and 0 <= y < self.h):
            raise ValueError("out of bounds")
        return y * self.w + x


def sample(s, i, phase):
    """Return (next material, signed external effect); never mutate input."""
    x, y, c = i % s.w, i // s.w, s.cells[i]
    if c == WATER and y + 1 < s.h and s.index(x, y+1) in s.body:
        return c, 2 if phase == 0 else -3  # stationary but side-effectful
    if c == WOOD:
        if any(0 <= x+dx < s.w and 0 <= y+dy < s.h and
               s.cells[(y+dy)*s.w+x+dx] == FIRE
               for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
            return FIRE, 0
    if c == FIRE:
        if any(0 <= x+dx < s.w and 0 <= y+dy < s.h and
               s.cells[(y+dy)*s.w+x+dx] == WATER
               for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
            return ASH, 0
    if c == WATER and s.pressure:
        return STEAM, 0
    if c == STEAM and not s.pressure:
        return WATER, 0
    top = y if y % 2 == phase else y-1
    if 0 <= top and top + 1 < s.h:
        a, b = top*s.w+x, (top+1)*s.w+x
        if (a not in s.body and b not in s.body and
                s.cells[a] in (SAND, WATER) and s.cells[b] == EMPTY):
            return (EMPTY if i == a else s.cells[a]), 0
    return c, 0


def apply_events(s, events):
    touched, global_dirty = set(), False
    for e in events:
        kind = e[0]
        if kind == "set":
            _, x, y, c = e
            assert type(c) is int and 0 <= c <= STEAM
            i = s.index(x, y)
            s.cells[i] = c
            touched.add(i)  # includes ABA/redundant edits
        elif kind == "body":
            new = frozenset(s.index(x, y) for x,y in e[1])
            touched |= s.body ^ new
            s.body = new
        elif kind == "pressure":
            assert type(e[1]) is int and e[1] in (0,1)
            global_dirty |= s.pressure != e[1]
            s.pressure = e[1]
        elif kind == "explode":
            _, x0, y0, r = e
            for y in range(max(0,y0-r), min(s.h,y0+r+1)):
                for x in range(max(0,x0-r), min(s.w,x0+r+1)):
                    if (x-x0)**2+(y-y0)**2 <= r*r:
                        i=s.index(x,y)
                        s.cells[i] = EMPTY
                        touched.add(i)
        elif kind == "unknown":
            global_dirty = True
        else:
            raise ValueError("unmodelled effect requires full recompute")
    return touched, global_dirty


def reference(s, events):
    apply_events(s, events)
    phase = s.tick % 2
    results = [sample(s, i, phase) for i in range(s.w*s.h)]
    s.cells = [c for c,_ in results]
    s.tick += 1
    return tuple((i,e) for i,(_,e) in enumerate(results) if e)


class Cache:
    def __init__(self, s, tile_size=3, *, unsafe_state_only=False):
        assert type(tile_size) is int and tile_size>0
        self.s = s.clone()
        self.tile_size=tile_size
        self.nx=(s.w+tile_size-1)//tile_size
        self.ny=(s.h+tile_size-1)//tile_size
        self.roster=[]
        for ty in range(self.ny):
            for tx in range(self.nx):
                self.roster.append(tuple(y*s.w+x for y in range(ty*tile_size,min(s.h,(ty+1)*tile_size))
                                               for x in range(tx*tile_size,min(s.w,(tx+1)*tile_size))))
        assert sorted(i for t in self.roster for i in t) == list(range(s.w*s.h))
        self.unsafe=unsafe_state_only
        self.certified=set()
        self.probes=self.rule_calls=self.halo_work=self.revoked=self.false_revoked=0
        self.refuse_unknown=0
        self.false_revocations=self.diagnostic_calls=self.tile_scans=self.restores=0
        self.certify()

    def tile(self,i):
        x,y=i%self.s.w,i//self.s.w
        return (y//self.tile_size)*self.nx+x//self.tile_size

    def stable(self,t,*,diagnostic=False):
        for i in self.roster[t]:
            for phase in (0,1):
                if diagnostic: self.diagnostic_calls += 1
                else: self.probes += 1
                value, effect=sample(self.s,i,phase)
                if value != self.s.cells[i] or (effect != 0 and not self.unsafe):
                    return False
        return True

    def certify(self):
        for t in range(len(self.roster)):
            if t not in self.certified and self.stable(t):
                self.certified.add(t)

    def revoke(self, touched, global_dirty):
        if global_dirty:
            targets=set(range(len(self.roster)))
            self.refuse_unknown += 1
        else:
            targets=set()
            for i in touched:
                x,y=i%self.s.w,i//self.s.w
                for yy in range(max(0,y-1),min(self.s.h,y+2)):
                    for xx in range(max(0,x-1),min(self.s.w,x+2)):
                        self.halo_work += 1
                        targets.add(self.tile(yy*self.s.w+xx))
        old=targets & self.certified
        self.revoked += len(old)
        self.certified.difference_update(targets)
        # Offline-only diagnostic: a revocation can be conservative yet not
        # needed for the instantaneous post-edit fixed-point predicate.
        self.false_revocations += sum(self.stable(t, diagnostic=True) for t in old)

    def step(self, events, workers=1):
        assert workers in (1,4)
        touched, global_dirty=apply_events(self.s,events)
        self.revoke(touched,global_dirty)
        pre=self.s.clone()
        out=pre.cells.copy()
        side=[]
        for shard in range(workers):
            for t, inds in enumerate(self.roster):
                self.tile_scans += 1
                if t % workers != shard or t in self.certified:
                    continue
                for i in inds:
                    value,e=sample(pre,i,pre.tick%2)
                    out[i]=value
                    self.rule_calls += 1
                    if e:
                        side.append((i,e))
        changed={i for i,(a,b) in enumerate(zip(pre.cells,out)) if a!=b}
        self.s.cells=out
        self.s.tick += 1
        self.revoke(changed,False)
        self.certify()
        return tuple(sorted(side))

    def restore(self, snapshot):
        self.s=snapshot.clone()
        self.certified.clear()
        self.restores += 1
        self.certify()


def seed(w,h):
    s=World(w,h,[ROCK]*(w*h))
    s.cells[s.index(1,1)]=WATER
    s.body=frozenset({s.index(1,2)})
    for x in range(3,w-1):
        s.cells[s.index(x,1)]=SAND
        s.cells[s.index(x,2)]=EMPTY
    return s


def fixtures(w,h,ticks):
    rng=random.Random(w*101+h)
    for t in range(ticks):
        events=[]
        if t%7==0:
            events.append(("set",rng.randrange(w),rng.randrange(h),rng.choice((ROCK,EMPTY,SAND,WATER,WOOD,FIRE))))
        if t%11==1:
            events.append(("body", ((1,2),) if t%22==1 else ()))
        if t%13==2:
            events.append(("pressure", (t//13)%2))
        if t%17==3:
            events.append(("explode",min(4,w-1),min(3,h-1),1))
        if t%19==4:
            events.append(("unknown",))
        if t%23==5:
            events += [("set",0,0,WATER),("set",0,0,ROCK)]  # ABA
        yield events


def run():
    # Decisive, zero-mutation false skip: original cells remain identical,
    # but a certified stationary body-contact cell emits a signed impulse.
    base=World(3,3,[ROCK]*9)
    base.cells[4]=WATER
    base.body=frozenset({7})
    actual=base.clone()
    ledger=reference(actual,())
    bad=Cache(base,3,unsafe_state_only=True)
    bad_ledger=bad.step((),1)
    assert bad.s==actual and ledger==((4,2),) and bad_ledger==()
    good=Cache(base,3)
    assert good.step((),1)==ledger and good.s==actual
    ledger2=reference(actual,())
    assert good.step((),4)==ledger2 and ledger2==((4,-3),)
    rows=[]
    for w,h in ((5,5),(8,6),(16,12)):
        for workers in (1,4):
            whole=seed(w,h)
            cached=Cache(whole,tile_size=3)
            emissions=0
            saved=None
            for attempt,events in enumerate(fixtures(w,h,64)):
                if attempt==17: saved=whole.clone()
                if attempt==40:
                    whole=saved.clone()
                    cached.restore(saved)
                want=reference(whole,events)
                got=cached.step(events,workers)
                assert cached.s==whole, (w,h,workers,whole.tick,"cells")
                assert got==want, (w,h,workers,whole.tick,"effects",want,got)
                emissions+=len(want)
            assert cached.rule_calls <= w*h*64
            rows.append(dict(size=f"{w}x{h}",logical_shards=workers,ticks=64,
                exact_state_and_signed_effects=True,emissions=emissions,
                evaluated=cached.rule_calls,full=w*h*64,
                skipped=w*h*64-cached.rule_calls,
                probe_calls=cached.probes,halo_sites=cached.halo_work,
                revocations=cached.revoked,false_positive_revocations=cached.false_revocations,
                offline_diagnostic_calls=cached.diagnostic_calls,restores=cached.restores,
                tile_scan_visits=cached.tile_scans,global_fallbacks=cached.refuse_unknown,
                abstract_cost=cached.rule_calls+cached.probes+cached.halo_work+cached.tile_scans))
    print(json.dumps(dict(negative_control={"state_equal_on_first_step":bad.s.cells==base.cells,
        "first_effect_expected":[4,2],"first_effect_unsafe":[],"first_effect_safe":[4,2]},
        rows=rows),indent=2,sort_keys=True))


if __name__ == "__main__":
    run()
