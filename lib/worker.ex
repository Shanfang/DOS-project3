defmodule Worker do
    import InitWorker
    use GenServer

    ######################### client API ####################

    def start_link(index) do
        actor_name = index |> Integer.to_string |> String.to_atom
        GenServer.start_link(__MODULE__, index, [name: actor_name])
    end

    def init_pastry_worker(actor_name, distance_nodes_map, sorted_node_list, node_map) do
        GenServer.call(actor_name, {:init_pastry_worker, distance_nodes_map, sorted_node_list, node_map})
    end

    def deliver_msg(actor_name, source_node, destination_node, num_of_hops) do
        GenServer.cast(actor_name, {:deliver_msg, source_node, destination_node, num_of_hops})
    end
    ######################### callbacks ####################

    def init(index) do 
        state = %{id: 0, routing_table: %{}, neighbor_set: [], leaf_set: [], distance_nodes_map: %{}, node_map: %{}}
        new_state = %{state | id: index}
        {:ok, new_state}
    end

    def handle_call({:init_pastry_worker, distance_nodes_map, sorted_node_list, node_map}, _from, state) do
        %{state | distance_nodes_map: distance_nodes_map, node_map: node_map}         
        id = state[:id]
        key = id |> Integer.to_string
        nodeId = Map.get(distance_nodes_map, key)

        # get the index of the nodeId in sorted_nodes_list, it can be different from id as it is sorted 
        sorted_list_index = Enum.find_index(sorted_node_list, fn(nodeId) -> 
            nodeId == state[:id] |> Integer.to_string(16) |> String.pad_leading(8, "0")            
        end)
        leaf_set = generate_leaf_set(sorted_list_index, sorted_node_list)
        neighbor_set = generate_neighbor_set(state[:id], distance_nodes_map)
        routing_table = generate_routing_table(state[:id], distance_nodes_map)
        
        new_state = %{state | leaf_set: leaf_set, neighbor_set: neighbor_set, routing_table: routing_table, distance_nodes_map: distance_nodes_map, node_map: node_map} 
        {:reply, :ok, new_state}        
    end

    @doc """
        routing procedure
        first, check if the key is in the range of nodeId's leafset, and forward to 
        the nearest one (with leaf_set_nodeId closest to nodeId)

        second, if not, check the routing table and forward to a node with
        num_shared_digits(table_nodeId, destination) >= 1 + num_shared_digits(nodeId, destination)
        
        third, rare case, routing table is empty or node is not reachable
        forward to a node with
        (num_shared_digits(some_node, destination) >= num_shared_digits(nodeId, destination)) && 
        (distance(some_node, destination) < distance(nodeId, destination))
    """
    def handle_cast({:deliver_msg, source_node, destination_node, num_of_hops}, state) do        
        # get self_id from distance_nodes_map, it is a string
        self_id = Map.get(state[:distance_nodes_map], state[:id] |> Integer.to_string)
        next_nodeId = "00000000"
        full_len = String.length(self_id)
        num_shared_digits_AD = get_shared_len(destination_node, self_id, full_len, 0, 0)
        leaf_set = state[:leaf_set]
        neighbor_set = state[:neighbor_set]
        routing_table = state[:routing_table]
        node_map = state[:node_map]

        if destination_node == self_id do
            Coordinator.stop_routing(:coordinator, num_of_hops)
        end

        # if total number of nodes in the network is >= 9, then there would be 8 elements in the leaf set.
        # if total number of nodes in the network is < 9, then there would be less than 8 elements in the leaf set.
        leaf_set_size = 16        
        if length(leaf_set) <= 16 do
            leaf_set_size = map_size(node_map) - 1
        end

        # if the key (id) lies within the leafSet range, then route the 
        # message to the node whose id is numerically closest to the key (id)
        # id is string in leaf_set
        first_leaf = List.first(leaf_set) |> String.to_integer(16)
        last_leaf = List.last(leaf_set) |> String.to_integer(16)
        destination_int = destination_node |> String.to_integer(16)
        row = num_shared_digits_AD
        
        # get the row-th digit from destination_node 
        col_str = String.slice(destination_node, row, 1) 
        column = String.to_integer(col_str, 16)
        start_index = length(leaf_set) - 1 
        inital_distanceTD = abs(destination_int - last_leaf)
        #inital_distanceAD = abs(destination_int - state[:id])
        id_int_base16 = state[:distance_nodes_map] 
                        |> Map.get(Integer.to_string(state[:id])) 
                        |> String.to_integer(16)
        dest_int_base16 = String.to_integer(destination_node, 16)
        distance_AD = abs(id_int_base16 - dest_int_base16)
        
        cond do
            destination_int >= first_leaf && destination_int <= last_leaf ->
                # first scenario in the routing procedure             
                next_nodeId = search_leaf_set(destination_int, inital_distanceTD, next_nodeId, leaf_set, start_index)                    
            routing_table[row][column] != "00000000" ->
                # second scenario in the routing procedure
                next_nodeId = routing_table[row][column]
            true ->
                # third scenario in the routing procudure, rare case
                #(num_shared_digits_AD(some_node, destination_node) >= num_shared_digits_AD(nodeId, destination_node)) && 
                #(distance(some_node, destination_node) < distance(nodeId, destination_node))
                
                # check if there are numerically closer nodes in the leaf set
                rare_case1 = rare_leaf_set(destination_node, distance_AD, next_nodeId, leaf_set, start_index, num_shared_digits_AD)

                dest_digit = String.slice(destination_node, row, 1) |> String.to_integer(16)
                
                rare_case2 = rare_routing_table(dest_digit, routing_table, num_shared_digits_AD, start_index, next_nodeId, 8)
                    
                # check if there are numerically closer nodes in the neighbor set
                rare_case3 = rare_neighbor_set(destination_node, neighbor_set, start_index, next_nodeId, num_shared_digits_AD, distance_AD)
              
                cond do
                    rare_case1 != "00000000" ->                       
                        next_nodeId = rare_case1
                    rare_case2 != "00000000" ->                       
                        next_nodeId = rare_case2
                    rare_case3 != "00000000" ->                       
                        next_nodeId = rare_case3
                    true ->
                        next_nodeId = "00000000"                      
                end     
        end

        # forward message only if next_nodeId is valid
        if next_nodeId != "00000000" do
            next_node_pid = Map.get(node_map, next_nodeId)
            num_of_hops = num_of_hops + 1
            Worker.deliver_msg(next_node_pid, source_node, destination_node, num_of_hops)  
        #else 
            #IO.puts "Oops, msg can not be routed!"
        end
        {:noreply, state}            
    end

    
    ######################### helper functions ####################
    
    defp get_shared_len(destination_node, node, full_len, len, shared_len) when len < full_len - 1 do
        if String.slice(destination_node, 0..len) == String.slice(node, 0..len) do
            shared_len = shared_len + 1
        end           
        get_shared_len(destination_node, node, full_len, len + 1, shared_len)
    end

    defp get_shared_len(destination_node, node, full_len, len, shared_len) do
        shared_len
    end

    defp search_leaf_set(destination_int, distance, next_nodeId, leaf_set, index) when index >= 0 do
        nodeId = Enum.at(leaf_set, index)
        new_distance = abs(String.to_integer(nodeId) - destination_int)
        if new_distance < distance do
            distance = new_distance
            next_nodeId = nodeId
        end
        search_leaf_set(destination_int, distance, next_nodeId, leaf_set, index - 1)   
    end
    
    defp search_leaf_set(destination_int, distance, next_nodeId, leaf_set, index) do
        next_nodeId
    end

    defp rare_case_node(destination_node, some_node, num_shared_digits_AD, distance_AD) do
        next_nodeId = "00000000"
        full_len = String.length(destination_node)
        #dest_int_base16 = String.to_integer(destination_node, 10)
        #some_int_base10 = String.to_integer(some_node, 10)
        dest_int_base16 = String.to_integer(destination_node, 16)
        some_int_base16 = String.to_integer(some_node, 16)

        num_shared_digits_TD = get_shared_len(destination_node, some_node, full_len, 0, 0)
        distance_TD = abs(dest_int_base16 - some_int_base16)
        
        if num_shared_digits_TD >= num_shared_digits_AD && distance_TD < distance_AD do
            next_nodeId = some_node
        end 
        next_nodeId     
    end
    defp rare_leaf_set(destination_node, distance, next_nodeId, leaf_set, index, num_shared_digits_AD) when index >= 0 do
        some_node = Enum.at(leaf_set, index)
        result = rare_case_node(destination_node, some_node, num_shared_digits_AD, distance)
        if result != "00000000" do
            next_nodeId = result
        end
        rare_leaf_set(destination_node, distance, next_nodeId, leaf_set, index - 1, num_shared_digits_AD)
    end
    
    defp rare_leaf_set(destination_node, distance, next_nodeId, leaf_set, index, num_shared_digits_AD) do
        next_nodeId
    end 

    #defp rare_routing_table(destination_node, routing_table, num_shared_digits_AD, index, next_nodeId, distance_AD) when index >= 0 do
    defp rare_routing_table(dest_digit, routing_table, num_shared_digits_AD, index, next_nodeId, minimum) when index >= 0 do            
        if index == dest_digit do
            index = index - 1
        end
        if abs(index - dest_digit) < minimum && routing_table[num_shared_digits_AD][index] != "00000000" do
            min = abs(index - dest_digit)
            next_nodeId = routing_table[num_shared_digits_AD][index]
        end
        rare_routing_table(dest_digit, routing_table, num_shared_digits_AD, index - 1, next_nodeId, minimum)      
    end
    
    defp rare_routing_table(dest_digit, routing_table, num_shared_digits_AD, index, next_nodeId, minimum) do
        next_nodeId
    end 

    defp rare_neighbor_set(destination_node, neighbor_set, index, next_nodeId, num_shared_digits_AD, distance) when index >= 0 do
        some_node = Enum.at(neighbor_set, index)
        result = rare_case_node(destination_node, some_node, num_shared_digits_AD, distance)
        if result != "00000000" do
            next_nodeId = result
        end
        rare_neighbor_set(destination_node, neighbor_set, index - 1, next_nodeId, num_shared_digits_AD, distance)
    end
    defp rare_neighbor_set(destination_node, neighbor_set, index, next_nodeId, num_shared_digits_AD, distance) do
        next_nodeId
    end
    
end