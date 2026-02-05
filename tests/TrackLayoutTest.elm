module TrackLayoutTest exposing (..)

import Array
import Expect
import Test exposing (..)
import Track.Element as Element exposing (ElementId(..), TrackElementType(..))
import Track.Layout
    exposing
        ( Layout
        , connect
        , emptyLayout
        , findElement
        , getConnector
        , placeElement
        , placeElementAt
        )
import Util.Vec2 exposing (vec2)


suite : Test
suite =
    describe "Track.Layout"
        [ emptyLayoutTests
        , placeElementTests
        , placeElementAtTests
        , connectTests
        , findElementTests
        , getConnectorTests
        ]


emptyLayoutTests : Test
emptyLayoutTests =
    describe "emptyLayout"
        [ test "has no elements" <|
            \_ ->
                emptyLayout.elements
                    |> List.length
                    |> Expect.equal 0
        , test "has no connections" <|
            \_ ->
                emptyLayout.connections
                    |> List.length
                    |> Expect.equal 0
        , test "next id starts at 0" <|
            \_ ->
                emptyLayout.nextId
                    |> Expect.equal 0
        ]


placeElementTests : Test
placeElementTests =
    describe "placeElement"
        [ test "adds element to layout" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout, _ ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                List.length layout.elements
                    |> Expect.equal 1
        , test "returns new element ID" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( _, newId ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                newId
                    |> Expect.equal (ElementId 0)
        , test "increments next ID" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout, _ ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                layout.nextId
                    |> Expect.equal 1
        , test "successive placements get incrementing IDs" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout1, id1 ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, id2 ) =
                        placeElement TrackEnd c0 layout1

                    ( _, id3 ) =
                        placeElement TrackEnd c0 layout2
                in
                ( id1, id2, id3 )
                    |> Expect.equal ( ElementId 0, ElementId 1, ElementId 2 )
        , test "computes connectors for placed element" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout, _ ) =
                        placeElement (StraightTrack 100) c0 emptyLayout
                in
                case List.head layout.elements of
                    Just elem ->
                        Array.length elem.connectors
                            |> Expect.equal 2

                    Nothing ->
                        Expect.fail "No element placed"
        ]


placeElementAtTests : Test
placeElementAtTests =
    describe "placeElementAt"
        [ test "places element connected to existing connector" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout1, _ ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, _ ) =
                        placeElementAt (StraightTrack 100) ( ElementId 0, 0 ) layout1
                in
                List.length layout2.elements
                    |> Expect.equal 2
        , test "adds connection between elements" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout1, _ ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, _ ) =
                        placeElementAt (StraightTrack 100) ( ElementId 0, 0 ) layout1
                in
                List.length layout2.connections
                    |> Expect.equal 1
        , test "new element connector 0 matches existing connector position" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout1, _ ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, newId ) =
                        placeElementAt (StraightTrack 100) ( ElementId 0, 0 ) layout1
                in
                case ( getConnector (ElementId 0) 0 layout2, getConnector newId 0 layout2 ) of
                    ( Just existingConn, Just newConn ) ->
                        Expect.all
                            [ \_ ->
                                newConn.position.x
                                    |> Expect.within (Expect.Absolute 0.01) existingConn.position.x
                            , \_ ->
                                newConn.position.y
                                    |> Expect.within (Expect.Absolute 0.01) existingConn.position.y
                            ]
                            ()

                    _ ->
                        Expect.fail "Could not get connectors"
        , test "falls back to origin when connector not found" <|
            \_ ->
                let
                    ( layout, _ ) =
                        placeElementAt (StraightTrack 50) ( ElementId 99, 0 ) emptyLayout
                in
                List.length layout.elements
                    |> Expect.equal 1
        ]


connectTests : Test
connectTests =
    describe "connect"
        [ test "adds connection to layout" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout1, _ ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, _ ) =
                        placeElement TrackEnd c0 layout1

                    layout3 =
                        connect ( ElementId 0, 0 ) ( ElementId 1, 0 ) layout2
                in
                List.length layout3.connections
                    |> Expect.equal 1
        , test "preserves existing connections" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout1, _ ) =
                        placeElement TrackEnd c0 emptyLayout

                    ( layout2, _ ) =
                        placeElement TrackEnd c0 layout1

                    ( layout3, _ ) =
                        placeElement TrackEnd c0 layout2

                    layout4 =
                        connect ( ElementId 0, 0 ) ( ElementId 1, 0 ) layout3

                    layout5 =
                        connect ( ElementId 1, 0 ) ( ElementId 2, 0 ) layout4
                in
                List.length layout5.connections
                    |> Expect.equal 2
        ]


findElementTests : Test
findElementTests =
    describe "findElement"
        [ test "finds existing element" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout, _ ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                case findElement (ElementId 0) layout of
                    Just elem ->
                        elem.id |> Expect.equal (ElementId 0)

                    Nothing ->
                        Expect.fail "Element not found"
        , test "returns Nothing for non-existent element" <|
            \_ ->
                findElement (ElementId 99) emptyLayout
                    |> Expect.equal Nothing
        ]


getConnectorTests : Test
getConnectorTests =
    describe "getConnector"
        [ test "gets connector by element ID and index" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 5 10, orientation = 0 }

                    ( layout, _ ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                case getConnector (ElementId 0) 0 layout of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within (Expect.Absolute 0.01) 5
                            , \_ -> conn.position.y |> Expect.within (Expect.Absolute 0.01) 10
                            ]
                            ()

                    Nothing ->
                        Expect.fail "Connector not found"
        , test "returns Nothing for invalid element ID" <|
            \_ ->
                getConnector (ElementId 99) 0 emptyLayout
                    |> Expect.equal Nothing
        , test "returns Nothing for invalid connector index" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout, _ ) =
                        placeElement TrackEnd c0 emptyLayout
                in
                getConnector (ElementId 0) 5 layout
                    |> Expect.equal Nothing
        ]
