module RouteContextTest exposing (..)

{-| Tests for scenario-driven route building: station-based routes,
node targets (portals, buffers), and independent turnout states.
-}

import Dict
import Expect
import ScenarioFixtures
    exposing
        ( ctx
        , eastRouteNormal
        , eastRouteReverse
        , normalStates
        , twoTurnoutCtx
        , westRouteNormal
        )
import Test exposing (..)
import Track.Element exposing (ElementId(..), SwitchState(..))
import Train.Route as Route


suite : Test
suite =
    describe "Train.Route with TrackContext"
        [ routeFromStationTests
        , nodeTargetTests
        , routeEndStationTests
        , twoTurnoutTests
        ]


routeFromStationTests : Test
routeFromStationTests =
    describe "routeFromStation"
        [ test "east station route traverses mainline elements" <|
            \_ ->
                List.map .elementId eastRouteNormal.segments
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3 ]
        , test "east station route is 500m (250 + 50 + 200)" <|
            \_ ->
                eastRouteNormal.totalLength
                    |> Expect.within (Expect.Absolute 0.01) 500.0
        , test "west station route traverses mainline elements in opposite order" <|
            \_ ->
                List.map .elementId westRouteNormal.segments
                    |> Expect.equal [ ElementId 3, ElementId 2, ElementId 1 ]
        , test "unknown station produces an empty route" <|
            \_ ->
                Route.routeFromStation ctx normalStates "nowhere"
                    |> Expect.equal { segments = [], totalLength = 0 }
        , test "missing turnout state defaults to Normal (through)" <|
            \_ ->
                Route.routeFromStation ctx Dict.empty "east"
                    |> .segments
                    |> List.map .elementId
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3 ]
        ]


nodeTargetTests : Test
nodeTargetTests =
    describe "spotPosition with node targets"
        [ test "buffer node is at the end of the siding route" <|
            \_ ->
                Route.spotPosition ctx "buffer" eastRouteReverse
                    |> Expect.equal (Just eastRouteReverse.totalLength)
        , test "buffer node is not reachable on the mainline route" <|
            \_ ->
                Route.spotPosition ctx "buffer" eastRouteNormal
                    |> Expect.equal Nothing
        , test "unknown target id is not reachable" <|
            \_ ->
                Route.spotPosition ctx "no-such-spot" eastRouteNormal
                    |> Expect.equal Nothing
        ]


routeEndStationTests : Test
routeEndStationTests =
    describe "routeEndStation"
        [ test "east mainline route ends at west station" <|
            \_ ->
                Route.routeEndStation ctx eastRouteNormal
                    |> Expect.equal (Just "west")
        , test "west mainline route ends at east station" <|
            \_ ->
                Route.routeEndStation ctx westRouteNormal
                    |> Expect.equal (Just "east")
        , test "siding route ends at no station (buffer stop)" <|
            \_ ->
                Route.routeEndStation ctx eastRouteReverse
                    |> Expect.equal Nothing
        ]


twoTurnoutTests : Test
twoTurnoutTests =
    describe "independent turnout states (two-turnout scenario)"
        [ test "context lists both turnout nodes" <|
            \_ ->
                twoTurnoutCtx.turnoutNodes
                    |> Expect.equal [ "t1", "t2" ]
        , test "both through: route passes both turnouts to the far portal" <|
            \_ ->
                let
                    states =
                        Dict.fromList [ ( "t1", Normal ), ( "t2", Normal ) ]
                in
                Route.routeFromStation twoTurnoutCtx states "south"
                    |> .segments
                    |> List.map .elementId
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3, ElementId 4, ElementId 5 ]
        , test "t1 diverging: route takes first siding, t2 state is irrelevant" <|
            \_ ->
                let
                    routeWithT2Normal =
                        Route.routeFromStation twoTurnoutCtx
                            (Dict.fromList [ ( "t1", Reverse ), ( "t2", Normal ) ])
                            "south"

                    routeWithT2Reverse =
                        Route.routeFromStation twoTurnoutCtx
                            (Dict.fromList [ ( "t1", Reverse ), ( "t2", Reverse ) ])
                            "south"
                in
                Expect.all
                    [ \_ ->
                        List.map .elementId routeWithT2Normal.segments
                            |> Expect.equal [ ElementId 1, ElementId 2, ElementId 9 ]
                    , \_ ->
                        List.map .elementId routeWithT2Reverse.segments
                            |> Expect.equal (List.map .elementId routeWithT2Normal.segments)
                    ]
                    ()
        , test "t2 diverging: route passes t1 through, takes second siding" <|
            \_ ->
                let
                    states =
                        Dict.fromList [ ( "t1", Normal ), ( "t2", Reverse ) ]
                in
                Route.routeFromStation twoTurnoutCtx states "south"
                    |> .segments
                    |> List.map .elementId
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3, ElementId 4, ElementId 7 ]
        , test "toggling t2 does not move t1's start distance on the route" <|
            \_ ->
                let
                    t1Elem =
                        Dict.get "t1" twoTurnoutCtx.nodeElementMap

                    distWith states =
                        t1Elem
                            |> Maybe.andThen
                                (\elemId ->
                                    Route.elementStartDistance elemId
                                        (Route.routeFromStation twoTurnoutCtx states "south")
                                )
                in
                distWith (Dict.fromList [ ( "t1", Normal ), ( "t2", Normal ) ])
                    |> Expect.equal (distWith (Dict.fromList [ ( "t1", Normal ), ( "t2", Reverse ) ]))
        , test "turnoutStartDistance finds the first turnout on the route" <|
            \_ ->
                let
                    states =
                        Dict.fromList [ ( "t1", Normal ), ( "t2", Normal ) ]
                in
                Route.turnoutStartDistance twoTurnoutCtx
                    (Route.routeFromStation twoTurnoutCtx states "south")
                    |> Expect.equal (Just 100.0)
        ]
