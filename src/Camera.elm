module Camera exposing
    ( Camera
    , CameraMsg(..)
    , CameraState
    , DragState
    , update
    , viewBoxString
    )

{-| Camera state and update logic for pan/zoom.
-}

import Util.Vec2 as Vec2 exposing (Vec2)


{-| Camera position and zoom level.
-}
type alias Camera =
    { center : Vec2 -- World coordinates
    , zoom : Float -- Pixels per meter
    }


{-| Drag state for camera panning.
-}
type alias DragState =
    { startScreenPos : Vec2 -- Screen position where drag started
    , startCameraCenter : Vec2 -- Camera center when drag started
    }


{-| Combined camera state including drag.
-}
type alias CameraState =
    { camera : Camera
    , dragState : Maybe DragState
    }


{-| Camera messages.
-}
type CameraMsg
    = StartDrag Float Float -- Screen x, y where mousedown occurred
    | Drag Float Float -- Current screen x, y during drag
    | EndDrag -- Mouseup or mouseleave
    | Zoom Float Float Float -- deltaY, mouseX, mouseY in screen coords


{-| Update camera state in response to a camera message.
-}
update : { width : Float, height : Float } -> CameraMsg -> CameraState -> CameraState
update viewportSize msg state =
    case msg of
        StartDrag screenX screenY ->
            { state
                | dragState =
                    Just
                        { startScreenPos = Vec2.vec2 screenX screenY
                        , startCameraCenter = state.camera.center
                        }
            }

        Drag screenX screenY ->
            case state.dragState of
                Just drag ->
                    let
                        -- Calculate screen delta
                        deltaScreenX =
                            screenX - drag.startScreenPos.x

                        deltaScreenY =
                            screenY - drag.startScreenPos.y

                        -- Convert to world delta (divide by zoom)
                        deltaWorldX =
                            deltaScreenX / state.camera.zoom

                        deltaWorldY =
                            deltaScreenY / state.camera.zoom

                        -- Move camera opposite to drag direction
                        newCenter =
                            Vec2.vec2
                                (drag.startCameraCenter.x - deltaWorldX)
                                (drag.startCameraCenter.y - deltaWorldY)
                    in
                    { state | camera = { center = newCenter, zoom = state.camera.zoom } }

                Nothing ->
                    state

        EndDrag ->
            { state | dragState = Nothing }

        Zoom deltaY mouseX mouseY ->
            let
                -- Zoom factor: scroll up = zoom in, scroll down = zoom out
                zoomFactor =
                    if deltaY < 0 then
                        1.1

                    else
                        1 / 1.1

                oldZoom =
                    state.camera.zoom

                newZoom =
                    clamp 0.5 10.0 (oldZoom * zoomFactor)

                -- Convert mouse screen position to world coordinates (before zoom)
                halfWidth =
                    viewportSize.width / 2

                halfHeight =
                    viewportSize.height / 2

                worldX =
                    state.camera.center.x + (mouseX - halfWidth) / oldZoom

                worldY =
                    state.camera.center.y + (mouseY - halfHeight) / oldZoom

                -- Adjust camera center so the world point under mouse stays fixed
                newCenterX =
                    worldX - (mouseX - halfWidth) / newZoom

                newCenterY =
                    worldY - (mouseY - halfHeight) / newZoom
            in
            { state | camera = { center = Vec2.vec2 newCenterX newCenterY, zoom = newZoom } }


{-| Calculate SVG viewBox string from camera and viewport size.
-}
viewBoxString : { width : Float, height : Float } -> Camera -> String
viewBoxString viewportSize camera =
    let
        halfWidth =
            viewportSize.width / 2 / camera.zoom

        halfHeight =
            viewportSize.height / 2 / camera.zoom

        minX =
            camera.center.x - halfWidth

        minY =
            camera.center.y - halfHeight

        viewBoxWidth =
            halfWidth * 2

        viewBoxHeight =
            halfHeight * 2
    in
    String.join " "
        [ String.fromFloat minX
        , String.fromFloat minY
        , String.fromFloat viewBoxWidth
        , String.fromFloat viewBoxHeight
        ]
