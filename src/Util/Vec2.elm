module Util.Vec2 exposing
    ( Vec2
    , vec2
    , add
    , subtract
    , scale
    , negate
    , length
    , lengthSquared
    , normalize
    , dot
    , cross
    , rotate
    , angle
    , angleBetween
    , lerp
    , distance
    , distanceSquared
    , fromAngle
    , perpendicular
    )

{-| 2D Vector operations for track geometry and positioning.

All angles are in radians. The coordinate system uses:

  - X axis: East (-) to West (+) (screen: left to right)
  - Y axis: North (-) to South (+) (screen: up to down)
  - Angle 0 = North, angles increase clockwise
  - 90° = West (right on screen)

-}


type alias Vec2 =
    { x : Float
    , y : Float
    }


{-| Create a vector from x and y components.
-}
vec2 : Float -> Float -> Vec2
vec2 x y =
    { x = x, y = y }


{-| Add two vectors.
-}
add : Vec2 -> Vec2 -> Vec2
add a b =
    { x = a.x + b.x
    , y = a.y + b.y
    }


{-| Subtract second vector from first (a - b).
-}
subtract : Vec2 -> Vec2 -> Vec2
subtract a b =
    { x = a.x - b.x
    , y = a.y - b.y
    }


{-| Scale a vector by a scalar.
-}
scale : Float -> Vec2 -> Vec2
scale s v =
    { x = v.x * s
    , y = v.y * s
    }


{-| Negate a vector (flip direction).
-}
negate : Vec2 -> Vec2
negate v =
    { x = -v.x
    , y = -v.y
    }


{-| Get the length (magnitude) of a vector.
-}
length : Vec2 -> Float
length v =
    sqrt (v.x * v.x + v.y * v.y)


{-| Get the squared length (avoids sqrt for comparisons).
-}
lengthSquared : Vec2 -> Float
lengthSquared v =
    v.x * v.x + v.y * v.y


{-| Normalize a vector to unit length. Returns zero vector if input is zero.
-}
normalize : Vec2 -> Vec2
normalize v =
    let
        len =
            length v
    in
    if len == 0 then
        vec2 0 0

    else
        scale (1 / len) v


{-| Dot product of two vectors.
-}
dot : Vec2 -> Vec2 -> Float
dot a b =
    a.x * b.x + a.y * b.y


{-| Cross product (returns scalar z-component of 3D cross product).
Positive if b is counter-clockwise from a.
-}
cross : Vec2 -> Vec2 -> Float
cross a b =
    a.x * b.y - a.y * b.x


{-| Rotate a vector by an angle (radians, counter-clockwise).
-}
rotate : Float -> Vec2 -> Vec2
rotate angleRad v =
    let
        cosA =
            cos angleRad

        sinA =
            sin angleRad
    in
    { x = v.x * cosA - v.y * sinA
    , y = v.x * sinA + v.y * cosA
    }


{-| Get the angle of a vector (radians, 0 = North, clockwise positive).
Returns 0 for zero vector.
-}
angle : Vec2 -> Float
angle v =
    atan2 v.x -v.y


{-| Get the angle between two vectors (radians, 0 to pi).
-}
angleBetween : Vec2 -> Vec2 -> Float
angleBetween a b =
    let
        dotProduct =
            dot a b

        lenA =
            length a

        lenB =
            length b

        denom =
            lenA * lenB
    in
    if denom == 0 then
        0

    else
        acos (clamp -1 1 (dotProduct / denom))


{-| Linear interpolation between two vectors.
t=0 returns a, t=1 returns b.
-}
lerp : Float -> Vec2 -> Vec2 -> Vec2
lerp t a b =
    { x = a.x + t * (b.x - a.x)
    , y = a.y + t * (b.y - a.y)
    }


{-| Distance between two points.
-}
distance : Vec2 -> Vec2 -> Float
distance a b =
    length (subtract b a)


{-| Squared distance between two points (avoids sqrt).
-}
distanceSquared : Vec2 -> Vec2 -> Float
distanceSquared a b =
    lengthSquared (subtract b a)


{-| Create a unit vector from an angle (radians, 0 = North, clockwise positive).
-}
fromAngle : Float -> Vec2
fromAngle angleRad =
    { x = sin angleRad
    , y = -(cos angleRad)
    }


{-| Get a perpendicular vector (rotated 90 degrees clockwise).
In our coordinate system, this is the "right-hand" perpendicular.
-}
perpendicular : Vec2 -> Vec2
perpendicular v =
    { x = -v.y
    , y = v.x
    }
