"""Independent abstract replay control. Does not import the published CyberSand model.
This is a review oracle for receipt classification, not source-head qualification.
"""
from dataclasses import dataclass, replace
from enum import Enum

class Status(str, Enum):
    COMMITTED = 'COMMITTED'
    HISTORICAL_ACK_ONLY = 'HISTORICAL_ACK_ONLY'
    REFUSED = 'REFUSED'

@dataclass(frozen=True)
class Receipt:
    status: Status
    epoch: int
    destination: str

@dataclass
class Snapshot:
    generation: int
    epoch: int
    count: int
    owner: str
    signed: bool
    accepted: dict

def replay(w, token, fingerprint, fence):
    # Oracle deliberately models only an accepted-token lookup and no mutation.
    old_fp, receipt = w.accepted[token]
    if fingerprint != old_fp:
        return Status.REFUSED, None
    return Status.HISTORICAL_ACK_ONLY, replace(receipt,status=Status.HISTORICAL_ACK_ONLY)

def snapshot(w):
    return (w.generation,w.epoch,w.count,w.owner,w.signed,tuple(sorted(w.accepted.items())))

trials = 0
for generation in (3, 4, 140):
    for epoch in (1, 2, 9, 2**20):
        for signed in (False, True):
            for fence in (False, True):
                w = Snapshot(generation, epoch, 256, 'ballistic', signed,
                             {'launch':(('water',3,0,256,'ballistic',13,-32),Receipt(Status.COMMITTED,1,'water'))})
                prior = snapshot(w)
                for i in range(16):
                    actual, receipt = replay(w,'launch',('water',3,0,256,'ballistic',13,-32),fence)
                    assert actual is Status.HISTORICAL_ACK_ONLY
                    assert receipt.epoch == 1
                    assert receipt.status != Status.COMMITTED
                    assert snapshot(w)==prior
                    trials+=1
                bad,_=replay(w,'launch',('water',3,0,256,'ballistic',13,32),fence)
                assert bad is Status.REFUSED and snapshot(w)==prior
print(f'PASS {trials} shadow replays + 48 fingerprint-spoof refusals; zero state mutations')
