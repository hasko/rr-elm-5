module Camera exposing
    ( Camera
    , ZoomConfig
    , defaultZoomConfig
    , init
    , zoomAtPoint
    )

{-| Camera module for viewport management.
-}

import Util.Vec2 as Vec2 exposing (Vec2)


{-| Camera state with center position and zoom level.
-}
type alias Camera =
    { center : Vec2
    , zoom : Float -- Pixels per meter
    }


{-| Configuration for zoom behavior.
-}
type alias ZoomConfig =
    { minZoom : Float
    , maxZoom : Float
    , zoomFactor : Float -- Multiplier per scroll step
    }


{-| Default zoom configuration.
-}
defaultZoomConfig : ZoomConfig
defaultZoomConfig =
    { minZoom = 0.5
    , maxZoom = 10.0
    , zoomFactor = 1.15
    }


{-| Initialize a camera at a position with a zoom level.
-}
init : Vec2 -> Float -> Camera
init center zoom =
    { center = center
    , zoom = zoom
    }


{-| Zoom the camera at a specific screen point.

Arguments:

  - config: Zoom configuration (min/max/factor)
  - deltaY: Scroll delta (negative = zoom in, positive = zoom out)
  - mouseOffset: Mouse position relative to viewport center
  - camera: Current camera state

Returns the new camera state with the zoom applied such that
the world point under the mouse stays fixed.

-}
zoomAtPoint : ZoomConfig -> Float -> Vec2 -> Camera -> Camera
zoomAtPoint config deltaY mouseOffset camera =
    let
        -- Zoom factor (negative deltaY = zoom in)
        factor =
            if deltaY < 0 then
                config.zoomFactor

            else
                1 / config.zoomFactor

        oldZoom =
            camera.zoom

        newZoom =
            clamp config.minZoom config.maxZoom (oldZoom * factor)

        -- World point under mouse before zoom
        worldX =
            camera.center.x + mouseOffset.x / oldZoom

        worldY =
            camera.center.y + mouseOffset.y / oldZoom

        -- Adjust center so same world point stays under mouse after zoom
        newCenterX =
            worldX - mouseOffset.x / newZoom

        newCenterY =
            worldY - mouseOffset.y / newZoom
    in
    { center = Vec2.vec2 newCenterX newCenterY
    , zoom = newZoom
    }
