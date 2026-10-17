extends Object
## Implements the runtime combat effects behavior used by the battle effect pipeline.
class_name CombatEffects

## The type of effect this is.
enum KIND {
    ## Positive effect for the owner, has a duration.
    BUFF = 0,
    ## Negative effect for the owner, has a duration.
    DEBUFF = 100,
    ## Effect that occurs and then is dismissed.
    INSTANT = 200,
    ## Effect that occurs once when triggered.
    ONCE = 300,
    ## Effect that repeats.
    REPEAT = 400
}

## When an effect's code is executed.
enum TRIGGER {
    ## When something is equipped.
    EQUIP = 0,
    ## When the effect owner is about to be hit.
    TARGETED = 100,
    ## After the effect owner is hit.
    DAMAGED = 200,
    ## When the effect owner is about to hit.
    ATTACKING = 300,
    ## After the effect owner hits.
    AFTER_HITTING = 400,
    ## When the effect owner is defeated.
    DEFEAT = 500,
    ## When the effect owner defeats a unit.
    KILL = 600,
    ## When all other effects have been processed on the owner.
    PROCESS_OVER = 700,
    ## When the round is over.
    ROUND_OVER = 800,
    ## After a successful hit roll, before outgoing damage and mitigation.
    BEFORE_DAMAGE = 900
}

## Enumerates the supported tag values.
enum TAG {
    SPECIAL = 0,
    HEALING = 10,
    DAMAGE = 20,
    DOT = 30,
    DRAIN = 40,
    ATTRIBUTE = 50,
    RESOURCE = 60,
    STAT = 70,
    VISUAL = 80,
    AUDIO = 90,
    RESPONSE = 100
}
