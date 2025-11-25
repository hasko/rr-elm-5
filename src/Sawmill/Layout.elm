module Sawmill.Layout exposing
    ( Element(..)
    , ElementId(..)
    , InteractiveElement
    , SpotType(..)
    , SwitchState(..)
    , elements
    , furniture
    , interactiveElements
    , trackLayout
    )

{-| Layout for the Sawmill puzzle using the composable track element system.

Layout:
    EAST                                                    WEST

    Tunnel ════════════════╗═══════════════════════════════════
    Portal                  ║╲                             Mainline
    (-250, 0)               ║ ╲ Turnout (50, 0)
                                 ╲
                                  ╲ Siding (45° from horizontal)
                             [Platform]
                                  ╲
                             [Team Track]
                                  ╲
                               Buffer

-}

import Array
import Track.Element as TrackElement exposing (Connector, Hand(..))
import Track.Layout as TrackLayout exposing (Layout)
import Util.Vec2 exposing (Vec2, vec2)



-- ELEMENT TYPES


type ElementId
    = TunnelPortalId
    | WestTunnelPortalId
    | TurnoutId
    | PlatformSpotId
    | TeamTrackSpotId
    | BufferStopId


type Element
    = TunnelPortal Vec2 String -- position, name
    | Turnout Vec2 Float SwitchState -- position, orientation (radians), state
    | Spot Vec2 String SpotType -- position, name, type
    | BufferStop Vec2 Float -- position, orientation


type SpotType
    = Passenger
    | Freight


type SwitchState
    = Normal
    | Reverse



-- INTERACTIVE ELEMENTS


type alias InteractiveElement =
    { id : ElementId
    , element : Element
    , bounds : Bounds
    , tooltip : String
    }


type alias Bounds =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }



-- TRACK LAYOUT


{-| Track geometry constants
-}
turnoutRadius : Float
turnoutRadius =
    170


turnoutSweep : Float
turnoutSweep =
    15 * pi / 180 -- 15 degrees


continuationSweep : Float
continuationSweep =
    30 * pi / 180 -- 30 degrees


{-| Total curve angle (turnout + continuation) = 45 degrees
-}
totalCurveAngle : Float
totalCurveAngle =
    turnoutSweep + continuationSweep


{-| The sawmill track layout built using the composable track system.

Elements:
0: Tunnel portal (TrackEnd) at (-250, 0) facing east
1: Mainline east (Straight 250m) from tunnel to turnout
2: Turnout (right-hand, 170m radius, 15° diverge)
3: Mainline west (Straight 200m) continuing west
4: Continuation curve (30° more)
5: Siding (Straight 150m)
6: Buffer stop (TrackEnd)

-}
trackLayout : Layout
trackLayout =
    let
        -- Start at tunnel portal facing west (90° = pi/2 radians)
        -- Trains exit the tunnel heading west (right on screen)
        tunnelConnector =
            { position = vec2 -250 0, orientation = pi / 2 }

        -- Build the layout step by step
        ( layout0, _ ) =
            TrackLayout.placeElement TrackElement.TrackEnd tunnelConnector TrackLayout.emptyLayout

        -- Mainline east (from tunnel to turnout)
        ( layout1, _ ) =
            TrackLayout.placeElementAt (TrackElement.StraightTrack 250) ( TrackElement.ElementId 0, 0 ) layout0

        -- Turnout at the junction
        ( layout2, _ ) =
            TrackLayout.placeElementAt
                (TrackElement.Turnout
                    { throughLength = 50
                    , radius = turnoutRadius
                    , sweep = turnoutSweep
                    , hand = RightHand
                    }
                )
                ( TrackElement.ElementId 1, 1 )
                layout1

        -- Mainline west (continuing from turnout's through route)
        ( layout3, _ ) =
            TrackLayout.placeElementAt (TrackElement.StraightTrack 200) ( TrackElement.ElementId 2, 1 ) layout2

        -- Continuation curve (from turnout's diverging route, continues right/CW)
        ( layout4, _ ) =
            TrackLayout.placeElementAt
                (TrackElement.CurvedTrack { radius = turnoutRadius, sweep = continuationSweep })
                ( TrackElement.ElementId 2, 2 )
                layout3

        -- Siding (straight section after continuation curve)
        ( layout5, _ ) =
            TrackLayout.placeElementAt (TrackElement.StraightTrack 150) ( TrackElement.ElementId 4, 1 ) layout4

        -- Buffer stop at end of siding
        ( layout6, _ ) =
            TrackLayout.placeElementAt TrackElement.TrackEnd ( TrackElement.ElementId 5, 1 ) layout5

        -- West tunnel portal at end of mainline west
        ( layout7, _ ) =
            TrackLayout.placeElementAt TrackElement.TrackEnd ( TrackElement.ElementId 3, 1 ) layout6
    in
    layout7


{-| Get the siding direction vector from the track layout.
-}
sidingDirection : Vec2
sidingDirection =
    vec2 (cos totalCurveAngle) (sin totalCurveAngle)


{-| Calculate a point along the siding at the given distance from the siding start.
Uses the continuation curve end connector position.
-}
pointAlongSiding : Float -> Vec2
pointAlongSiding distance =
    let
        -- Get continuation curve end (element 4, connector 1)
        maybeCurveEnd =
            TrackLayout.getConnector (TrackElement.ElementId 4) 1 trackLayout

        curveEnd =
            case maybeCurveEnd of
                Just c ->
                    c.position

                Nothing ->
                    -- Fallback if layout construction failed
                    vec2 0 0
    in
    vec2
        (curveEnd.x + distance * sidingDirection.x)
        (curveEnd.y + distance * sidingDirection.y)



-- LAYOUT DATA


{-| All interactive elements in the sawmill puzzle.
-}
interactiveElements : SwitchState -> List InteractiveElement
interactiveElements turnoutState =
    let
        -- Get positions from track layout
        tunnelPos =
            case TrackLayout.getConnector (TrackElement.ElementId 0) 0 trackLayout of
                Just c ->
                    c.position

                Nothing ->
                    vec2 -250 0

        turnoutPos =
            case TrackLayout.getConnector (TrackElement.ElementId 2) 0 trackLayout of
                Just c ->
                    c.position

                Nothing ->
                    vec2 0 0

        -- Position along siding for each element
        platformPos =
            pointAlongSiding 60

        teamTrackPos =
            pointAlongSiding 120

        bufferPos =
            pointAlongSiding 150
    in
    let
        -- Get West Station position from track layout (element 7, connector 0)
        westPos =
            case TrackLayout.getConnector (TrackElement.ElementId 7) 0 trackLayout of
                Just c ->
                    c.position

                Nothing ->
                    vec2 250 0
    in
    [ { id = TunnelPortalId
      , element = TunnelPortal tunnelPos "East Station"
      , bounds = { x = tunnelPos.x - 20, y = tunnelPos.y - 20, width = 40, height = 40 }
      , tooltip = "East Station (spawn point)"
      }
    , { id = WestTunnelPortalId
      , element = TunnelPortal westPos "West Station"
      , bounds = { x = westPos.x - 20, y = westPos.y - 20, width = 40, height = 40 }
      , tooltip = "West Station (spawn point)"
      }
    , { id = TurnoutId
      , element = Turnout turnoutPos 0 turnoutState
      , bounds = { x = turnoutPos.x - 15, y = turnoutPos.y - 15, width = 60, height = 30 }
      , tooltip =
            case turnoutState of
                Normal ->
                    "Turnout: Normal (mainline)"

                Reverse ->
                    "Turnout: Reverse (siding)"
      }
    , { id = PlatformSpotId
      , element = Spot platformPos "Platform" Passenger
      , bounds = { x = platformPos.x - 15, y = platformPos.y - 15, width = 30, height = 30 }
      , tooltip = "Platform (passenger spot)"
      }
    , { id = TeamTrackSpotId
      , element = Spot teamTrackPos "Team Track" Freight
      , bounds = { x = teamTrackPos.x - 15, y = teamTrackPos.y - 15, width = 30, height = 30 }
      , tooltip = "Team Track (freight spot)"
      }
    , { id = BufferStopId
      , element = BufferStop bufferPos totalCurveAngle
      , bounds = { x = bufferPos.x - 10, y = bufferPos.y - 10, width = 20, height = 20 }
      , tooltip = "Buffer Stop"
      }
    ]


{-| Get all elements for rendering.
-}
elements : SwitchState -> List Element
elements turnoutState =
    List.map .element (interactiveElements turnoutState)


{-| Map furniture - decorative elements.
Positioned relative to the angled siding.
-}
furniture :
    { sawmill : { position : Vec2, width : Float, height : Float, orientation : Float }
    , platform : { position : Vec2, width : Float, height : Float, orientation : Float }
    , teamTrackRamp : { position : Vec2, width : Float, height : Float, orientation : Float }
    , trees : List Vec2
    }
furniture =
    let
        -- Calculate positions along the siding
        platformPos =
            pointAlongSiding 60

        teamTrackPos =
            pointAlongSiding 120

        -- Perpendicular direction (to offset furniture from track)
        -- Rotate siding direction 90° clockwise: (x, y) -> (y, -x)
        perpOffset =
            { x = sidingDirection.y, y = -sidingDirection.x }

        -- Siding track orientation (45 degrees)
        sidingOrientation =
            totalCurveAngle
    in
    { sawmill =
        -- East of team track area (perpendicular offset from siding)
        { position = vec2 (teamTrackPos.x + 50 * perpOffset.x) (teamTrackPos.y + 50 * perpOffset.y)
        , width = 80
        , height = 60
        , orientation = sidingOrientation
        }
    , platform =
        -- West of platform position (negative perpendicular offset)
        { position = vec2 (platformPos.x - 30 * perpOffset.x) (platformPos.y - 30 * perpOffset.y)
        , width = 35
        , height = 20
        , orientation = sidingOrientation
        }
    , teamTrackRamp =
        -- East of team track position
        { position = vec2 (teamTrackPos.x + 25 * perpOffset.x) (teamTrackPos.y + 25 * perpOffset.y)
        , width = 25
        , height = 15
        , orientation = sidingOrientation
        }
    , trees =
        [ vec2 -50 80
        , vec2 -40 140
        , vec2 (platformPos.x + 60) (platformPos.y - 20)
        , vec2 (teamTrackPos.x + 80) teamTrackPos.y
        , vec2 -80 -30
        , vec2 150 -20
        ]
    }
