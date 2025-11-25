module Train.Movement exposing
    ( updateTrain
    , shouldDespawn
    )

{-| Train movement and despawn logic.
-}

import Train.Stock exposing (consistLength)
import Train.Types exposing (ActiveTrain)


{-| Update a train's position based on elapsed time.
-}
updateTrain : Float -> ActiveTrain -> ActiveTrain
updateTrain deltaSeconds train =
    let
        newPosition =
            train.position + train.speed * deltaSeconds
    in
    { train | position = newPosition }


{-| Check if a train should be despawned (fully exited the route).
Train is despawned when its last car has exited the route.
-}
shouldDespawn : ActiveTrain -> Bool
shouldDespawn train =
    let
        -- Last car's rear position
        lastCarRear =
            train.position - consistLength train.consist
    in
    lastCarRear > train.route.totalLength
