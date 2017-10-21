defmodule InitWorker do
    
   # handle when there are no more than 8 nodes
    defp generate_leaf_set(index, total, sorted_node_list) when total <= 8 do
        leaf_set = List.duplicate(" ", 8)
        leaf_indicator = 0
        for i <- 0..total - 1 do
            #if leaf_indicator == index do
            #    leaf_indicator = leaf_indicator + 1 # skip the node itself
            #end
            leaf_set = List.update_at(leaf_set, i, Enum.at(sorted_node_list, leaf_indicator)
            leaf_indicator = leaf_indicator + 1
        end  
        leaf_set      
    end

    # handle case when there are more than 8 nodes
    defp generate_leaf_set(index, total, sorted_node_list) when total > 8 do
        leaf_set = List.duplicate(" ", 8)
        leaf_indicator = 0

        cond do
            index - 4 < 0 ->
                leaf_indicator = 0
            index + 4 > total - 1
                leaf_indicator = total - 9
            _ ->
                leaf_indicator = index - 4 
        end
        
        for i <- 0..8 do
            leaf_set = List.update_at(leaf_set, i, Enum.at(sorted_node_list, leaf_indicator)
            leaf_indicator = leaf_indicator + 1
        end
        leaf_set
    end

    defp generate_routing_table(index, distance_nodes_map, node_map) do
        routing_table = form_list([
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4),
            List.duplicate(" ", 4)
        ])
        
        node_key = index |> Integer.to_string |> String.to_atom
        id  = Map.get(distance_nodes_map, node_key)
            

        for i <- 0..7 do
            #j = 0
            # get the digit at ith column in the table
            str_digit = String.slice(id, i, i) |> String.to_integer
            digit = String.to_integer(str_digit)

            # set itself as "00000000" in the routing table
            routing_table[i][digit] = "00000000" 

            # enumrate the node_map to insert other node into this node's routing table
            node_map |> Enum.map(fn ({key => value}) ->
                key_digit = String.slice(key, k, k)
                if key_digit != str_digit && String.slice(key, 0, k - 1) == String.slice(id, 0, k - 1) do
                    for j <- 0..3 do
                        if j == String.to_integer(key_digit) do
                            routing_table[k][j] = key
                        end
                        j = j + 1                        
                    end
                end
            end)
        end
        routing_table
    end

    defp generate_neighbor_set(index, total, distance_nodes_map) do
        neighbor_set = List.duplicate(" ", 8)
        neighbor_indictor = index + 1

        # for the last node, its neighbor should start from the 1st one
        if neighbor_indictor == total do
            neighbor_indictor = 0
        end 
        for i <- 0..7 do
            neighbor_set = List.update_at(neighbor_set, i, Enum.at(distance_nodes_map, i + neighbor_indictor))
        end
        neighbor_set
    end

end