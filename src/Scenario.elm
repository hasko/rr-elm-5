module Scenario exposing
    ( Goal
    , NodeType(..)
    , Scenario
    , Segment(..)
    , Spot
    , Station
    , StockEntry
    , TrackEdge
    , TrackGraph
    , TrackNode
    , TurnoutProps
    , decoder
    , edgeDecoder
    , goalDecoder
    , nodeDecoder
    , segmentDecoder
    , stationDecoder
    )

import Json.Decode as Decode exposing (Decoder)


{-| A complete scenario loaded from JSON.
-}
type alias Scenario =
    { name : String
    , description : String
    , startTime : String
    , endTime : String
    , track : TrackGraph
    , stations : List Station
    , goals : List Goal
    }


type alias TrackGraph =
    { nodes : List TrackNode
    , edges : List TrackEdge
    }


type alias TrackNode =
    { id : String
    , nodeType : NodeType
    }


type NodeType
    = Portal
    | Turnout TurnoutProps
    | Buffer


type alias TurnoutProps =
    { hand : String
    , radius : Float
    , sweep : Float
    , throughLength : Float
    , initialState : String
    }


type alias TrackEdge =
    { from : String
    , to : String
    , segments : List Segment
    , port_ : Maybe String
    , spots : List Spot
    }


type Segment
    = StraightSegment Float
    | CurveSegment { radius : Float, sweep : Float }


type alias Spot =
    { id : String
    , at : Float
    , name : String
    }


type alias Station =
    { id : String
    , name : String
    , portal : String
    , stock : List StockEntry
    }


type alias StockEntry =
    { stockType : String
    , count : Int
    }


type alias Goal =
    { what : String
    , at : String
    , from : Maybe String
    , flavor : String
    }



-- DECODERS


decoder : Decoder Scenario
decoder =
    Decode.map7 Scenario
        (Decode.field "name" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "startTime" Decode.string)
        (Decode.field "endTime" Decode.string)
        (Decode.field "track" trackGraphDecoder)
        (Decode.field "stations" (Decode.list stationDecoder))
        (Decode.field "goals" (Decode.list goalDecoder))


trackGraphDecoder : Decoder TrackGraph
trackGraphDecoder =
    Decode.map2 TrackGraph
        (Decode.field "nodes" (Decode.list nodeDecoder))
        (Decode.field "edges" (Decode.list edgeDecoder))


nodeDecoder : Decoder TrackNode
nodeDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\typeStr ->
                case typeStr of
                    "portal" ->
                        Decode.map2 TrackNode
                            (Decode.field "id" Decode.string)
                            (Decode.succeed Portal)

                    "turnout" ->
                        Decode.map2 TrackNode
                            (Decode.field "id" Decode.string)
                            (Decode.map5 TurnoutProps
                                (Decode.field "hand" Decode.string)
                                (Decode.field "radius" Decode.float)
                                (Decode.field "sweep" Decode.float)
                                (Decode.field "throughLength" Decode.float)
                                (Decode.field "initialState" Decode.string
                                    |> Decode.maybe
                                    |> Decode.map (Maybe.withDefault "through")
                                )
                                |> Decode.map Turnout
                            )

                    "buffer" ->
                        Decode.map2 TrackNode
                            (Decode.field "id" Decode.string)
                            (Decode.succeed Buffer)

                    other ->
                        Decode.fail ("Unknown node type: " ++ other)
            )


segmentDecoder : Decoder Segment
segmentDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\typeStr ->
                case typeStr of
                    "straight" ->
                        Decode.map StraightSegment
                            (Decode.field "length" Decode.float)

                    "curve" ->
                        Decode.map2 (\r s -> CurveSegment { radius = r, sweep = s })
                            (Decode.field "radius" Decode.float)
                            (Decode.field "sweep" Decode.float)

                    other ->
                        Decode.fail ("Unknown segment type: " ++ other)
            )


edgeDecoder : Decoder TrackEdge
edgeDecoder =
    Decode.map5 TrackEdge
        (Decode.field "from" Decode.string)
        (Decode.field "to" Decode.string)
        (Decode.field "segments" (Decode.list segmentDecoder))
        (Decode.maybe (Decode.field "port" Decode.string))
        (Decode.maybe (Decode.field "spots" (Decode.list spotDecoder))
            |> Decode.map (Maybe.withDefault [])
        )


spotDecoder : Decoder Spot
spotDecoder =
    Decode.map3 Spot
        (Decode.field "id" Decode.string)
        (Decode.field "at" Decode.float)
        (Decode.field "name" Decode.string)


stationDecoder : Decoder Station
stationDecoder =
    Decode.map4 Station
        (Decode.field "id" Decode.string)
        (Decode.field "name" Decode.string)
        (Decode.field "portal" Decode.string)
        (Decode.field "stock" (Decode.list stockEntryDecoder))


stockEntryDecoder : Decoder StockEntry
stockEntryDecoder =
    Decode.map2 StockEntry
        (Decode.field "type" Decode.string)
        (Decode.field "count" Decode.int)


goalDecoder : Decoder Goal
goalDecoder =
    Decode.map4 Goal
        (Decode.field "what" Decode.string)
        (Decode.field "at" Decode.string)
        (Decode.maybe (Decode.field "from" Decode.string))
        (Decode.field "flavor" Decode.string)
