module Vec2Test exposing (..)

import Expect
import Test exposing (..)
import Util.Vec2
    exposing
        ( Vec2
        , add
        , angle
        , angleBetween
        , cross
        , distance
        , distanceSquared
        , dot
        , fromAngle
        , length
        , lengthSquared
        , lerp
        , normalize
        , perpendicular
        , rotate
        , scale
        , subtract
        , vec2
        )


suite : Test
suite =
    describe "Util.Vec2"
        [ constructorTests
        , addTests
        , subtractTests
        , scaleTests
        , negateTests
        , lengthTests
        , normalizeTests
        , dotTests
        , crossTests
        , rotateTests
        , angleTests
        , angleBetweenTests
        , lerpTests
        , distanceTests
        , fromAngleTests
        , perpendicularTests
        ]


tol : Expect.FloatingPointTolerance
tol =
    Expect.Absolute 0.0001


constructorTests : Test
constructorTests =
    describe "vec2"
        [ test "creates vector with given components" <|
            \_ ->
                let
                    v =
                        vec2 3 4
                in
                ( v.x, v.y )
                    |> Expect.equal ( 3, 4 )
        , test "creates zero vector" <|
            \_ ->
                let
                    v =
                        vec2 0 0
                in
                ( v.x, v.y )
                    |> Expect.equal ( 0, 0 )
        , test "handles negative components" <|
            \_ ->
                let
                    v =
                        vec2 -1 -2
                in
                ( v.x, v.y )
                    |> Expect.equal ( -1, -2 )
        ]


addTests : Test
addTests =
    describe "add"
        [ test "adds two vectors" <|
            \_ ->
                let
                    result =
                        add (vec2 1 2) (vec2 3 4)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 4, 6 )
        , test "adding zero vector is identity" <|
            \_ ->
                let
                    result =
                        add (vec2 5 6) (vec2 0 0)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 5, 6 )
        , test "is commutative" <|
            \_ ->
                let
                    a =
                        add (vec2 1 2) (vec2 3 4)

                    b =
                        add (vec2 3 4) (vec2 1 2)
                in
                ( a.x, a.y )
                    |> Expect.equal ( b.x, b.y )
        ]


subtractTests : Test
subtractTests =
    describe "subtract"
        [ test "subtracts second from first" <|
            \_ ->
                let
                    result =
                        subtract (vec2 5 7) (vec2 2 3)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 3, 4 )
        , test "subtracting self gives zero" <|
            \_ ->
                let
                    v =
                        vec2 3 4

                    result =
                        subtract v v
                in
                ( result.x, result.y )
                    |> Expect.equal ( 0, 0 )
        ]


scaleTests : Test
scaleTests =
    describe "scale"
        [ test "scales vector by scalar" <|
            \_ ->
                let
                    result =
                        scale 2 (vec2 3 4)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 6, 8 )
        , test "scaling by zero gives zero vector" <|
            \_ ->
                let
                    result =
                        scale 0 (vec2 3 4)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 0, 0 )
        , test "scaling by -1 negates vector" <|
            \_ ->
                let
                    result =
                        scale -1 (vec2 3 4)
                in
                ( result.x, result.y )
                    |> Expect.equal ( -3, -4 )
        ]


negateTests : Test
negateTests =
    describe "negate"
        [ test "negates both components" <|
            \_ ->
                let
                    result =
                        Util.Vec2.negate (vec2 3 -4)
                in
                ( result.x, result.y )
                    |> Expect.equal ( -3, 4 )
        , test "double negate is identity" <|
            \_ ->
                let
                    v =
                        vec2 3 4

                    result =
                        Util.Vec2.negate (Util.Vec2.negate v)
                in
                ( result.x, result.y )
                    |> Expect.equal ( v.x, v.y )
        ]


lengthTests : Test
lengthTests =
    describe "length and lengthSquared"
        [ test "length of 3-4-5 triangle" <|
            \_ ->
                length (vec2 3 4)
                    |> Expect.within tol 5
        , test "length of zero vector is 0" <|
            \_ ->
                length (vec2 0 0)
                    |> Expect.within tol 0
        , test "length of unit x" <|
            \_ ->
                length (vec2 1 0)
                    |> Expect.within tol 1
        , test "lengthSquared of 3-4 is 25" <|
            \_ ->
                lengthSquared (vec2 3 4)
                    |> Expect.within tol 25
        , test "lengthSquared matches length * length" <|
            \_ ->
                let
                    v =
                        vec2 3 4

                    len =
                        length v
                in
                lengthSquared v
                    |> Expect.within tol (len * len)
        ]


normalizeTests : Test
normalizeTests =
    describe "normalize"
        [ test "normalized vector has length 1" <|
            \_ ->
                length (normalize (vec2 3 4))
                    |> Expect.within tol 1
        , test "normalizing unit vector is identity" <|
            \_ ->
                let
                    result =
                        normalize (vec2 1 0)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 1, 0 )
        , test "normalizing zero vector gives zero" <|
            \_ ->
                let
                    result =
                        normalize (vec2 0 0)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 0, 0 )
        , test "preserves direction" <|
            \_ ->
                let
                    result =
                        normalize (vec2 10 0)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 1
                    , \_ -> result.y |> Expect.within tol 0
                    ]
                    ()
        ]


dotTests : Test
dotTests =
    describe "dot"
        [ test "dot product of perpendicular vectors is 0" <|
            \_ ->
                dot (vec2 1 0) (vec2 0 1)
                    |> Expect.within tol 0
        , test "dot product of same direction is positive" <|
            \_ ->
                dot (vec2 1 0) (vec2 2 0)
                    |> Expect.within tol 2
        , test "dot product of opposite direction is negative" <|
            \_ ->
                dot (vec2 1 0) (vec2 -2 0)
                    |> Expect.within tol -2
        , test "dot product of arbitrary vectors" <|
            \_ ->
                dot (vec2 1 2) (vec2 3 4)
                    |> Expect.within tol 11
        ]


crossTests : Test
crossTests =
    describe "cross"
        [ test "cross product of parallel vectors is 0" <|
            \_ ->
                cross (vec2 1 0) (vec2 2 0)
                    |> Expect.within tol 0
        , test "cross of x and y is positive (CCW)" <|
            \_ ->
                -- cross (1,0) (0,1) = 1*1 - 0*0 = 1
                cross (vec2 1 0) (vec2 0 1)
                    |> Expect.within tol 1
        , test "cross of y and x is negative (CW)" <|
            \_ ->
                cross (vec2 0 1) (vec2 1 0)
                    |> Expect.within tol -1
        ]


rotateTests : Test
rotateTests =
    describe "rotate"
        [ test "rotating by 0 is identity" <|
            \_ ->
                let
                    result =
                        rotate 0 (vec2 1 0)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 1
                    , \_ -> result.y |> Expect.within tol 0
                    ]
                    ()
        , test "rotating (1,0) by 90 degrees CCW gives (0,1)" <|
            \_ ->
                let
                    result =
                        rotate (pi / 2) (vec2 1 0)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 0
                    , \_ -> result.y |> Expect.within tol 1
                    ]
                    ()
        , test "rotating by 180 degrees negates" <|
            \_ ->
                let
                    result =
                        rotate pi (vec2 1 0)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol -1
                    , \_ -> result.y |> Expect.within tol 0
                    ]
                    ()
        , test "rotating preserves length" <|
            \_ ->
                let
                    v =
                        vec2 3 4
                in
                length (rotate 1.23 v)
                    |> Expect.within tol (length v)
        ]


angleTests : Test
angleTests =
    describe "angle"
        [ test "north (0, -1) has angle 0" <|
            \_ ->
                -- angle returns atan2(x, -y), for (0, -1): atan2(0, 1) = 0
                angle (vec2 0 -1)
                    |> Expect.within tol 0
        , test "east/west (+x, 0) has angle pi/2" <|
            \_ ->
                -- In this coordinate system: 90 degrees = West = +X
                -- angle (1, 0) = atan2(1, 0) = pi/2
                angle (vec2 1 0)
                    |> Expect.within tol (pi / 2)
        , test "south (0, 1) has angle pi" <|
            \_ ->
                -- angle (0, 1) = atan2(0, -1) = pi
                angle (vec2 0 1)
                    |> Expect.within tol pi
        , test "east (-x, 0) has angle -pi/2" <|
            \_ ->
                -- angle (-1, 0) = atan2(-1, 0) = -pi/2
                angle (vec2 -1 0)
                    |> Expect.within tol -(pi / 2)
        , test "zero vector angle is pi due to atan2(0,-0)" <|
            \_ ->
                -- Note: docstring says 0 but atan2(0, -0) = pi per IEEE 754
                angle (vec2 0 0)
                    |> Expect.within tol pi
        ]


angleBetweenTests : Test
angleBetweenTests =
    describe "angleBetween"
        [ test "same direction is 0" <|
            \_ ->
                angleBetween (vec2 1 0) (vec2 2 0)
                    |> Expect.within tol 0
        , test "perpendicular vectors have angle pi/2" <|
            \_ ->
                angleBetween (vec2 1 0) (vec2 0 1)
                    |> Expect.within tol (pi / 2)
        , test "opposite directions have angle pi" <|
            \_ ->
                angleBetween (vec2 1 0) (vec2 -1 0)
                    |> Expect.within tol pi
        , test "with zero vector returns 0" <|
            \_ ->
                angleBetween (vec2 0 0) (vec2 1 0)
                    |> Expect.within tol 0
        ]


lerpTests : Test
lerpTests =
    describe "lerp"
        [ test "t=0 returns first vector" <|
            \_ ->
                let
                    result =
                        lerp 0 (vec2 1 2) (vec2 5 6)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 1
                    , \_ -> result.y |> Expect.within tol 2
                    ]
                    ()
        , test "t=1 returns second vector" <|
            \_ ->
                let
                    result =
                        lerp 1 (vec2 1 2) (vec2 5 6)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 5
                    , \_ -> result.y |> Expect.within tol 6
                    ]
                    ()
        , test "t=0.5 returns midpoint" <|
            \_ ->
                let
                    result =
                        lerp 0.5 (vec2 0 0) (vec2 10 10)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 5
                    , \_ -> result.y |> Expect.within tol 5
                    ]
                    ()
        ]


distanceTests : Test
distanceTests =
    describe "distance and distanceSquared"
        [ test "distance between same point is 0" <|
            \_ ->
                distance (vec2 3 4) (vec2 3 4)
                    |> Expect.within tol 0
        , test "distance follows Pythagorean theorem" <|
            \_ ->
                distance (vec2 0 0) (vec2 3 4)
                    |> Expect.within tol 5
        , test "distanceSquared of 3-4-5" <|
            \_ ->
                distanceSquared (vec2 0 0) (vec2 3 4)
                    |> Expect.within tol 25
        , test "distance is symmetric" <|
            \_ ->
                let
                    d1 =
                        distance (vec2 1 2) (vec2 4 6)

                    d2 =
                        distance (vec2 4 6) (vec2 1 2)
                in
                d1 |> Expect.within tol d2
        ]


fromAngleTests : Test
fromAngleTests =
    describe "fromAngle"
        [ test "0 radians (north) gives (0, -1)" <|
            \_ ->
                let
                    result =
                        fromAngle 0
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 0
                    , \_ -> result.y |> Expect.within tol -1
                    ]
                    ()
        , test "pi/2 radians (west/+x) gives (1, 0)" <|
            \_ ->
                let
                    result =
                        fromAngle (pi / 2)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 1
                    , \_ -> result.y |> Expect.within tol 0
                    ]
                    ()
        , test "pi radians (south) gives (0, 1)" <|
            \_ ->
                let
                    result =
                        fromAngle pi
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol 0
                    , \_ -> result.y |> Expect.within tol 1
                    ]
                    ()
        , test "-pi/2 radians (east/-x) gives (-1, 0)" <|
            \_ ->
                let
                    result =
                        fromAngle -(pi / 2)
                in
                Expect.all
                    [ \_ -> result.x |> Expect.within tol -1
                    , \_ -> result.y |> Expect.within tol 0
                    ]
                    ()
        , test "fromAngle produces unit vector" <|
            \_ ->
                length (fromAngle 1.234)
                    |> Expect.within tol 1
        , test "angle of fromAngle round-trips" <|
            \_ ->
                -- fromAngle(theta) should produce a vector with angle(v) == theta
                let
                    theta =
                        0.7

                    v =
                        fromAngle theta
                in
                angle v
                    |> Expect.within tol theta
        ]


perpendicularTests : Test
perpendicularTests =
    describe "perpendicular"
        [ test "perpendicular of (1,0) is (0,1)" <|
            \_ ->
                let
                    result =
                        perpendicular (vec2 1 0)
                in
                ( result.x, result.y )
                    |> Expect.equal ( 0, 1 )
        , test "perpendicular of (0,1) is (-1,0)" <|
            \_ ->
                let
                    result =
                        perpendicular (vec2 0 1)
                in
                ( result.x, result.y )
                    |> Expect.equal ( -1, 0 )
        , test "perpendicular is orthogonal" <|
            \_ ->
                let
                    v =
                        vec2 3 4

                    p =
                        perpendicular v
                in
                dot v p
                    |> Expect.within tol 0
        , test "perpendicular preserves length" <|
            \_ ->
                let
                    v =
                        vec2 3 4
                in
                length (perpendicular v)
                    |> Expect.within tol (length v)
        ]
