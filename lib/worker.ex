defmodule Worker do
    use GenServer

    ######################### client API ####################

    def start_link(index) do
        actor_name = index |> Integer.to_string |> String.to_atom
        GenServer.start_link(__MODULE__, index, [name: actor_name])
    end

    # called by Pastry when a message is received and the local node’s
    # nodeId is numerically closest to key, among all live nodes
    def deliver(msg, key) do
        
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
        state = %{id: 0, routing_set: [], neighbor_set: [], leaf_ser: []}
        new_state = %{state | id: index}
        {:ok, new_state}
    end

    def handle_cast({:setup_neighbors, num_of_nodes, topology}, state) do
        neighbors = find_neighbors(state[:id], num_of_nodes, topology) 
        new_state = %{state | neighbors: neighbors} 
        {:noreply, new_state}        
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

end