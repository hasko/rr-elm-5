module ScenarioLayoutTest exposing (..)

import Dict
import Expect
import Json.Decode as Decode
import Scenario exposing (Scenario)
import Scenario.Layout exposing (LayoutResult, buildLayout)
import Test exposing (..)
import Track.Element exposing (ElementId(..), TrackElementType(..))
import Track.Layout as Layout


sawmillScenario : Result String Scenario
sawmillScenario =
    Decode.decodeString Scenario.decoder sawmillJson
        |> Result.mapError Decode.errorToString


suite : Test
suite =
    describe "Scenario.Layout"
        [ describe "buildLayout with sawmill scenario"
            [ test "produces correct number of elements" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            -- East portal (TrackEnd) + Straight 250 + Turnout + Straight 200 (through)
                            -- + Curve 30° + Straight 150 (siding) + Buffer (TrackEnd) + West portal (TrackEnd)
                            Expect.equal 8 (List.length result.layout.elements)

                        Err err ->
                            Expect.fail err
            , test "first element is TrackEnd (east portal)" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            case List.head result.layout.elements of
                                Just elem ->
                                    Expect.equal TrackEnd elem.elementType

                                Nothing ->
                                    Expect.fail "No elements"

                        Err err ->
                            Expect.fail err
            , test "maps all 4 nodes to element IDs" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            Expect.equal 4 (Dict.size result.nodeElementMap)

                        Err err ->
                            Expect.fail err
            , test "maps e-portal to ElementId 0" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            Expect.equal (Just (ElementId 0)) (Dict.get "e-portal" result.nodeElementMap)

                        Err err ->
                            Expect.fail err
            , test "produces 2 spot positions" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            Expect.equal 2 (Dict.size result.spotPositions)

                        Err err ->
                            Expect.fail err
            , test "platform spot has a valid position" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            case Dict.get "platform" result.spotPositions of
                                Just spot ->
                                    -- Platform should be on the siding, south-east of the turnout
                                    -- Its Y coordinate should be positive (south on screen)
                                    Expect.greaterThan 0 spot.position.y

                                Nothing ->
                                    Expect.fail "platform spot not found"

                        Err err ->
                            Expect.fail err
            , test "team-track spot is further along siding than platform" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            case ( Dict.get "platform" result.spotPositions, Dict.get "team-track" result.spotPositions ) of
                                ( Just platform, Just teamTrack ) ->
                                    -- Team track is further from turnout (larger y)
                                    Expect.greaterThan platform.position.y teamTrack.position.y

                                _ ->
                                    Expect.fail "spot positions not found"

                        Err err ->
                            Expect.fail err
            , test "extracts turnout initial state" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            Expect.equal (Just "through") (Dict.get "t1" result.turnoutStates)

                        Err err ->
                            Expect.fail err
            , test "layout has correct number of connections" <|
                \_ ->
                    case sawmillScenario |> Result.andThen buildLayout of
                        Ok result ->
                            -- 7 connections: portal->straight, straight->turnout,
                            -- turnout-through->straight, straight->west-portal,
                            -- turnout-diverge->curve, curve->siding, siding->buffer
                            Expect.equal 7 (List.length result.layout.connections)

                        Err err ->
                            Expect.fail err
            ]
        , describe "merge point validation"
            [ test "detects position mismatch at merge point" <|
                \_ ->
                    let
                        -- Create a scenario with a passing loop that doesn't merge properly
                        -- Two paths from portal to buffer that have different geometry
                        badScenarioJson =
                            """{
                              "name": "Bad Loop",
                              "description": "Test",
                              "startTime": "06:00",
                              "endTime": "07:00",
                              "track": {
                                "nodes": [
                                  { "id": "portal", "type": "portal" },
                                  { "id": "t1", "type": "turnout", "hand": "right", "radius": 100, "sweep": 30, "throughLength": 50, "initialState": "through" },
                                  { "id": "merge", "type": "turnout", "hand": "right", "radius": 100, "sweep": 30, "throughLength": 50, "initialState": "through" }
                                ],
                                "edges": [
                                  { "from": "portal", "to": "t1", "segments": [{"type": "straight", "length": 100}] },
                                  { "from": "t1", "to": "merge", "port": "through", "segments": [{"type": "straight", "length": 200}] },
                                  { "from": "t1", "to": "merge", "port": "diverge", "segments": [{"type": "straight", "length": 100}] }
                                ]
                              },
                              "stations": [],
                              "goals": []
                            }"""
                    in
                    case Decode.decodeString Scenario.decoder badScenarioJson |> Result.mapError Decode.errorToString |> Result.andThen buildLayout of
                        Ok _ ->
                            -- The merge should fail because the two paths to "merge" have
                            -- different geometry (different lengths, different angles)
                            Expect.fail "Expected merge validation error"

                        Err errMsg ->
                            if String.contains "Merge point validation failed" errMsg || String.contains "merge" (String.toLower errMsg) then
                                Expect.pass

                            else
                                Expect.fail ("Expected merge error, got: " ++ errMsg)
            ]
        ]


sawmillJson : String
sawmillJson =
    """{
  "name": "Morning Run",
  "description": "Move passengers and freight along the sawmill siding.",
  "startTime": "06:00",
  "endTime": "07:00",
  "track": {
    "nodes": [
      { "id": "e-portal", "type": "portal" },
      { "id": "t1", "type": "turnout", "hand": "right", "radius": 170, "sweep": 15, "throughLength": 50, "initialState": "through" },
      { "id": "w-portal", "type": "portal" },
      { "id": "buffer", "type": "buffer" }
    ],
    "edges": [
      {
        "from": "e-portal",
        "to": "t1",
        "segments": [{ "type": "straight", "length": 250 }]
      },
      {
        "from": "t1",
        "to": "w-portal",
        "port": "through",
        "segments": [{ "type": "straight", "length": 200 }]
      },
      {
        "from": "t1",
        "to": "buffer",
        "port": "diverge",
        "segments": [
          { "type": "curve", "radius": 170, "sweep": 30 },
          { "type": "straight", "length": 150 }
        ],
        "spots": [
          { "id": "platform", "at": 149, "name": "Platform" },
          { "id": "team-track", "at": 209, "name": "Team Track" }
        ]
      }
    ]
  },
  "stations": [
    { "id": "east", "name": "Millville", "portal": "e-portal", "stock": [{"type": "locomotive", "count": 1}, {"type": "coach", "count": 2}] },
    { "id": "west", "name": "Lumber Junction", "portal": "w-portal", "stock": [{"type": "locomotive", "count": 1}, {"type": "flatbed", "count": 1}, {"type": "coach", "count": 1}] }
  ],
  "goals": [
    { "what": "coach", "from": "east", "at": "west", "flavor": "Commuters to Lumber Junction" },
    { "what": "coach", "from": "east", "at": "west", "flavor": "More commuters" },
    { "what": "flatbed", "at": "team-track", "flavor": "Spot flatbed" },
    { "what": "coach", "at": "platform", "flavor": "Stop at platform" }
  ]
}"""
