module Util.Transform exposing
    ( translate
    , rotate
    , rotateAround
    , scale
    , scaleXY
    , combine
    , toAttribute
    )

{-| SVG transform string builders.

These helpers create transform strings for use with Svg.Attributes.transform.

-}

import Svg
import Svg.Attributes


{-| Create a translation transform string.
-}
translate : Float -> Float -> String
translate x y =
    "translate(" ++ String.fromFloat x ++ "," ++ String.fromFloat y ++ ")"


{-| Create a rotation transform string (degrees, around origin).
-}
rotate : Float -> String
rotate degrees =
    "rotate(" ++ String.fromFloat degrees ++ ")"


{-| Create a rotation transform string (degrees, around a point).
-}
rotateAround : Float -> Float -> Float -> String
rotateAround degrees cx cy =
    "rotate("
        ++ String.fromFloat degrees
        ++ ","
        ++ String.fromFloat cx
        ++ ","
        ++ String.fromFloat cy
        ++ ")"


{-| Create a uniform scale transform string.
-}
scale : Float -> String
scale s =
    "scale(" ++ String.fromFloat s ++ ")"


{-| Create a non-uniform scale transform string.
-}
scaleXY : Float -> Float -> String
scaleXY sx sy =
    "scale(" ++ String.fromFloat sx ++ "," ++ String.fromFloat sy ++ ")"


{-| Combine multiple transform strings into one.
Transforms are applied in order (first in list is applied first).
-}
combine : List String -> String
combine transforms =
    String.join " " transforms


{-| Convert a transform string to an SVG attribute.
-}
toAttribute : String -> Svg.Attribute msg
toAttribute transformStr =
    Svg.Attributes.transform transformStr
