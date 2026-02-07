module Programmer.View exposing (viewProgrammerPanel)

{-| View functions for the train programmer panel UI.
-}

import Html exposing (Html, button, div, input, label, option, select, span, text)
import Html.Attributes exposing (attribute, disabled, selected, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode
import Programmer.Types as Programmer
    exposing
        ( Order(..)
        , ProgrammerState
        , ReverserPosition(..)
        , SpotId(..)
        , SpotTarget(..)
        , SwitchPosition(..)
        , orderDescription
        , spotName
        )


{-| Render the entire programmer panel.
-}
viewProgrammerPanel :
    { state : ProgrammerState
    , trainId : Int
    , onBack : msg
    , onSave : msg
    , onAddOrder : Order -> msg
    , onRemoveOrder : Int -> msg
    , onMoveOrderUp : Int -> msg
    , onMoveOrderDown : Int -> msg
    , onSelectOrder : Int -> msg
    }
    -> Html msg
viewProgrammerPanel config =
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
        [ viewHeader config.trainId config.onBack
        , viewProgramList config
        , viewOrderPalette config.onAddOrder
        , viewSaveButton config.onSave
        ]


viewHeader : Int -> msg -> Html msg
viewHeader trainId onBack =
    div
        [ style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "padding" "12px 16px"
        , style "background" "#252540"
        , style "border-bottom" "1px solid #333"
        ]
        [ button
            [ style "background" "#3a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 12px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "14px"
            , onClick onBack
            ]
            [ text "← Back" ]
        , span
            [ style "font-weight" "bold"
            , style "font-size" "16px"
            ]
            [ text ("Train #" ++ String.fromInt trainId ++ " Program") ]
        ]


viewProgramList :
    { a
        | state : ProgrammerState
        , onRemoveOrder : Int -> msg
        , onMoveOrderUp : Int -> msg
        , onMoveOrderDown : Int -> msg
        , onSelectOrder : Int -> msg
    }
    -> Html msg
viewProgramList config =
    let
        program =
            config.state.program

        programLength =
            List.length program
    in
    div
        [ style "padding" "12px 16px"
        , style "border-bottom" "1px solid #333"
        , style "flex" "1"
        , style "overflow-y" "auto"
        , style "min-height" "150px"
        ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "font-size" "12px"
            , style "color" "#888"
            ]
            [ text "PROGRAM" ]
        , if List.isEmpty program then
            div [ style "color" "#666", style "font-style" "italic" ]
                [ text "No orders yet. Add orders below." ]

          else
            div []
                (List.indexedMap
                    (viewOrderItem config.state.selectedOrderIndex programLength config.onRemoveOrder config.onMoveOrderUp config.onMoveOrderDown config.onSelectOrder)
                    program
                )
        ]


viewOrderItem : Maybe Int -> Int -> (Int -> msg) -> (Int -> msg) -> (Int -> msg) -> (Int -> msg) -> Int -> Order -> Html msg
viewOrderItem selectedIndex programLength onRemove onMoveUp onMoveDown onSelect index order =
    let
        isSelected =
            selectedIndex == Just index

        canMoveUp =
            index > 0

        canMoveDown =
            index < programLength - 1
    in
    div
        [ attribute "data-testid" ("order-item-" ++ String.fromInt index)
        , style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "padding" "8px 10px"
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
                "transparent"
            )
        , style "border-radius" "4px"
        , style "margin-bottom" "4px"
        , style "cursor" "pointer"
        , onClick (onSelect index)
        ]
        [ div [ style "display" "flex", style "align-items" "center" ]
            [ span
                [ style "color" "#888"
                , style "margin-right" "10px"
                , style "font-size" "12px"
                , style "min-width" "20px"
                ]
                [ text (String.fromInt (index + 1) ++ ".") ]
            , span [] [ text (orderDescription order) ]
            ]
        , div [ style "display" "flex", style "align-items" "center", style "gap" "4px" ]
            [ button
                [ style "background"
                    (if canMoveUp then
                        "#3a3a5a"

                     else
                        "#2a2a3a"
                    )
                , style "border" "none"
                , style "color"
                    (if canMoveUp then
                        "#e0e0e0"

                     else
                        "#555"
                    )
                , style "padding" "4px 6px"
                , style "border-radius" "2px"
                , style "cursor"
                    (if canMoveUp then
                        "pointer"

                     else
                        "default"
                    )
                , style "font-size" "12px"
                , disabled (not canMoveUp)
                , Html.Events.stopPropagationOn "click"
                    (if canMoveUp then
                        Json.Decode.succeed ( onMoveUp index, True )

                     else
                        Json.Decode.fail ""
                    )
                ]
                [ text "↑" ]
            , button
                [ style "background"
                    (if canMoveDown then
                        "#3a3a5a"

                     else
                        "#2a2a3a"
                    )
                , style "border" "none"
                , style "color"
                    (if canMoveDown then
                        "#e0e0e0"

                     else
                        "#555"
                    )
                , style "padding" "4px 6px"
                , style "border-radius" "2px"
                , style "cursor"
                    (if canMoveDown then
                        "pointer"

                     else
                        "default"
                    )
                , style "font-size" "12px"
                , disabled (not canMoveDown)
                , Html.Events.stopPropagationOn "click"
                    (if canMoveDown then
                        Json.Decode.succeed ( onMoveDown index, True )

                     else
                        Json.Decode.fail ""
                    )
                ]
                [ text "↓" ]
            , button
                [ style "background" "#6a2a2a"
                , style "border" "none"
                , style "color" "#e0e0e0"
                , style "padding" "4px 8px"
                , style "border-radius" "2px"
                , style "cursor" "pointer"
                , style "font-size" "12px"
                , Html.Events.stopPropagationOn "click" (Json.Decode.succeed ( onRemove index, True ))
                ]
                [ text "X" ]
            ]
        ]


viewOrderPalette : (Order -> msg) -> Html msg
viewOrderPalette onAddOrder =
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
            [ text "ADD ORDER" ]
        , div [ style "display" "flex", style "flex-direction" "column", style "gap" "8px" ]
            [ viewMoveToSelector onAddOrder
            , viewReverserSelector onAddOrder
            , viewSwitchSelector onAddOrder
            , viewWaitSecondsSelector onAddOrder
            , viewCoupleSelector onAddOrder
            ]
        ]


viewMoveToSelector : (Order -> msg) -> Html msg
viewMoveToSelector onAddOrder =
    div [ style "display" "flex", style "flex-direction" "column", style "gap" "6px" ]
        [ div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
            [ label [ style "width" "90px", style "font-size" "14px" ] [ text "Move To" ]
            , viewSpotButton PlatformSpot onAddOrder
            , viewSpotButton TeamTrackSpot onAddOrder
            , viewSpotButton EastTunnelSpot onAddOrder
            , viewSpotButton WestTunnelSpot onAddOrder
            ]
        , div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
            [ label [ style "width" "90px", style "font-size" "14px", style "color" "#aaa" ] [ text "Spot Car" ]
            , viewSpotCarButton 0 PlatformSpot onAddOrder
            , viewSpotCarButton 1 PlatformSpot onAddOrder
            , viewSpotCarButton 0 TeamTrackSpot onAddOrder
            , viewSpotCarButton 1 TeamTrackSpot onAddOrder
            ]
        ]


viewSpotButton : SpotId -> (Order -> msg) -> Html msg
viewSpotButton spot onAddOrder =
    button
        [ attribute "data-testid" ("add-moveto-" ++ spotTestId spot)
        , style "background" "#3a5a3a"
        , style "border" "none"
        , style "color" "#e0e0e0"
        , style "padding" "6px 10px"
        , style "border-radius" "4px"
        , style "cursor" "pointer"
        , style "font-size" "12px"
        , onClick (onAddOrder (MoveTo spot TrainHead))
        ]
        [ text (spotShortName spot) ]


viewSpotCarButton : Int -> SpotId -> (Order -> msg) -> Html msg
viewSpotCarButton carIndex spot onAddOrder =
    button
        [ attribute "data-testid" ("add-spotcar-" ++ String.fromInt carIndex ++ "-" ++ spotTestId spot)
        , style "background" "#2a5a3a"
        , style "border" "none"
        , style "color" "#e0e0e0"
        , style "padding" "6px 10px"
        , style "border-radius" "4px"
        , style "cursor" "pointer"
        , style "font-size" "12px"
        , onClick (onAddOrder (MoveTo spot (SpotCar carIndex)))
        ]
        [ text ("#" ++ String.fromInt (carIndex + 1) ++ "@" ++ spotShortName spot) ]


spotShortName : SpotId -> String
spotShortName spot =
    case spot of
        PlatformSpot ->
            "Plat"

        TeamTrackSpot ->
            "Team"

        EastTunnelSpot ->
            "E.Tun"

        WestTunnelSpot ->
            "W.Tun"


spotTestId : SpotId -> String
spotTestId spot =
    case spot of
        PlatformSpot ->
            "platform"

        TeamTrackSpot ->
            "teamtrack"

        EastTunnelSpot ->
            "easttunnel"

        WestTunnelSpot ->
            "westtunnel"


viewReverserSelector : (Order -> msg) -> Html msg
viewReverserSelector onAddOrder =
    div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
        [ label [ style "width" "90px", style "font-size" "14px" ] [ text "Reverser" ]
        , button
            [ attribute "data-testid" "add-reverser-forward"
            , style "background" "#3a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 12px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (SetReverser Forward))
            ]
            [ text "Forward" ]
        , button
            [ attribute "data-testid" "add-reverser-reverse"
            , style "background" "#3a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 12px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (SetReverser Reverse))
            ]
            [ text "Reverse" ]
        ]


viewSwitchSelector : (Order -> msg) -> Html msg
viewSwitchSelector onAddOrder =
    div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
        [ label [ style "width" "90px", style "font-size" "14px" ] [ text "Switch" ]
        , button
            [ attribute "data-testid" "add-switch-main-normal"
            , style "background" "#5a5a3a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (SetSwitch "main" Normal))
            ]
            [ text "Main→N" ]
        , button
            [ attribute "data-testid" "add-switch-main-diverging"
            , style "background" "#5a5a3a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (SetSwitch "main" Diverging))
            ]
            [ text "Main→D" ]
        ]


viewWaitSecondsSelector : (Order -> msg) -> Html msg
viewWaitSecondsSelector onAddOrder =
    div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
        [ label [ style "width" "90px", style "font-size" "14px" ] [ text "Wait" ]
        , button
            [ attribute "data-testid" "add-wait-10"
            , style "background" "#5a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (WaitSeconds 10))
            ]
            [ text "10s" ]
        , button
            [ attribute "data-testid" "add-wait-30"
            , style "background" "#5a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (WaitSeconds 30))
            ]
            [ text "30s" ]
        , button
            [ attribute "data-testid" "add-wait-60"
            , style "background" "#5a3a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (WaitSeconds 60))
            ]
            [ text "60s" ]
        ]


viewCoupleSelector : (Order -> msg) -> Html msg
viewCoupleSelector onAddOrder =
    div [ style "display" "flex", style "gap" "8px", style "align-items" "center" ]
        [ label [ style "width" "90px", style "font-size" "14px" ] [ text "Coupling" ]
        , button
            [ attribute "data-testid" "add-couple"
            , style "background" "#3a5a5a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder Couple)
            ]
            [ text "Couple" ]
        , button
            [ attribute "data-testid" "add-uncouple-1"
            , style "background" "#5a3a3a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (Uncouple 1))
            ]
            [ text "Cut 1" ]
        , button
            [ attribute "data-testid" "add-uncouple-2"
            , style "background" "#5a3a3a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (Uncouple 2))
            ]
            [ text "Cut 2" ]
        , button
            [ attribute "data-testid" "add-uncouple-3"
            , style "background" "#5a3a3a"
            , style "border" "none"
            , style "color" "#e0e0e0"
            , style "padding" "6px 10px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "12px"
            , onClick (onAddOrder (Uncouple 3))
            ]
            [ text "Cut 3" ]
        ]


viewSaveButton : msg -> Html msg
viewSaveButton onSave =
    div
        [ style "padding" "12px 16px"
        ]
        [ button
            [ attribute "data-testid" "save-program-btn"
            , style "width" "100%"
            , style "background" "#4a9eff"
            , style "border" "none"
            , style "color" "#fff"
            , style "padding" "12px"
            , style "border-radius" "4px"
            , style "cursor" "pointer"
            , style "font-size" "14px"
            , style "font-weight" "bold"
            , onClick onSave
            ]
            [ text "Save Program" ]
        ]


