defmodule InitWorker do
    import Matrix
    
    # handle case when there are more than 8 nodes
    def generate_leaf_set(index, sorted_node_list) when length(sorted_node_list) > 8 do
        leaf_set = List.duplicate("00000000", 8)
        IO.puts "Before init the leaf set: "
        Enum.each(leaf_set, fn(item) -> IO.inspect item end)
        leaf_indicator = 0
        #IO.puts "Sorted node list in gen leaf set"
        #Enum.each(sorted_node_list, fn(node) -> IO.inspect node end)
        
        total = length(sorted_node_list)
        #IO.puts "Index in leaf set, index is..."
        #IO.inspect index
        cond do
            index - 4 < 0 ->
                leaf_indicator = 0
            index + 4 > total - 1
                leaf_indicator = total - 9
            true ->
                leaf_indicator = index - 4 
        end
        len = length(leaf_set)
        leaf_set = set_up_leaf(len - 1, 0, leaf_indicator, sorted_node_list, leaf_set)
        IO.puts "After init the leaf set is: "
        Enum.each(leaf_set, fn(item) -> IO.inspect item end)
        leaf_set
    end

    defp set_up_leaf(flag, index, leaf_indicator, sorted_node_list, leaf_set) when flag >=0 do
        len = length(leaf_set)
        # skip the node itself
        if index == 4 do
            leaf_indicator = leaf_indicator + 1
        end
        #leaf_set = List.replace_at(leaf_set, index, Enum.at(sorted_node_list, leaf_indicator))
        
        if leaf_indicator < len do
            leaf_set = List.replace_at(leaf_set, index, Enum.at(sorted_node_list, leaf_indicator))
        #else
           # List.replace_at(leaf_set, index, "00000000")          
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

        #IO.puts "Routing table set up..."
        #Enum.each(routing_table, fn(element) -> IO.inspect element end)
        routing_table
    end

    defp set_up_table(id, total, distance_nodes_map, routing_table) when total > 0 do
        to_fill = Map.get(distance_nodes_map, Integer.to_string(total - 1))
        if to_fill != id do
            full_len = String.length(id)
            row = get_shared_len(to_fill, id, full_len, 0, 0)
                
            # key!=id has guaranteed that row cannot be the last index here
            col_str = String.slice(to_fill, row, 1)
            column =  String.to_integer(col_str)
            #IO.puts "to_fill in the row and column of..."
            #IO.puts row
            #IO.puts column
            #IO.puts "Before insertion, the table looks like this: "
            #Enum.each(routing_table, fn(item) -> IO.inspect item end)
            #IO.puts "the cell before insertion is "
            #IO.inspect routing_table[row][column]
            # insert into routing table only if there is no existing element in the specific spot
            #if routing_table[row][column] == "00000000" do
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
        IO.puts "Before inserting into neighbor set..."
        Enum.each(neighbor_set, fn(element) -> IO.inspect element end)
        len = length(neighbor_set)        
        #next_neighbor = id + 1
        total = map_size(distance_nodes_map)

        #IO.puts "Index in neighbor set, id is..."
        #IO.inspect id

        # for the last node, its neighbor should start from the 1st one
        #if next_neighbor == total do
        #    next_neighbor = 0
        #end 
        neighbor_set = set_up_neighbor(len - 1, 1, 0, total, distance_nodes_map, neighbor_set)

        IO.puts "Neighbor set is set up..."
        Enum.each(neighbor_set, fn(element) -> IO.inspect element end)
        neighbor_set
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