defmodule InitWorker do
    import Matrix

   # handle when there are no more than 8 nodes
    def generate_leaf_set(index, sorted_node_list) when length(sorted_node_list) <= 8 do
        leaf_set = List.duplicate("00000000", 8)
        leaf_indicator = 0
        total = length(sorted_node_list)
        
        for i <- 0..total - 1 do
            #if leaf_indicator == index do
            #    leaf_indicator = leaf_indicator + 1 # skip the node itself
            #end
            leaf_set = List.update_at(leaf_set, i, Enum.at(sorted_node_list, leaf_indicator))
            leaf_indicator = leaf_indicator + 1
        end  
        leaf_set      
    end

    # handle case when there are more than 8 nodes
    def generate_leaf_set(index, total, sorted_node_list) when length(sorted_node_list) > 8 do
        leaf_set = List.duplicate("00000000", 9)
        leaf_indicator = 0
        total = length(sorted_node_list)

        cond do
            index - 4 < 0 ->
                leaf_indicator = 0
            index + 4 > total - 1
                leaf_indicator = total - 9
            true ->
                leaf_indicator = index - 4 
        end
        
        for i <- 0..8 do

            # skip the node itself
            if i == 4 do
                leaf_indicator = leaf_indicator + 1
            end
            leaf_set = List.replace_at(leaf_set, i, Enum.at(sorted_node_list, leaf_indicator))
            leaf_indicator = leaf_indicator + 1
        end
        leaf_set
    end

    def generate_routing_table(index, distance_nodes_map) do
        routing_table = Matrix.form_list([
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4)
        ])
        
        node_key = index |> Integer.to_string |> String.to_atom
        # id is a string
        id  = Map.get(distance_nodes_map, node_key)
    
        # enumrate the node_map to insert other node into this node's routing table
        # get a list from the node_map
        total = map_size(distance_nodes_map) 
        for i <- 0..total - 1 do
            to_fill = Map.get(distance_nodes_map, i |> Integer.to_string |> String.to_atom)
            if to_fill != id do
                row = get_shared_len(to_fill, id)
                # key!=id has guaranteed that row cannot be the last index here
                column = String.slice(to_fill, row + 1, row + 1) 
                # insert into routing table only if there is no existing element in the specific spot
                if routing_table[row][column] == "000000" do
                    routing_table = put_in(routing_table[row][column], to_fill)
                end                     
            end
        end
        routing_table
    end

    def generate_neighbor_set(id, distance_nodes_map) do
        neighbor_set = List.duplicate("00000000", 8)
        next_neighbor = id + 1
        total = map_size(distance_nodes_map)

        # for the last node, its neighbor should start from the 1st one
        if next_neighbor == total do
            next_neighbor = 0
        end 
        for i <- 0..7 do
            key = i + next_neighbor |> Integer.to_string |> String.to_atom
            neighbor_set = List.update_at(neighbor_set, i, Map.get(distance_nodes_map, key))
        end
        neighbor_set
    end

    defp get_shared_len(key, id) do
        len = String.length(key)
        shared_len = 0
        for i <- 0..len - 1 do
            if String.slice(key, 0, i) == String.slice(id, 0, i) do
                shared_len = shared_len + 1
            end           
        end
        shared_len
    end
end