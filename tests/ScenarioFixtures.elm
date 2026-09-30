module ScenarioFixtures exposing
    ( ctx
    , eastRouteNormal
    , eastRouteReverse
    , normalStates
    , reverseStates
    , sawmillScenario
    , twoTurnoutCtx
    , twoTurnoutScenario
    , westRouteNormal
    )

{-| Shared scenario fixtures for unit tests.

`sawmillScenario` mirrors `public/scenarios/sawmill.json` as an Elm value.
Element ids in the built layout:

    0: e-portal (TrackEnd)   4: w-portal (TrackEnd)
    1: straight 250m         5: curve 30°
    2: turnout t1            6: siding straight 150m
    3: straight 200m         7: buffer (TrackEnd)

A canary test in ScenarioLayoutTest asserts that `buildLayout` succeeds for
these fixtures, so the `Result.withDefault` fallbacks here cannot mask
a broken layout silently.

-}

import Dict exposing (Dict)
import Scenario exposing (NodeType(..), Scenario)
import Scenario.Layout exposing (LayoutResult)
import Track.Element exposing (SwitchState(..))
import Track.Layout
import Train.Route as Route exposing (TrackContext)
import Train.Types exposing (Route)


sawmillScenario : Scenario
sawmillScenario =
    { name = "Morning Run"
    , description = "Move passengers and freight along the sawmill siding."
    , startTime = "06:00"
    , endTime = "07:00"
    , track =
        { nodes =
            [ { id = "e-portal", nodeType = Portal }
            , { id = "t1"
              , nodeType =
                    Turnout
                        { hand = "right"
                        , radius = 170
                        , sweep = 15
                        , throughLength = 50
                        , initialState = "through"
                        }
              }
            , { id = "w-portal", nodeType = Portal }
            , { id = "buffer", nodeType = Buffer }
            ]
        , edges =
            [ { from = "e-portal"
              , to = "t1"
              , segments = [ Scenario.StraightSegment 250 ]
              , port_ = Nothing
              , spots = []
              }
            , { from = "t1"
              , to = "w-portal"
              , segments = [ Scenario.StraightSegment 200 ]
              , port_ = Just "through"
              , spots = []
              }
            , { from = "t1"
              , to = "buffer"
              , segments =
                    [ Scenario.CurveSegment { radius = 170, sweep = 30 }
                    , Scenario.StraightSegment 150
                    ]
              , port_ = Just "diverge"
              , spots =
                    [ { id = "platform", at = 149, name = "Platform" }
                    , { id = "team-track", at = 209, name = "Team Track" }
                    ]
              }
            ]
        }
    , stations =
        [ { id = "east"
          , name = "Millville"
          , portal = "e-portal"
          , stock = [ { stockType = "locomotive", count = 1 }, { stockType = "coach", count = 2 } ]
          }
        , { id = "west"
          , name = "Lumber Junction"
          , portal = "w-portal"
          , stock =
                [ { stockType = "locomotive", count = 1 }
                , { stockType = "flatbed", count = 1 }
                , { stockType = "coach", count = 1 }
                ]
          }
        ]
    , goals =
        [ { what = "coach", at = "west", from = Just "east", flavor = "Commuters" }
        , { what = "coach", at = "west", from = Just "east", flavor = "More commuters" }
        , { what = "flatbed", at = "team-track", from = Nothing, flavor = "Spot flatbed" }
        , { what = "coach", at = "platform", from = Nothing, flavor = "Stop at platform" }
        ]
    }


emptyLayoutResult : LayoutResult
emptyLayoutResult =
    { layout = Track.Layout.emptyLayout
    , nodeElementMap = Dict.empty
    , spotPositions = Dict.empty
    , spotLocations = Dict.empty
    , turnoutStates = Dict.empty
    }


layoutResult : LayoutResult
layoutResult =
    Scenario.Layout.buildLayout sawmillScenario
        |> Result.withDefault emptyLayoutResult


ctx : TrackContext
ctx =
    Route.makeTrackContext sawmillScenario layoutResult


normalStates : Dict String SwitchState
normalStates =
    Dict.fromList [ ( "t1", Normal ) ]


reverseStates : Dict String SwitchState
reverseStates =
    Dict.fromList [ ( "t1", Reverse ) ]


{-| Route departing Millville ("east", anchor portal) with the given states.
-}
eastRouteNormal : Route
eastRouteNormal =
    Route.routeFromStation ctx normalStates "east"


eastRouteReverse : Route
eastRouteReverse =
    Route.routeFromStation ctx reverseStates "east"


westRouteNormal : Route
westRouteNormal =
    Route.routeFromStation ctx normalStates "west"



-- TWO-TURNOUT SCENARIO


{-| A scenario with two independent turnouts: mainline with two sidings.

    portal -- 100m -- t1 =through==== 100m ==== t2 =through== 100m == far-portal
                        \\diverge                  \\diverge
                         curve+50m                  curve+50m
                         buffer1                    buffer2

-}
twoTurnoutScenario : Scenario
twoTurnoutScenario =
    { name = "Two Sidings"
    , description = "Two turnouts with independent state."
    , startTime = "06:00"
    , endTime = "07:00"
    , track =
        { nodes =
            [ { id = "p1", nodeType = Portal }
            , { id = "t1"
              , nodeType =
                    Turnout
                        { hand = "right"
                        , radius = 170
                        , sweep = 15
                        , throughLength = 50
                        , initialState = "through"
                        }
              }
            , { id = "t2"
              , nodeType =
                    Turnout
                        { hand = "right"
                        , radius = 170
                        , sweep = 15
                        , throughLength = 50
                        , initialState = "through"
                        }
              }
            , { id = "p2", nodeType = Portal }
            , { id = "b1", nodeType = Buffer }
            , { id = "b2", nodeType = Buffer }
            ]
        , edges =
            [ { from = "p1", to = "t1", segments = [ Scenario.StraightSegment 100 ], port_ = Nothing, spots = [] }
            , { from = "t1", to = "t2", segments = [ Scenario.StraightSegment 100 ], port_ = Just "through", spots = [] }
            , { from = "t1", to = "b1", segments = [ Scenario.StraightSegment 50 ], port_ = Just "diverge", spots = [] }
            , { from = "t2", to = "p2", segments = [ Scenario.StraightSegment 100 ], port_ = Just "through", spots = [] }
            , { from = "t2", to = "b2", segments = [ Scenario.StraightSegment 50 ], port_ = Just "diverge", spots = [] }
            ]
        }
    , stations =
        [ { id = "south", name = "South Yard", portal = "p1", stock = [] }
        , { id = "north", name = "North Yard", portal = "p2", stock = [] }
        ]
    , goals = []
    }


twoTurnoutLayoutResult : LayoutResult
twoTurnoutLayoutResult =
    Scenario.Layout.buildLayout twoTurnoutScenario
        |> Result.withDefault emptyLayoutResult


twoTurnoutCtx : TrackContext
twoTurnoutCtx =
    Route.makeTrackContext twoTurnoutScenario twoTurnoutLayoutResult
