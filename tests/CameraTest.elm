module CameraTest exposing (..)

import Camera exposing (Camera, ZoomConfig, defaultZoomConfig, init, zoomAtPoint)
import Expect exposing (FloatingPointTolerance(..))
import Test exposing (..)
import Util.Vec2 as Vec2


suite : Test
suite =
    describe "Camera"
        [ describe "init"
            [ test "creates camera with given center and zoom" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 10 20) 2.5
                    in
                    Expect.all
                        [ \c -> Expect.within (Absolute 0.001) 10 c.center.x
                        , \c -> Expect.within (Absolute 0.001) 20 c.center.y
                        , \c -> Expect.within (Absolute 0.001) 2.5 c.zoom
                        ]
                        camera
            ]
        , describe "defaultZoomConfig"
            [ test "has sensible min zoom" <|
                \_ ->
                    Expect.within (Absolute 0.001) 0.5 defaultZoomConfig.minZoom
            , test "has sensible max zoom" <|
                \_ ->
                    Expect.within (Absolute 0.001) 10.0 defaultZoomConfig.maxZoom
            , test "has sensible zoom factor" <|
                \_ ->
                    Expect.within (Absolute 0.001) 1.15 defaultZoomConfig.zoomFactor
            ]
        , describe "zoomAtPoint"
            [ test "zoom in (negative deltaY) increases zoom level" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 0 0) 2.0

                        mouseOffset =
                            Vec2.vec2 0 0

                        newCamera =
                            zoomAtPoint defaultZoomConfig -100 mouseOffset camera
                    in
                    Expect.greaterThan camera.zoom newCamera.zoom
            , test "zoom out (positive deltaY) decreases zoom level" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 0 0) 2.0

                        mouseOffset =
                            Vec2.vec2 0 0

                        newCamera =
                            zoomAtPoint defaultZoomConfig 100 mouseOffset camera
                    in
                    Expect.lessThan camera.zoom newCamera.zoom
            , test "zoom at center keeps center fixed" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 50 50) 2.0

                        -- Mouse at center (offset = 0, 0)
                        mouseOffset =
                            Vec2.vec2 0 0

                        newCamera =
                            zoomAtPoint defaultZoomConfig -100 mouseOffset camera
                    in
                    Expect.all
                        [ \c -> Expect.within (Absolute 0.001) 50 c.center.x
                        , \c -> Expect.within (Absolute 0.001) 50 c.center.y
                        ]
                        newCamera
            , test "zoom respects minimum zoom level" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 0 0) 0.6 -- Close to min

                        mouseOffset =
                            Vec2.vec2 0 0

                        -- Zoom out many times
                        zoomOut c =
                            zoomAtPoint defaultZoomConfig 100 mouseOffset c

                        newCamera =
                            camera |> zoomOut |> zoomOut |> zoomOut |> zoomOut |> zoomOut
                    in
                    Expect.within (Absolute 0.001) defaultZoomConfig.minZoom newCamera.zoom
            , test "zoom respects maximum zoom level" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 0 0) 9.0 -- Close to max

                        mouseOffset =
                            Vec2.vec2 0 0

                        -- Zoom in many times
                        zoomIn c =
                            zoomAtPoint defaultZoomConfig -100 mouseOffset c

                        newCamera =
                            camera |> zoomIn |> zoomIn |> zoomIn |> zoomIn |> zoomIn
                    in
                    Expect.within (Absolute 0.001) defaultZoomConfig.maxZoom newCamera.zoom
            , test "zoom at offset keeps world point under cursor fixed" <|
                \_ ->
                    let
                        camera =
                            init (Vec2.vec2 100 100) 2.0

                        -- Mouse offset from center
                        mouseOffset =
                            Vec2.vec2 50 50

                        -- Calculate world point under mouse before zoom
                        worldXBefore =
                            camera.center.x + mouseOffset.x / camera.zoom

                        worldYBefore =
                            camera.center.y + mouseOffset.y / camera.zoom

                        newCamera =
                            zoomAtPoint defaultZoomConfig -100 mouseOffset camera

                        -- Calculate world point under mouse after zoom
                        worldXAfter =
                            newCamera.center.x + mouseOffset.x / newCamera.zoom

                        worldYAfter =
                            newCamera.center.y + mouseOffset.y / newCamera.zoom
                    in
                    Expect.all
                        [ \_ -> Expect.within (Absolute 0.01) worldXBefore worldXAfter
                        , \_ -> Expect.within (Absolute 0.01) worldYBefore worldYAfter
                        ]
                        ()
            , test "zoom with custom config uses custom factor" <|
                \_ ->
                    let
                        customConfig =
                            { minZoom = 1.0
                            , maxZoom = 5.0
                            , zoomFactor = 2.0 -- Double each step
                            }

                        camera =
                            init (Vec2.vec2 0 0) 2.0

                        mouseOffset =
                            Vec2.vec2 0 0

                        newCamera =
                            zoomAtPoint customConfig -100 mouseOffset camera
                    in
                    Expect.within (Absolute 0.001) 4.0 newCamera.zoom
            , test "zoom out with custom config uses inverse factor" <|
                \_ ->
                    let
                        customConfig =
                            { minZoom = 0.5
                            , maxZoom = 5.0
                            , zoomFactor = 2.0 -- Double each step (or halve when zooming out)
                            }

                        camera =
                            init (Vec2.vec2 0 0) 2.0

                        mouseOffset =
                            Vec2.vec2 0 0

                        newCamera =
                            zoomAtPoint customConfig 100 mouseOffset camera
                    in
                    Expect.within (Absolute 0.001) 1.0 newCamera.zoom
            ]
        ]
