module Train.Movement exposing
    ( exitedThroughStart
    , shouldDespawn
    )

{-| Despawn logic. Movement itself is handled by `Train.Execution`.
-}

import Programmer.Types exposing (ReverserPosition(..))
import Train.Stock exposing (consistLength)
import Train.Types exposing (ActiveTrain)


{-| Check if a train should be despawned (fully exited the route).

A forward train has left once its last car is past the route end; a
reversing train has left once its head (the trailing end) is back inside
the portal at the route start.

-}
shouldDespawn : ActiveTrain -> Bool
shouldDespawn train =
    exitedThroughStart train
        || (train.position - consistLength train.consist > train.route.totalLength)


{-| Has the train backed out through the portal at the start of its route?
-}
exitedThroughStart : ActiveTrain -> Bool
exitedThroughStart train =
    train.reverser == Reverse && train.position < 0
