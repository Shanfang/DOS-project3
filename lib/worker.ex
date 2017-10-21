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
    def deliver_msg(actor_name, destination, num_of_hops) do
        GeneServer.cast(actor_name, {:deliver_msg, destination, num_of_hops})   
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
        
        leaf_set = generate_leaf_set(state[:id], total, sorted_node_list)
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
        num_shared_digits(table_nodeId, key) >= 1 + num_shared_digits(nodeId, key)
        
        third, rare case, routing table is empty or node is not reachable
        forward to a node with
        (num_shared_digits(some_nodeId, key) >= num_shared_digits(nodeId, key)) && 
        (num_shared_digits(some_nodeId, key) < num_shared_digits(nodeId, key))
    """
    def handle_cast({:deliver_msg, destination, num_of_hops}) do
        # get self_id from distance_nodes_map
        self_id = Map.get(state[:distance_nodes_map], state[:id] |> Integer.to_string |> String.to_atom)
        next_nodeId = "00000000"
        num_shared_digits = 0
        
        for i <- 1..7 do
            if String.slice(destination, 0, i) == String.slice(self_id, 0, i)do
                num_shared_digits = i + 1
            end
        end

        if destination == self_id do
            Coordinator.stop_routing(:coordinator, num_of_hops)
        end

        # if total number of nodes in the network is >= 9, then there would be 8 elements in the leaf set.
        # if total number of nodes in the network is < 9, then there would be less than 8 elements in the leaf set.
        leaf_set_size = 8        
        if length(leaf_set) <= 8 do
            leaf_set_size = map_size(node_map) - 1
        end

        # if the key (id) lies within the leafSet range, then route the 
        # message to the node whose id is numerically closest to the key (id)
        # id is string in leaf_set
        first_leaf = List.first(leaf_set) |> String.to_integer
        last_leaf = List.last(leaf_set) |> String.to_integer
        destination_int = destination |> String.to_integer

        if first_leaf != 0 && (destination_int >= first_leaf) && (destination_int <= last_leaf) do
            # first scenario in the routing procedure           
            next_nodeId = List.first(leaf_set)
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

            # get the common shared prefix, starting from row 1 as they do not share any prefix at row 0
            row = 0
            for i <- 1..7 do
                if String.slice(destination, 0, i) == String.slice(self_id, 0, i)do
                    row = i
                end
            end

            # get the row-th digit from destionation
            column = String.slice(destionation, row, row) |> String.to_integer
            # if there exists a node id in that particular row and column, then route message to that node
            if routing_table[row][column] != "00000000" && row != 0 do
                next_nodeId = routing_table[row][column]
            end
        else 
            # third scenario in the routing procudure, rare case
            
            # get shortest

        else 
            IO.puts "There is no appropriate node to route!"
        end

    end

    
    ######################### helper functions ####################
    
    # routing msg to its neighbors
