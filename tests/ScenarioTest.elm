module ScenarioTest exposing (..)

import Expect
import Json.Decode as Decode
import Scenario exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Scenario JSON decoders"
        [ describe "nodeDecoder"
            [ test "decodes portal node" <|
                \_ ->
                    let
                        json =
                            """{"id": "e-portal", "type": "portal"}"""
                    in
                    case Decode.decodeString nodeDecoder json of
                        Ok node ->
                            Expect.all
                                [ \n -> Expect.equal "e-portal" n.id
                                , \n -> Expect.equal Portal n.nodeType
                                ]
                                node

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes turnout node" <|
                \_ ->
                    let
                        json =
                            """{"id": "t1", "type": "turnout", "hand": "right", "radius": 170, "sweep": 15, "throughLength": 50, "initialState": "through"}"""
                    in
                    case Decode.decodeString nodeDecoder json of
                        Ok node ->
                            case node.nodeType of
                                Turnout props ->
                                    Expect.all
                                        [ \_ -> Expect.equal "t1" node.id
                                        , \_ -> Expect.equal "right" props.hand
                                        , \_ -> Expect.within (Expect.Absolute 0.001) 170 props.radius
                                        , \_ -> Expect.within (Expect.Absolute 0.001) 15 props.sweep
                                        , \_ -> Expect.within (Expect.Absolute 0.001) 50 props.throughLength
                                        , \_ -> Expect.equal "through" props.initialState
                                        ]
                                        ()

                                _ ->
                                    Expect.fail "Expected Turnout node type"

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "turnout defaults initialState to through" <|
                \_ ->
                    let
                        json =
                            """{"id": "t1", "type": "turnout", "hand": "right", "radius": 170, "sweep": 15, "throughLength": 50}"""
                    in
                    case Decode.decodeString nodeDecoder json of
                        Ok node ->
                            case node.nodeType of
                                Turnout props ->
                                    Expect.equal "through" props.initialState

                                _ ->
                                    Expect.fail "Expected Turnout node type"

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes buffer node" <|
                \_ ->
                    let
                        json =
                            """{"id": "buffer", "type": "buffer"}"""
                    in
                    case Decode.decodeString nodeDecoder json of
                        Ok node ->
                            Expect.all
                                [ \n -> Expect.equal "buffer" n.id
                                , \n -> Expect.equal Buffer n.nodeType
                                ]
                                node

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "rejects unknown node type" <|
                \_ ->
                    let
                        json =
                            """{"id": "x", "type": "bridge"}"""
                    in
                    case Decode.decodeString nodeDecoder json of
                        Ok _ ->
                            Expect.fail "Expected decode failure for unknown node type"

                        Err _ ->
                            Expect.pass
            ]
        , describe "segmentDecoder"
            [ test "decodes straight segment" <|
                \_ ->
                    let
                        json =
                            """{"type": "straight", "length": 250}"""
                    in
                    case Decode.decodeString segmentDecoder json of
                        Ok seg ->
                            case seg of
                                StraightSegment len ->
                                    Expect.within (Expect.Absolute 0.001) 250 len

                                _ ->
                                    Expect.fail "Expected StraightSegment"

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes curve segment" <|
                \_ ->
                    let
                        json =
                            """{"type": "curve", "radius": 170, "sweep": 30}"""
                    in
                    case Decode.decodeString segmentDecoder json of
                        Ok seg ->
                            case seg of
                                CurveSegment props ->
                                    Expect.all
                                        [ \_ -> Expect.within (Expect.Absolute 0.001) 170 props.radius
                                        , \_ -> Expect.within (Expect.Absolute 0.001) 30 props.sweep
                                        ]
                                        ()

                                _ ->
                                    Expect.fail "Expected CurveSegment"

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "edgeDecoder"
            [ test "decodes straight edge" <|
                \_ ->
                    let
                        json =
                            """{"from": "e-portal", "to": "t1", "segments": [{"type": "straight", "length": 250}]}"""
                    in
                    case Decode.decodeString edgeDecoder json of
                        Ok edge ->
                            Expect.all
                                [ \e -> Expect.equal "e-portal" e.from
                                , \e -> Expect.equal "t1" e.to
                                , \e -> Expect.equal 1 (List.length e.segments)
                                , \e -> Expect.equal Nothing e.port_
                                , \e -> Expect.equal [] e.spots
                                ]
                                edge

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes edge with spots" <|
                \_ ->
                    let
                        json =
                            """{"from": "t1", "to": "buffer", "segments": [{"type": "straight", "length": 150}], "spots": [{"id": "platform", "at": 60, "name": "Platform"}]}"""
                    in
                    case Decode.decodeString edgeDecoder json of
                        Ok edge ->
                            case edge.spots of
                                [ spot ] ->
                                    Expect.all
                                        [ \_ -> Expect.equal "platform" spot.id
                                        , \_ -> Expect.within (Expect.Absolute 0.001) 60 spot.at
                                        , \_ -> Expect.equal "Platform" spot.name
                                        ]
                                        ()

                                _ ->
                                    Expect.fail ("Expected 1 spot, got " ++ String.fromInt (List.length edge.spots))

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes edge with port" <|
                \_ ->
                    let
                        json =
                            """{"from": "t1", "to": "w-portal", "port": "through", "segments": [{"type": "straight", "length": 200}]}"""
                    in
                    case Decode.decodeString edgeDecoder json of
                        Ok edge ->
                            Expect.equal (Just "through") edge.port_

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes compound edge with multiple segments" <|
                \_ ->
                    let
                        json =
                            """{"from": "t1", "to": "buffer", "port": "diverge", "segments": [{"type": "curve", "radius": 170, "sweep": 30}, {"type": "straight", "length": 150}]}"""
                    in
                    case Decode.decodeString edgeDecoder json of
                        Ok edge ->
                            Expect.all
                                [ \e -> Expect.equal 2 (List.length e.segments)
                                , \e -> Expect.equal (Just "diverge") e.port_
                                ]
                                edge

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "stationDecoder"
            [ test "decodes station with stock" <|
                \_ ->
                    let
                        json =
                            """{"id": "east", "name": "Millville", "portal": "e-portal", "stock": [{"type": "locomotive", "count": 1}, {"type": "coach", "count": 2}]}"""
                    in
                    case Decode.decodeString stationDecoder json of
                        Ok station ->
                            Expect.all
                                [ \s -> Expect.equal "east" s.id
                                , \s -> Expect.equal "Millville" s.name
                                , \s -> Expect.equal "e-portal" s.portal
                                , \s -> Expect.equal 2 (List.length s.stock)
                                , \s ->
                                    case s.stock of
                                        first :: _ ->
                                            Expect.all
                                                [ \_ -> Expect.equal "locomotive" first.stockType
                                                , \_ -> Expect.equal 1 first.count
                                                ]
                                                ()

                                        [] ->
                                            Expect.fail "Expected at least one stock entry"
                                ]
                                station

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "goalDecoder"
            [ test "decodes directional goal" <|
                \_ ->
                    let
                        json =
                            """{"what": "coach", "from": "east", "at": "west", "flavor": "Morning commuters"}"""
                    in
                    case Decode.decodeString goalDecoder json of
                        Ok goal ->
                            Expect.all
                                [ \g -> Expect.equal "coach" g.what
                                , \g -> Expect.equal (Just "east") g.from
                                , \g -> Expect.equal "west" g.at
                                , \g -> Expect.equal "Morning commuters" g.flavor
                                ]
                                goal

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            , test "decodes non-directional goal" <|
                \_ ->
                    let
                        json =
                            """{"what": "flatbed", "at": "team-track", "flavor": "Spot for loading"}"""
                    in
                    case Decode.decodeString goalDecoder json of
                        Ok goal ->
                            Expect.all
                                [ \g -> Expect.equal "flatbed" g.what
                                , \g -> Expect.equal Nothing g.from
                                , \g -> Expect.equal "team-track" g.at
                                , \g -> Expect.equal "Spot for loading" g.flavor
                                ]
                                goal

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        , describe "full scenario decoder"
            [ test "decodes complete sawmill scenario" <|
                \_ ->
                    let
                        json =
                            sawmillJson
                    in
                    case Decode.decodeString decoder json of
                        Ok scenario ->
                            Expect.all
                                [ \s -> Expect.equal "Morning Run" s.name
                                , \s -> Expect.equal "06:00" s.startTime
                                , \s -> Expect.equal "07:00" s.endTime
                                , \s -> Expect.equal 4 (List.length s.track.nodes)
                                , \s -> Expect.equal 3 (List.length s.track.edges)
                                , \s -> Expect.equal 2 (List.length s.stations)
                                , \s -> Expect.equal 4 (List.length s.goals)
                                , \s ->
                                    let
                                        totalSpots =
                                            List.concatMap .spots s.track.edges |> List.length
                                    in
                                    Expect.equal 2 totalSpots
                                ]
                                scenario

                        Err err ->
                            Expect.fail (Decode.errorToString err)
            ]
        ]


{-| Inline sawmill scenario JSON for testing (matches public/scenarios/sawmill.json).
-}
sawmillJson : String
sawmillJson =
    """{
  "name": "Morning Run",
  "description": "Move passengers and freight along the sawmill siding before the morning shift.",
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
    {
      "id": "east",
      "name": "Millville",
      "portal": "e-portal",
      "stock": [
        { "type": "locomotive", "count": 1 },
        { "type": "coach", "count": 2 }
      ]
    },
    {
      "id": "west",
      "name": "Lumber Junction",
      "portal": "w-portal",
      "stock": [
        { "type": "locomotive", "count": 1 },
        { "type": "flatbed", "count": 1 },
        { "type": "coach", "count": 1 }
      ]
    }
  ],
  "goals": [
    {
      "what": "coach",
      "from": "east",
      "at": "west",
      "flavor": "Morning commuters need a ride to Lumber Junction"
    },
    {
      "what": "coach",
      "from": "east",
      "at": "west",
      "flavor": "More commuters heading to Lumber Junction"
    },
    {
      "what": "flatbed",
      "at": "team-track",
      "flavor": "Spot an empty flatbed at the team track for loading"
    },
    {
      "what": "coach",
      "at": "platform",
      "flavor": "A coach must stop at the sawmill platform"
    }
  ]
}"""
