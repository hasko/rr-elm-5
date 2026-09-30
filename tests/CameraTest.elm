module CameraTest exposing (..)

import Camera exposing (..)
import Expect
import Test exposing (..)
import Util.Vec2 exposing (vec2)



-- FIXTURES


viewport : { width : Float, height : Float }
viewport =
    { width = 800, height = 600 }


initialState : CameraState
initialState =
    { camera = { center = vec2 100 50, zoom = 2.0 }
    , dragState = Nothing
    }


withZoom : Float -> CameraState
withZoom zoom =
    { initialState | camera = { center = initialState.camera.center, zoom = zoom } }


step : CameraMsg -> CameraState -> CameraState
step =
    update viewport


{-| World coordinates of a screen point for the given camera.
-}
screenToWorld : Camera -> Float -> Float -> ( Float, Float )
screenToWorld camera sx sy =
    ( camera.center.x + (sx - viewport.width / 2) / camera.zoom
    , camera.center.y + (sy - viewport.height / 2) / camera.zoom
    )


near : Float -> Float -> Expect.Expectation
near expected actual =
    Expect.within (Expect.Absolute 0.0001) expected actual



-- TESTS


suite : Test
suite =
    describe "Camera"
        [ zoomTests
        , zoomAnchorTests
        , dragTests
        , viewBoxTests
        ]


zoomTests : Test
zoomTests =
    describe "zoom level"
        [ test "scrolling up (negative deltaY) zooms in by 1.1" <|
            \_ ->
                step (Zoom -100 400 300) initialState
                    |> .camera
                    |> .zoom
                    |> near 2.2
        , test "scrolling down (positive deltaY) zooms out by 1/1.1" <|
            \_ ->
                step (Zoom 100 400 300) initialState
                    |> .camera
                    |> .zoom
                    |> near (2.0 / 1.1)
        , test "zero deltaY counts as zooming out" <|
            \_ ->
                step (Zoom 0 400 300) initialState
                    |> .camera
                    |> .zoom
                    |> near (2.0 / 1.1)
        , test "zoom in then out returns to the original zoom" <|
            \_ ->
                initialState
                    |> step (Zoom -100 400 300)
                    |> step (Zoom 100 400 300)
                    |> .camera
                    |> .zoom
                    |> near 2.0
        , test "zoom is clamped at the maximum of 10" <|
            \_ ->
                List.foldl (\_ s -> step (Zoom -100 400 300) s) (withZoom 9.5) (List.range 1 20)
                    |> .camera
                    |> .zoom
                    |> near 10.0
        , test "zoom is clamped at the minimum of 0.5" <|
            \_ ->
                List.foldl (\_ s -> step (Zoom 100 400 300) s) (withZoom 0.6) (List.range 1 20)
                    |> .camera
                    |> .zoom
                    |> near 0.5
        , test "zooming in at max zoom leaves the camera unchanged" <|
            \_ ->
                step (Zoom -100 123 456) (withZoom 10)
                    |> .camera
                    |> Expect.all
                        [ .zoom >> near 10
                        , .center >> .x >> near 100
                        , .center >> .y >> near 50
                        ]
        , test "zooming does not affect drag state" <|
            \_ ->
                initialState
                    |> step (StartDrag 10 10)
                    |> step (Zoom -100 400 300)
                    |> .dragState
                    |> Expect.equal (Just { startScreenPos = vec2 10 10, startCameraCenter = vec2 100 50 })
        ]


zoomAnchorTests : Test
zoomAnchorTests =
    describe "zoom anchored at cursor"
        [ test "zooming at the viewport center keeps the camera center" <|
            \_ ->
                step (Zoom -100 400 300) initialState
                    |> .camera
                    |> .center
                    |> Expect.all
                        [ .x >> near 100
                        , .y >> near 50
                        ]
        , test "zooming in keeps the world point under the cursor fixed" <|
            \_ ->
                let
                    ( beforeX, beforeY ) =
                        screenToWorld initialState.camera 650 120

                    ( afterX, afterY ) =
                        screenToWorld (step (Zoom -100 650 120) initialState).camera 650 120
                in
                Expect.all
                    [ \_ -> near beforeX afterX
                    , \_ -> near beforeY afterY
                    ]
                    ()
        , test "zooming out keeps the world point under the cursor fixed" <|
            \_ ->
                let
                    ( beforeX, beforeY ) =
                        screenToWorld initialState.camera 30 580

                    ( afterX, afterY ) =
                        screenToWorld (step (Zoom 100 30 580) initialState).camera 30 580
                in
                Expect.all
                    [ \_ -> near beforeX afterX
                    , \_ -> near beforeY afterY
                    ]
                    ()
        , test "zooming in off-center moves the camera center toward the cursor" <|
            \_ ->
                step (Zoom -100 700 300) initialState
                    |> .camera
                    |> .center
                    |> .x
                    |> Expect.greaterThan 100
        ]


dragTests : Test
dragTests =
    describe "drag pan"
        [ test "StartDrag records start screen position and camera center" <|
            \_ ->
                step (StartDrag 200 150) initialState
                    |> .dragState
                    |> Expect.equal (Just { startScreenPos = vec2 200 150, startCameraCenter = vec2 100 50 })
        , test "StartDrag does not move the camera" <|
            \_ ->
                step (StartDrag 200 150) initialState
                    |> .camera
                    |> Expect.equal initialState.camera
        , test "dragging moves the camera opposite to the pointer, scaled by zoom" <|
            \_ ->
                initialState
                    |> step (StartDrag 200 150)
                    |> step (Drag 240 130)
                    |> .camera
                    |> .center
                    |> Expect.all
                        [ .x >> near 80 -- 100 - 40/2
                        , .y >> near 60 -- 50 - (-20)/2
                        ]
        , test "successive drags are relative to the drag start" <|
            \_ ->
                initialState
                    |> step (StartDrag 200 150)
                    |> step (Drag 240 130)
                    |> step (Drag 200 150)
                    |> .camera
                    |> .center
                    |> Expect.all
                        [ .x >> near 100
                        , .y >> near 50
                        ]
        , test "dragging keeps the zoom level" <|
            \_ ->
                initialState
                    |> step (StartDrag 200 150)
                    |> step (Drag 0 0)
                    |> .camera
                    |> .zoom
                    |> near 2.0
        , test "Drag without StartDrag does nothing" <|
            \_ ->
                step (Drag 240 130) initialState
                    |> Expect.equal initialState
        , test "EndDrag clears drag state and keeps the panned camera" <|
            \_ ->
                initialState
                    |> step (StartDrag 200 150)
                    |> step (Drag 240 150)
                    |> step EndDrag
                    |> Expect.all
                        [ .dragState >> Expect.equal Nothing
                        , .camera >> .center >> .x >> near 80
                        ]
        , test "Drag after EndDrag is ignored" <|
            \_ ->
                let
                    ended =
                        initialState
                            |> step (StartDrag 200 150)
                            |> step (Drag 240 150)
                            |> step EndDrag
                in
                step (Drag 999 999) ended
                    |> Expect.equal ended
        ]


viewBoxTests : Test
viewBoxTests =
    describe "viewBoxString"
        [ test "centers the view on the camera with size viewport / zoom" <|
            \_ ->
                viewBoxString viewport initialState.camera
                    |> Expect.equal "-100 -100 400 300"
        , test "zoom 1 at origin gives a viewport-sized box centered on the origin" <|
            \_ ->
                viewBoxString viewport { center = vec2 0 0, zoom = 1 }
                    |> Expect.equal "-400 -300 800 600"
        , test "higher zoom shows a smaller area" <|
            \_ ->
                viewBoxString { width = 100, height = 50 } { center = vec2 10 20, zoom = 10 }
                    |> Expect.equal "5 17.5 10 5"
        ]
