defmodule Worker do
    import InitWorker

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
        state = %{id: 0, routing_table: %{}, neighbor_set: [], leaf_set: []}
        new_state = %{state | id: index}
        {:ok, new_state}
    end

    def handle_cast({:initi_pastry_worker, total, node_map, distance_nodes_map, sorted_node_list}, state) do
        neighbors = find_neighbors(state[:id], num_of_nodes, topology) 
        
        leaf_set = generate_leaf_set(state[:id], total, sorted_node_list)
        neighbor_set = generate_neighbor_set(state[:id], total, distance_nodes_map)
        routing_table = generate_routing_table(state[:id], distance_nodes_map, node_map)
        
        new_state = %{state | leaf_set: leaf_set, neighbor_set: neighbor_set, routing_table: routing_table} 
        {:noreply, new_state}        
    end

    def handle_cast({:deliver_msg, destination, num_of_hops}) do
        self_id = state[:id] |> Integer.to_string(4) |> String.pad_leading(8, "0")
        
        if destination == self_id do
            Coordinator.stop_routing(:coordinator, num_of_hops)
        end

        # check routing table to forward the msg

    end
    # routing procedure
    # first, check if the key is in the range of nodeId's leafset, and forward to 
    # the nearest one (with leaf_set_nodeId closest to nodeId)

    # second, if not, check the routing table and forward to a node with
    # num_shared_digits(table_nodeId, key) >= 1 + num_shared_digits(nodeId, key)
    
    # third, rare case, routing table is empty or node is not reachable
    # forward to a node with
    # (num_shared_digits(some_nodeId, key) >= num_shared_digits(nodeId, key)) 
    # && (shl(some_nodeId, key) < shl(nodeId, key))
    
    ######################### helper functions ####################
    
    # routing msg to its neighbors
