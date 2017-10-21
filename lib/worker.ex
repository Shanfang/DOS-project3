defmodule Worker do
    import InitWorker
    #import Matrix
    use GenServer

    ######################### client API ####################

    def start_link(index) do
        actor_name = index |> Integer.to_string |> String.to_atom
        GenServer.start_link(__MODULE__, index, [name: actor_name])
    end

    def initi_pastry_worker(actor_name, node_map, distance_nodes_map, sorted_node_list) do
        GeneServer.cast(actor_name, {:initi_pastry_worker, node_map, distance_nodes_map, sorted_node_list})
    end

    # called by Pastry when a message is received and the local node’s
    # nodeId is numerically closest to key, among all live nodes
    def deliver_msg(actor_name, source_node, destination_node, num_of_hops) do
        GeneServer.cast(actor_name, {:deliver_msg, source_node, destination_node, num_of_hops})   
    end
    

    
    # called by pastry before a message is forwarded to the node with nodeId = nextId
    # The application may change the contents of the message
    # or the value of nextId. Setting the nextId to NULL terminates the message at the
    # local node.
    def forward(msg,key,nextId) do
        
    end

    # called by Pastry whenever there is a change in the local node’s leaf set.
    def newLeafs(leafSet) do
        
    end
   
    ######################### callbacks ####################

    def init(index) do 
        state = %{id: 0, routing_table: %{}, neighbor_set: [], leaf_set: [], distance_nodes_map: %{}}
        new_state = %{state | id: index}
        {:ok, new_state}
    end

    def handle_cast({:initi_pastry_worker, total, node_map, distance_nodes_map, sorted_node_list}, state) do
        neighbors = find_neighbors(state[:id], num_of_nodes, topology) 
        nodeId = Map.get(distance_nodes_map, state[:id] |> Integer.to_string |> String.to_atom)

        # get the index of the nodeId in sorted_nodes_list, it can be different from id as it is sorted 
        sorted_list_index = Enum.find_index(sorted_node_list, fn(nodeId) -> 
            nodeId == Integer.to_string(state[:id])
        end)
        leaf_set = generate_leaf_set(sorted_list_index, total, sorted_node_list)
        neighbor_set = generate_neighbor_set(state[:id], total, distance_nodes_map)
        routing_table = generate_routing_table(state[:id], distance_nodes_map, node_map)
        
        new_state = %{state | leaf_set: leaf_set, neighbor_set: neighbor_set, routing_table: routing_table, distance_nodes_map: distance_nodes_map} 
        {:noreply, new_state}        
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
        self_id = Map.get(state[:distance_nodes_map], state[:id] |> Integer.to_string |> String.to_atom)
        next_nodeId = "00000000"
        num_shared_digits_AD = get_shared_len(destination_node, self_id)
        leaf_set = state[:leaf_set]
        neighbor_set = state[:neighbor_set]
        routing_table = state[:routing_table]

        if destination_node == self_id do
            Coordinator.stop_routing(:coordinator, num_of_hops)
        end

        # if total number of nodes in the network is >= 9, then there would be 8 elements in the leaf set.
        # if total number of nodes in the network is < 9, then there would be less than 8 elements in the leaf set.
        leaf_set_size = 8        
        if length(leaf_set)) <= 8 do
            leaf_set_size = map_size(node_map) - 1
        end

        # if the key (id) lies within the leafSet range, then route the 
        # message to the node whose id is numerically closest to the key (id)
        # id is string in leaf_set
        first_leaf = List.first(leaf_set) |> String.to_integer
        last_leaf = List.last(leaf_set) |> String.to_integer
        destination_int = destination_node |> String.to_integer
        if destination_int >= first_leaf && destination_int <= last_leaf do
            # first scenario in the routing procedure                       
            distance = abs(first_leaf - destination_int)

            Enum.slice(leaf_set, 1..7) |> Enum.each(fn(nodeId) -> 
                new_distance = abs(String.to_integer(nodeId) - destination_int)
                if new_distance < distance do
                    distance = new_distance
                    next_nodeId = nodeId
                end
            end) 
        else
            # second scenario in the routing procedure
            row = num_shared_digits_AD
            
            # get the row-th digit from destionation
            column = String.slice(destionation, row, row) |> String.to_integer
            # if there exists a node id in that particular row and column, then route message to that node
            if routing_table[row][column] != "00000000" do
                next_nodeId = routing_table[row][column]
            end
        else 
            # third scenario in the routing procudure, rare case
            #(num_shared_digits_AD(some_node, destination_node) >= num_shared_digits_AD(nodeId, destination_node)) && 
            #(distance(some_node, destination_node) < distance(nodeId, destination_node))
            distance_AD = abs(String.to_integer(Map.get(state[:distance_nodes_map], state[:id])) - String.to_integer(destination_node))
            
            # check if there are numerically closer nodes in the leaf set
            leaf_set |> Enum.map(fn(some_node) -> 
                result = rare_case_node(destination_node, some_node, num_shared_digits_AD, distance_AD)
                if result != "" do
                    next_nodeId = some_node
                end
            end)

            # check if there are numerically closer nodes in the routing table
            for i <- 0..7 do
                some_node = routing_table[num_shared_digits_AD][i]
                result = rare_case_node(destination_node, some_node, num_shared_digits_AD, distance_AD)
                if result != "00000000" do
                    next_nodeId = some_node
                end
            end
            
            # check if there are numerically closer nodes in the neighbor set
            neighbor_set |> Enum.map(fn(some_node) -> 
                result = rare_case_node(destination_node, some_node, num_shared_digits_AD, distance_AD)
                if result != "00000000" do
                    next_nodeId = some_node
                end
            end)
        end

        # forward message only if next_nodeId is valid
        if next_nodeId != "00000000" do
            next_node_pid = Map.get(state[:node_map], next_nodeId)
            Worker.deliver_msg(next_node_pid, source_node, destination_node, num_of_hops + 1)  
        else 
            IO.put "Oops, msg can not be routed!"
        end
        {:noreply, state}            
    end

    
    ######################### helper functions ####################
    
    defp get_shared_len(destination_node, node) do
        len = String.length(destination_node)
        shared_len = 0
        for i <- 0..len - 1 do
            if String.slice(destination_node, 0, i) == String.slice(node, 0, i) do
                shared_len = shared_len + 1
            end           
        end
        shared_len
    end

    defp rare_case_node(destination_node, some_node, num_shared_digits_AD, distance_AD) do
        next_nodeId = "00000000"
        num_shared_digits_TD = get_shared_len(destination_node, some_node)
        distance_TD = abs(String.to_integer(some_node) - String.to_integer(destination_node))
        
        if num_shared_digits_TD >= num_shared_digits_AD && distance_TD < distance_AD do
            next_nodeId = some_node
        end 
        next_nodeId     
    end