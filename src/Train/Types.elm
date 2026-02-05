module Train.Types exposing
    ( ActiveTrain
    , Effect(..)
    , Route
    , RouteSegment
    , SegmentGeometry(..)
    , TrainState(..)
    )

{-| Types for active trains in the simulation.
-}

import Planning.Types exposing (SpawnPointId, StockItem)
import Programmer.Types exposing (Order, ReverserPosition(..), SwitchPosition)
import Track.Element exposing (ElementId)
import Util.Vec2 exposing (Vec2)


{-| Train execution state.
-}
type TrainState
    = Executing
    | WaitingForOrders
    | Stopped String


{-| Side effects produced by program execution that affect world state.
-}
type Effect
    = SetSwitchEffect String SwitchPosition


{-| An active train currently on the track.
-}
type alias ActiveTrain =
    { id : Int
    , consist : List StockItem
    , position : Float -- Distance of lead car front along route (meters)
    , speed : Float -- m/s (positive = forward along route)
    , route : Route
    , spawnPoint : SpawnPointId -- Which direction this train travels
    , program : List Order
    , programCounter : Int
    , trainState : TrainState
    , reverser : ReverserPosition
    , waitTimer : Float -- Seconds remaining for WaitSeconds
    }


{-| A route is a sequence of track segments defining a path.
-}
type alias Route =
    { segments : List RouteSegment
    , totalLength : Float
    }


{-| A segment of a route with computed geometry.
-}
type alias RouteSegment =
    { elementId : ElementId
    , length : Float
    , startDistance : Float -- Cumulative distance at segment start
    , geometry : SegmentGeometry
    }


{-| Geometry for interpolating position along a segment.
-}
type SegmentGeometry
    = StraightGeometry
        { start : Vec2
        , end : Vec2
        , orientation : Float -- radians, direction of travel
        }
    | ArcGeometry
        { center : Vec2
        , radius : Float
        , startAngle : Float -- radians, angle at segment start
        , sweep : Float -- radians, positive = CCW
        }
