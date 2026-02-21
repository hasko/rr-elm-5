module Util.List exposing (removeAt, swapAt)

{-| Generic list utilities.
-}


{-| Remove element at index from list.
-}
removeAt : Int -> List a -> List a
removeAt index list =
    List.take index list ++ List.drop (index + 1) list


{-| Swap elements at two indices.
-}
swapAt : Int -> Int -> List a -> List a
swapAt i j list =
    let
        arr =
            List.indexedMap Tuple.pair list

        getAt idx =
            arr
                |> List.filter (\( k, _ ) -> k == idx)
                |> List.head
                |> Maybe.map Tuple.second
    in
    case ( getAt i, getAt j ) of
        ( Just vi, Just vj ) ->
            arr
                |> List.map
                    (\( k, v ) ->
                        if k == i then
                            vj

                        else if k == j then
                            vi

                        else
                            v
                    )

        _ ->
            list
