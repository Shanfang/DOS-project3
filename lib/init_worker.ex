defmodule InitWorker do
    import Matrix
    
    # handle case when there are more than 8 nodes
    def generate_leaf_set(index, sorted_node_list) when length(sorted_node_list) > 8 do
        leaf_set = List.duplicate("00000000", 8)
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
        len = length(leaf_set)
        set_up_leaf(len - 1, 0, leaf_indicator, sorted_node_list, leaf_set)
    end

    defp set_up_leaf(flag, index, leaf_indicator, sorted_node_list, leaf_set) when flag >=0 do
        len = length(leaf_set)
        # skip the node itself
        if index == 4 do
            leaf_indicator = leaf_indicator + 1
        end
        
        if leaf_indicator < len do
            leaf_set = List.replace_at(leaf_set, index, Enum.at(sorted_node_list, leaf_indicator))         
        end
        set_up_leaf(flag - 1, index + 1, leaf_indicator + 1, sorted_node_list, leaf_set)
    end
    defp set_up_leaf(flag, index, leaf_indicator, sorted_node_list, leaf_set) do
        leaf_set
    end

    def generate_routing_table(index, distance_nodes_map) do
        IO.puts "Generate routing table..."
        list  = 
        [
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4),
            List.duplicate("00000000", 4)
        ]
        routing_table = Matrix.from_list(list)
        node_key = index |> Integer.to_string
        
        # id is a string
        id  = Map.get(distance_nodes_map, node_key)
        # enumrate the node_map to insert other node into this node's routing table
        # get a list from the node_map
        total = map_size(distance_nodes_map) 
        routing_table = set_up_table(id, total, distance_nodes_map, routing_table)
        routing_table
    end

    defp set_up_table(id, total, distance_nodes_map, routing_table) when total > 0 do
        to_fill = Map.get(distance_nodes_map, Integer.to_string(total - 1))
        if to_fill != id do
            full_len = String.length(id)
            row = get_shared_len(to_fill, id, full_len, 0, 0)               
            col_str = String.slice(to_fill, row, 1)
            column =  String.to_integer(col_str)
            if routing_table[row][column] == "00000000" do                    
                routing_table = put_in(routing_table[row][column], to_fill)
            end                     
        end
        set_up_table(id, total - 1, distance_nodes_map, routing_table)
    end
 
    defp set_up_table(id, total, distance_nodes_map, routing_table) do
        routing_table
    end

    defp get_shared_len(key, id, full_len, len, shared_len) when len < full_len do
        if String.slice(key, 0..len) == String.slice(id, 0..len) do
            shared_len = shared_len + 1
        end           
        get_shared_len(key, id, full_len, len + 1, shared_len)
    end

    defp get_shared_len(key, id, full_len, len, shared_len) do
        shared_len
    end

    def generate_neighbor_set(id, distance_nodes_map) do
        neighbor_set = List.duplicate("00000000", 8)
        len = length(neighbor_set)        
        total = map_size(distance_nodes_map)
        set_up_neighbor(len - 1, 1, 0, total, distance_nodes_map, neighbor_set)
    end
    defp set_up_neighbor(flag, index, next, total, distance_nodes_map, neighbor_set) when flag >= 0 do
        if next == total do
            next = 0
        end 
        key = Integer.to_string(next)          
        neighbor_set = List.replace_at(neighbor_set, index - 1, Map.get(distance_nodes_map, key))  
        set_up_neighbor(flag - 1, index + 1, next + 1, total, distance_nodes_map, neighbor_set) 
    end
    defp set_up_neighbor(flag, index, next, total, distance_nodes_map, neighbor_set) do
        neighbor_set
    end
end