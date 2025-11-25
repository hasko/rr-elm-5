module Train.Types exposing
    ( ActiveTrain
    , Route
    , RouteSegment
    , SegmentGeometry(..)
    )

{-| Types for active trains in the simulation.
-}

import Planning.Types exposing (StockItem)
import Track.Element exposing (ElementId)
import Util.Vec2 exposing (Vec2)


{-| An active train currently on the track.
-}
type alias ActiveTrain =
    { id : Int
    , consist : List StockItem
    , position : Float -- Distance of lead car front along route (meters)
    , speed : Float -- m/s (positive = forward along route)
    , route : Route
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
