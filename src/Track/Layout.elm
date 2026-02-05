module Track.Layout exposing
    ( Connection
    , Layout
    , connect
    , emptyLayout
    , findConnected
    , findElement
    , getConnector
    , placeElement
    , placeElementAt
    )

{-| Track layout structure and builder functions.

A layout is a flat list of placed elements with explicit connections.
This allows flexibility during planning mode where tracks may have loose ends.

-}

import Array
import Track.Element as Element
    exposing
        ( Connector
        , ConnectorIndex
        , ElementId(..)
        , PlacedElement
        , TrackElementType
        )


{-| A connection between two element connectors.
-}
type alias Connection =
    { from : ( ElementId, ConnectorIndex )
    , to : ( ElementId, ConnectorIndex )
    }


{-| A complete track layout.
-}
type alias Layout =
    { elements : List PlacedElement
    , connections : List Connection
    , nextId : Int
    }


{-| Create an empty layout.
-}
emptyLayout : Layout
emptyLayout =
    { elements = []
    , connections = []
    , nextId = 0
    }


{-| Place a new element at the given connector 0 position/orientation.
Returns the updated layout and the new element's ID.
-}
placeElement : TrackElementType -> Connector -> Layout -> ( Layout, ElementId )
placeElement elementType connector0 layout =
    let
        newId =
            ElementId layout.nextId

        connectors =
            Element.computeConnectors connector0 elementType

        element =
            { id = newId
            , elementType = elementType
            , connectors = connectors
            }
    in
    ( { layout
        | elements = layout.elements ++ [ element ]
        , nextId = layout.nextId + 1
      }
    , newId
    )


{-| Place a new element connected to an existing element's connector.
The new element's connector 0 will be positioned to match the specified connector.
Returns the updated layout (with connection added) and the new element's ID.
-}
placeElementAt :
    TrackElementType
    -> ( ElementId, ConnectorIndex )
    -> Layout
    -> ( Layout, ElementId )
placeElementAt elementType ( existingId, connectorIdx ) layout =
    case getConnector existingId connectorIdx layout of
        Just existingConnector ->
            let
                -- New element's connector 0 faces opposite to existing connector
                newConnector0 =
                    { position = existingConnector.position
                    , orientation = Element.flipOrientation existingConnector.orientation
                    }

                ( layoutWithElement, newId ) =
                    placeElement elementType newConnector0 layout

                -- Add connection
                connection =
                    { from = ( existingId, connectorIdx )
                    , to = ( newId, 0 )
                    }
            in
            ( { layoutWithElement
                | connections = layoutWithElement.connections ++ [ connection ]
              }
            , newId
            )

        Nothing ->
            -- Connector not found, just place at origin as fallback
            placeElement elementType { position = { x = 0, y = 0 }, orientation = 0 } layout


{-| Connect two element connectors.
-}
connect : ( ElementId, ConnectorIndex ) -> ( ElementId, ConnectorIndex ) -> Layout -> Layout
connect from to layout =
    { layout
        | connections = layout.connections ++ [ { from = from, to = to } ]
    }


{-| Find an element by ID.
-}
findElement : ElementId -> Layout -> Maybe PlacedElement
findElement targetId layout =
    layout.elements
        |> List.filter (\e -> e.id == targetId)
        |> List.head


{-| Get a specific connector from an element.
-}
getConnector : ElementId -> ConnectorIndex -> Layout -> Maybe Connector
getConnector elementId connectorIdx layout =
    findElement elementId layout
        |> Maybe.andThen (\e -> Array.get connectorIdx e.connectors)


{-| Find what a connector is connected to via the connection graph.
Connections are bidirectional: if A->B exists, querying B returns A.
Returns the (elementId, connectorIndex) of the connected endpoint.
-}
findConnected : ElementId -> ConnectorIndex -> Layout -> Maybe ( ElementId, ConnectorIndex )
findConnected elementId connIdx layout =
    let
        needle =
            ( elementId, connIdx )

        search connections =
            case connections of
                [] ->
                    Nothing

                conn :: rest ->
                    if conn.from == needle then
                        Just conn.to

                    else if conn.to == needle then
                        Just conn.from

                    else
                        search rest
    in
    search layout.connections
