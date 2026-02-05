module Planning.View exposing (viewPlanningPanel)

{-| View functions for the planning panel UI.
-}

import Html exposing (Html, button, div, label, option, select, span, text)
import Html.Attributes exposing (attribute, disabled, id, selected, style, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Planning.Types as Planning
    exposing
        ( ConsistBuilder
        , PanelMode(..)
        , PlanningState
        , ScheduledTrain
        , SpawnPointId(..)
        , SpawnPointInventory
        , StockItem
        , StockType(..)
        )
import Svg exposing (Svg)
import Svg.Attributes as SvgA


{-| Render the entire planning panel.
-}
viewPlanningPanel :
    { state : PlanningState
    , onClose : msg
    , onSelectSpawnPoint : SpawnPointId -> msg
    , onSelectStock : StockItem -> msg
    , onAddToFront : msg
    , onAddToBack : msg
    , onInsertInConsist : Int -> msg
    , onRemoveFromConsist : Int -> msg
    , onClearConsist : msg
    , onSetHour : Int -> msg
    , onSetMinute : Int -> msg
    , onSetDay : Int -> msg
    , onSchedule : msg
    , onRemoveTrain : Int -> msg
    , onSelectTrain : Int -> msg
    , onOpenProgrammer : Int -> msg
    , onReset : msg
    }
    -> Html msg
viewPlanningPanel config =
    div
        [ style "width" "400px"
        , style "background" "#1a1a2e"
        , style "border-left" "2px solid #333"
        , style "display" "flex"
        , style "flex-direction" "column"
        , style "font-family" "sans-serif"
        , style "color" "#e0e0e0"
        , style "overflow-y" "auto"
        ]
        [ viewPanelHeader config.onClose config.onReset
        , viewSpawnPointSelector config.state.selectedSpawnPoint config.onSelectSpawnPoint
        , viewScheduledTrains config.state config.onRemoveTrain config.onSelectTrain config.onOpenProgrammer
        , viewAvailableStock config.state config.onSelectStock
        , viewConsistBuilder config.state.consistBuilder config.onAddToFront config.onAddToBack config.onInsertInConsist config.onRemoveFromConsist config.onClearConsist
        , viewScheduleControls config.state config.onSetDay config.onSetHour config.onSetMinute config.onSchedule config.onOpenProgrammer
        ]


viewPanelHeader : msg -> msg -> Html msg
viewPanelHeader onClose onReset =
    div
        [ style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "padding" "12px 16px"
        , style "background" "#252540"
        , style "border-bottom" "1px solid #333"
        ]
        [ span
            [ style "font-weight" "bold"
            , style "font-size" "16px"
            ]
            [ text "Train Planning" ]
        , div
            [ style "display" "flex"
            , style "gap" "8px"
            , style "align-items" "center"
            ]
            [ button
                [ style "background" "#4a3030"
                , style "border" "1px solid #6a4040"
                , style "color" "#e0e0e0"
                , style "font-size" "12px"
                , style "cursor" "pointer"
                , style "padding" "4px 8px"
                , style "border-radius" "4px"
                , onClick onReset
                ]
                [ text "Start Fresh" ]
            , button
                [ attribute "data-testid" "close-planning-panel"
                , style "background" "transparent"
                , style "border" "none"
                , style "color" "#e0e0e0"
                , style "font-size" "20px"
                , style "cursor" "pointer"
                , style "padding" "4px 8px"
                , onClick onClose
                ]
                [ text "X" ]
            ]
        ]


viewSpawnPointSelector : SpawnPointId -> (SpawnPointId -> msg) -> Html msg
viewSpawnPointSelector selected onSelect =
    div
        [ style "padding" "12px 16px"
        , style "border-bottom" "1px solid #333"
        ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "font-size" "12px"
            , style "color" "#888"
            ]
            [ text "STATION" ]
        , div [ style "display" "flex", style "gap" "8px" ]
            [ viewSpawnPointButton EastStation "East Station" selected onSelect
            , viewSpawnPointButton WestStation "West Station" selected onSelect
            ]
        ]


viewSpawnPointButton : SpawnPointId -> String -> SpawnPointId -> (SpawnPointId -> msg) -> Html msg
viewSpawnPointButton spawnId labelText selected onSelect =
    let
        isSelected =
            spawnId == selected
    in
    button
        [ style "flex" "1"
        , style "padding" "8px 12px"
        , style "border" "2px solid"
        , style "border-color"
            (if isSelected then
                "#4a9eff"

             else
                "#444"
            )
        , style "background"
            (if isSelected then
                "#2a4a6e"

             else
                "#252540"
            )
        , style "color" "#e0e0e0"
        , style "border-radius" "4px"
        , style "cursor" "pointer"
        , onClick (onSelect spawnId)
        ]
        [ text labelText ]


viewScheduledTrains : PlanningState -> (Int -> msg) -> (Int -> msg) -> (Int -> msg) -> Html msg
viewScheduledTrains state onRemove onSelect onOpenProgrammer =
    let
        trainsForSpawnPoint =
            state.scheduledTrains
                |> List.filter (\t -> t.spawnPoint == state.selectedSpawnPoint)
                |> List.sortBy (\t -> t.departureTime.day * 1440 + t.departureTime.hour * 60 + t.departureTime.minute)
    in
    div
        [ style "padding" "12px 16px"
        , style "border-bottom" "1px solid #333"
        , style "max-height" "150px"
        , style "overflow-y" "auto"
        ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "font-size" "12px"
            , style "color" "#888"
            ]
            [ text "SCHEDULED TRAINS" ]
        , if List.isEmpty trainsForSpawnPoint then
            div [ style "color" "#666", style "font-style" "italic" ]
                [ text "No trains scheduled" ]

          else
            div [] (List.map (viewScheduledTrainItem onRemove onSelect onOpenProgrammer state.editingTrainId) trainsForSpawnPoint)
        ]


viewScheduledTrainItem : (Int -> msg) -> (Int -> msg) -> (Int -> msg) -> Maybe Int -> ScheduledTrain -> Html msg
viewScheduledTrainItem onRemove onSelect onOpenProgrammer editingId train =
    let
        isEditing =
            editingId == Just train.id

        locoCount =
            List.length (List.filter (\item -> item.stockType == Locomotive) train.consist)

        carCount =
            List.length (List.filter (\item -> item.stockType /= Locomotive) train.consist)

        consistDescription =
            if locoCount > 0 && carCount > 0 then
                String.fromInt locoCount ++ " loco + " ++ String.fromInt carCount ++ " cars"

            else if locoCount > 0 then
                String.fromInt locoCount ++ " loco"

            else
                String.fromInt carCount ++ " cars"

        programButton =
            if isEditing then
                button
                    [ attribute "data-testid" ("program-btn-" ++ String.fromInt train.id)
                    , style "background" "#4a6a8a"
                    , style "border" "none"
                    , style "color" "#e0e0e0"
                    , style "padding" "4px 8px"
                    , style "border-radius" "2px"
                    , style "cursor" "pointer"
                    , style "margin-right" "8px"
                    , Html.Events.stopPropagationOn "click" (Decode.succeed ( onOpenProgrammer train.id, True ))
                    ]
                    [ text "Program" ]

            else
                text ""
    in
    div
        [ attribute "data-testid" ("train-row-" ++ String.fromInt train.id)
        , style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "padding" "6px 8px"
        , style "background"
            (if isEditing then
                "#2a4a6e"

             else
                "#252540"
            )
        , style "border" "2px solid"
        , style "border-color"
            (if isEditing then
                "#4a9eff"

             else
                "transparent"
            )
        , style "border-radius" "4px"
        , style "margin-bottom" "4px"
        , style "cursor" "pointer"
        , onClick (onSelect train.id)
        ]
        [ div []
            [ span [ style "font-weight" "bold" ]
                [ text (formatDepartureTime train.departureTime) ]
            , span [ style "color" "#888", style "margin-left" "8px" ]
                [ text consistDescription ]
            ]
        , div [ style "display" "flex", style "align-items" "center" ]
            [ programButton
            , button
                [ style "background" "#6a2a2a"
                , style "border" "none"
                , style "color" "#e0e0e0"
                , style "padding" "4px 8px"
                , style "border-radius" "2px"
                , style "cursor" "pointer"
                , Html.Events.stopPropagationOn "click" (Decode.succeed ( onRemove train.id, True ))
                ]
                [ text "X" ]
            ]
        ]


formatDepartureTime : Planning.DepartureTime -> String
formatDepartureTime time =
    let
        dayName =
            case time.day of
                0 ->
                    "Mon"

                1 ->
                    "Tue"

                2 ->
                    "Wed"

                3 ->
                    "Thu"

                _ ->
                    "Fri"

        hourStr =
            String.padLeft 2 '0' (String.fromInt time.hour)

        minuteStr =
            String.padLeft 2 '0' (String.fromInt time.minute)
    in
    dayName ++ " " ++ hourStr ++ ":" ++ minuteStr


viewAvailableStock : PlanningState -> (StockItem -> msg) -> Html msg
viewAvailableStock state onSelectStock =
    let
        inventory =
            state.inventories
                |> List.filter (\inv -> inv.spawnPointId == state.selectedSpawnPoint)
                |> List.head
                |> Maybe.map .availableStock
                |> Maybe.withDefault []

        -- Group by type and count
        stockCounts =
            groupAndCountStock inventory
    in
    div
        [ style "padding" "12px 16px"
        , style "border-bottom" "1px solid #333"
        ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "font-size" "12px"
            , style "color" "#888"
            ]
            [ text "AVAILABLE STOCK" ]
        , div
            [ style "display" "flex"
            , style "gap" "12px"
            , style "flex-wrap" "wrap"
            ]
            (List.map (viewStockTypeItem state.consistBuilder.selectedStock onSelectStock) stockCounts)
        ]


{-| Group stock items by type and return (type, count, representative item).
-}
groupAndCountStock : List StockItem -> List ( StockType, Int, StockItem )
groupAndCountStock items =
    let
        stockTypes =
            [ Locomotive, PassengerCar, Flatbed, Boxcar ]

        countType stockType =
            let
                matching =
                    List.filter (\s -> s.stockType == stockType) items
            in
            case matching of
                first :: _ ->
                    Just ( stockType, List.length matching, first )

                [] ->
                    Nothing
    in
    List.filterMap countType stockTypes


viewStockTypeItem : Maybe StockItem -> (StockItem -> msg) -> ( StockType, Int, StockItem ) -> Html msg
viewStockTypeItem selectedItem onSelect ( stockType, count, representative ) =
    let
        isSelected =
            case selectedItem of
                Just sel ->
                    sel.stockType == stockType

                Nothing ->
                    False
    in
    div
        [ attribute "data-testid" ("stock-" ++ stockTypeTestId stockType)
        , style "position" "relative"
        , style "cursor" "pointer"
        , style "padding" "8px"
        , style "background"
            (if isSelected then
                "#2a4a6e"

             else
                "#252540"
            )
        , style "border" "2px solid"
        , style "border-color"
            (if isSelected then
                "#4a9eff"

             else
                "#444"
            )
        , style "border-radius" "4px"
        , onClick (onSelect representative)
        ]
        [ viewStockSideProfile stockType
        , div
            [ style "position" "absolute"
            , style "top" "-8px"
            , style "right" "-8px"
            , style "background" "#4a9eff"
            , style "color" "#fff"
            , style "border-radius" "50%"
            , style "width" "20px"
            , style "height" "20px"
            , style "display" "flex"
            , style "align-items" "center"
            , style "justify-content" "center"
            , style "font-size" "12px"
            , style "font-weight" "bold"
            ]
            [ text (String.fromInt count) ]
        ]


stockTypeTestId : StockType -> String
stockTypeTestId stockType =
    case stockType of
        Locomotive ->
            "locomotive"

        PassengerCar ->
            "passenger"

        Flatbed ->
            "flatbed"

        Boxcar ->
            "boxcar"


viewStockSideProfile : StockType -> Html msg
viewStockSideProfile stockType =
    Svg.svg
        [ SvgA.width "60"
        , SvgA.height "30"
        , SvgA.viewBox "0 0 60 30"
        ]
        (case stockType of
            Locomotive ->
                [ Svg.rect [ SvgA.x "5", SvgA.y "5", SvgA.width "50", SvgA.height "18", SvgA.fill "#4a6a8a", SvgA.rx "2" ] []
                , Svg.rect [ SvgA.x "40", SvgA.y "2", SvgA.width "12", SvgA.height "8", SvgA.fill "#3a5a7a" ] []
                , Svg.circle [ SvgA.cx "15", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                , Svg.circle [ SvgA.cx "45", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                ]

            PassengerCar ->
                [ Svg.rect [ SvgA.x "2", SvgA.y "6", SvgA.width "56", SvgA.height "14", SvgA.fill "#8a6a4a", SvgA.rx "2" ] []
                , Svg.rect [ SvgA.x "8", SvgA.y "8", SvgA.width "8", SvgA.height "8", SvgA.fill "#aaa" ] []
                , Svg.rect [ SvgA.x "26", SvgA.y "8", SvgA.width "8", SvgA.height "8", SvgA.fill "#aaa" ] []
                , Svg.rect [ SvgA.x "44", SvgA.y "8", SvgA.width "8", SvgA.height "8", SvgA.fill "#aaa" ] []
                , Svg.circle [ SvgA.cx "12", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                , Svg.circle [ SvgA.cx "48", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                ]

            Flatbed ->
                [ -- Deck
                  Svg.rect [ SvgA.x "2", SvgA.y "14", SvgA.width "56", SvgA.height "6", SvgA.fill "#6a5a4a" ] []

                -- Rungen (stakes) - 8 equally spaced, outermost at corners
                -- Deck spans x=2 to x=58, stakes at: 2, 10, 18, 26, 34, 42, 50, 58 (spacing = 8)
                , Svg.rect [ SvgA.x "2", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "10", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "18", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "26", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "34", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "42", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "50", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []
                , Svg.rect [ SvgA.x "56", SvgA.y "4", SvgA.width "2", SvgA.height "10", SvgA.fill "#4a4a4a" ] []

                -- Wheels
                , Svg.circle [ SvgA.cx "12", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                , Svg.circle [ SvgA.cx "48", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                ]

            Boxcar ->
                [ Svg.rect [ SvgA.x "2", SvgA.y "4", SvgA.width "56", SvgA.height "16", SvgA.fill "#8a4a4a", SvgA.rx "2" ] []
                , Svg.rect [ SvgA.x "22", SvgA.y "6", SvgA.width "16", SvgA.height "12", SvgA.fill "#6a3a3a" ] []
                , Svg.circle [ SvgA.cx "12", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                , Svg.circle [ SvgA.cx "48", SvgA.cy "26", SvgA.r "4", SvgA.fill "#333" ] []
                ]
        )


getItemAt : Int -> List a -> Maybe a
getItemAt index list =
    list
        |> List.drop index
        |> List.head


viewConsistBuilder : ConsistBuilder -> msg -> msg -> (Int -> msg) -> (Int -> msg) -> msg -> Html msg
viewConsistBuilder builder onAddFront onAddBack onInsert onRemove onClear =
    let
        hasSelection =
            builder.selectedStock /= Nothing

        items =
            builder.items
    in
    div
        [ style "padding" "12px 16px"
        , style "border-bottom" "1px solid #333"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-bottom" "8px"
            ]
            [ label
                [ style "font-size" "12px"
                , style "color" "#888"
                ]
                [ text "CONSIST BUILDER" ]
            , button
                [ style "background" "#444"
                , style "border" "none"
                , style "color" "#e0e0e0"
                , style "padding" "4px 8px"
                , style "border-radius" "2px"
                , style "cursor" "pointer"
                , style "font-size" "11px"
                , onClick onClear
                ]
                [ text "Clear" ]
            ]
        , div
            [ attribute "data-testid" "consist-area"
            , style "display" "flex"
            , style "gap" "4px"
            , style "padding" "8px"
            , style "background" "#151520"
            , style "border-radius" "4px"
            , style "min-height" "50px"
            , style "align-items" "center"
            , style "justify-content"
                (if List.isEmpty items then
                    "center"

                 else
                    "flex-start"
                )
            ]
            (if List.isEmpty items then
                -- Single centered + button when empty
                [ viewAddButton hasSelection onAddBack ]

             else
                -- [+] [item] [+] [item] [+] ... [+]
                [ viewAddButton hasSelection onAddFront ]
                    ++ List.concatMap
                        (\index ->
                            case getItemAt index items of
                                Just item ->
                                    [ viewConsistItem onRemove index item
                                    , viewAddButton hasSelection (onInsert (index + 1))
                                    ]

                                Nothing ->
                                    []
                        )
                        (List.range 0 (List.length items - 1))
            )
        , case builder.selectedStock of
            Just stock ->
                div
                    [ style "margin-top" "8px"
                    , style "color" "#4a9eff"
                    , style "font-size" "12px"
                    ]
                    [ text ("Selected: " ++ Planning.stockTypeName stock.stockType ++ " - click + to add") ]

            Nothing ->
                div
                    [ style "margin-top" "8px"
                    , style "color" "#666"
                    , style "font-size" "12px"
                    ]
                    [ text "Select stock from above to add to consist" ]
        ]


viewAddButton : Bool -> msg -> Html msg
viewAddButton enabled onAdd =
    button
        [ style "width" "36px"
        , style "height" "40px"
        , style "border" "2px dashed"
        , style "border-color"
            (if enabled then
                "#4a9eff"

             else
                "#444"
            )
        , style "border-radius" "4px"
        , style "background" "transparent"
        , style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        , style "cursor"
            (if enabled then
                "pointer"

             else
                "default"
            )
        , style "flex-shrink" "0"
        , onClick onAdd
        ]
        [ span
            [ style "color"
                (if enabled then
                    "#4a9eff"

                 else
                    "#444"
                )
            , style "font-size" "20px"
            ]
            [ text "+" ]
        ]


viewConsistItem : (Int -> msg) -> Int -> StockItem -> Html msg
viewConsistItem onRemove index item =
    div
        [ attribute "data-testid" ("consist-item-" ++ stockTypeTestId item.stockType)
        , style "position" "relative"
        , style "flex-shrink" "0"
        ]
        [ div
            [ style "width" "60px"
            , style "height" "40px"
            , style "border" "2px solid #555"
            , style "border-radius" "4px"
            , style "display" "flex"
            , style "align-items" "center"
            , style "justify-content" "center"
            , style "background" "#252540"
            ]
            [ viewStockSideProfile item.stockType ]
        , button
            [ style "position" "absolute"
            , style "top" "-6px"
            , style "right" "-6px"
            , style "width" "18px"
            , style "height" "18px"
            , style "border-radius" "50%"
            , style "background" "#6a2a2a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "font-size" "10px"
            , style "cursor" "pointer"
            , style "display" "flex"
            , style "align-items" "center"
            , style "justify-content" "center"
            , style "padding" "0"
            , onClick (onRemove index)
            ]
            [ text "X" ]
        ]


viewScheduleControls : PlanningState -> (Int -> msg) -> (Int -> msg) -> (Int -> msg) -> msg -> (Int -> msg) -> Html msg
viewScheduleControls state onSetDay onSetHour onSetMinute onSchedule onOpenProgrammer =
    let
        items =
            state.consistBuilder.items

        hasLoco =
            List.any (\item -> item.stockType == Locomotive) items

        isValid =
            not (List.isEmpty items) && hasLoco

        editingTrainId =
            state.editingTrainId

        isEditing =
            editingTrainId /= Nothing

        buttonText =
            if isEditing then
                "Update Train"

            else
                "Schedule Train"

        hintText =
            if List.isEmpty items then
                Just "Add stock to consist first"

            else if not hasLoco then
                Just "Consist needs a locomotive"

            else
                Nothing

        programButton =
            case editingTrainId of
                Just trainId ->
                    button
                        [ attribute "data-testid" ("program-btn-" ++ String.fromInt trainId)
                        , style "width" "100%"
                        , style "padding" "12px"
                        , style "background" "#4a6a8a"
                        , style "border" "none"
                        , style "color" "#fff"
                        , style "border-radius" "4px"
                        , style "cursor" "pointer"
                        , style "font-weight" "bold"
                        , style "font-size" "14px"
                        , style "margin-bottom" "8px"
                        , onClick (onOpenProgrammer trainId)
                        ]
                        [ text "Program" ]

                Nothing ->
                    text ""
    in
    div
        [ style "padding" "12px 16px"
        , style "background" "#252540"
        ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "font-size" "12px"
            , style "color" "#888"
            ]
            [ text "DEPARTURE TIME" ]
        , div
            [ style "display" "flex"
            , style "gap" "8px"
            , style "margin-bottom" "12px"
            ]
            [ viewDayPicker state.timePickerDay onSetDay
            , viewTimePicker state.timePickerHour state.timePickerMinute onSetHour onSetMinute
            ]
        , programButton
        , button
            [ id "schedule-button"
            , attribute "data-testid" "schedule-button"
            , style "width" "100%"
            , style "padding" "12px"
            , style "background"
                (if isValid then
                    "#4a9eff"

                 else
                    "#555"
                )
            , style "border" "none"
            , style "color"
                (if isValid then
                    "#fff"

                 else
                    "#888"
                )
            , style "border-radius" "4px"
            , style "cursor"
                (if isValid then
                    "pointer"

                 else
                    "not-allowed"
                )
            , style "font-weight" "bold"
            , style "font-size" "14px"
            , disabled (not isValid)
            , onClick onSchedule
            ]
            [ text buttonText ]
        , case hintText of
            Just hint ->
                div
                    [ style "margin-top" "8px"
                    , style "font-size" "12px"
                    , style "color" "#888"
                    , style "text-align" "center"
                    ]
                    [ text hint ]

            Nothing ->
                text ""
        ]


viewDayPicker : Int -> (Int -> msg) -> Html msg
viewDayPicker selectedDay onSetDay =
    select
        [ style "padding" "8px"
        , style "background" "#1a1a2e"
        , style "border" "1px solid #444"
        , style "color" "#e0e0e0"
        , style "border-radius" "4px"
        , onInput (\s -> onSetDay (String.toInt s |> Maybe.withDefault 0))
        ]
        [ option [ value "0", selected (selectedDay == 0) ] [ text "Mon" ]
        , option [ value "1", selected (selectedDay == 1) ] [ text "Tue" ]
        , option [ value "2", selected (selectedDay == 2) ] [ text "Wed" ]
        , option [ value "3", selected (selectedDay == 3) ] [ text "Thu" ]
        , option [ value "4", selected (selectedDay == 4) ] [ text "Fri" ]
        ]


viewTimePicker : Int -> Int -> (Int -> msg) -> (Int -> msg) -> Html msg
viewTimePicker hour minute onSetHour onSetMinute =
    div [ style "display" "flex", style "gap" "4px" ]
        [ select
            [ style "padding" "8px"
            , style "background" "#1a1a2e"
            , style "border" "1px solid #444"
            , style "color" "#e0e0e0"
            , style "border-radius" "4px"
            , style "width" "60px"
            , onInput (\s -> onSetHour (String.toInt s |> Maybe.withDefault 0))
            ]
            (List.range 0 23
                |> List.map
                    (\h ->
                        option
                            [ value (String.fromInt h)
                            , selected (h == hour)
                            ]
                            [ text (String.padLeft 2 '0' (String.fromInt h)) ]
                    )
            )
        , span [ style "padding" "8px 0", style "color" "#e0e0e0" ] [ text ":" ]
        , select
            [ style "padding" "8px"
            , style "background" "#1a1a2e"
            , style "border" "1px solid #444"
            , style "color" "#e0e0e0"
            , style "border-radius" "4px"
            , style "width" "60px"
            , onInput (\s -> onSetMinute (String.toInt s |> Maybe.withDefault 0))
            ]
            (List.range 0 59
                |> List.map
                    (\m ->
                        option
                            [ value (String.fromInt m)
                            , selected (m == minute)
                            ]
                            [ text (String.padLeft 2 '0' (String.fromInt m)) ]
                    )
            )
        ]
