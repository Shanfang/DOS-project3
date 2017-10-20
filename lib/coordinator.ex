def Coordinator do
    import Matrix
    use GenServer

    ######################### client API ####################
    def start_link do
        GenServer.start_link(__MODULE__, %{}, [name: :coordinator])
    end

    # build network using the input parameters
    def build_network(num_nodes, num_requests) do
        Genserver.cast(coordinator, {:build_network, num_nodes, num_requests})
    end


    ######################### callbacks ####################
    #?????????? what would be the state of a coordinator?????????
    def init(%{}) do
        state = %{nodes => [], node_map => %{}, distance_nodes_map => %{}, sorted_node_list => []}
        {:ok, state}
    end

    def handle_cast({:build_network, num_nodes, num_requests}, state) do
        #######@@@@@@@@@ make changes so that # of digits is 8 or so
        for index <- 0..num_nodes - 1 do
            str_index = index |> to_string 
            node = Actor.start_link(str_index) 
            nodeId = get_nodeId(str_index, node_map)

            # map actor nodeId to actor pid 
            node_map = Map.put(node_map, nodeId: node) 

            # map index to nodeId
            distance_nodes_map = Map.put(distance_nodes_map, index, nodeId)           
        end 

        # sort the node list by nodeId to form the leaf set
        sorted_node_list = node_map |> Enum.sort_by(&(elem(&1, 0)))


        for i <- 0..num_nodes - 1 do
            leaf_set = generate_leaf_set(i, num_nodes, sorted_node_list)
            routing_table = generate_routing_table()
            neighbor_set = generate_neighbor_set(i, num_nodes, distance_nodes_map)
            
            # send init msg to each actor in the pastry
            nodeId = Map.get(distance_nodes_map, i)
            actor = Map.get(node_map, nodeId)
            Actor.initi_pastry_worker(actor, @@@@@, ######)
        end

        new_state = %{state | node_map: node_map}
        {:noreply, new_state}
    end

    ######################### helper functions ####################
    
    # set a unique identifier for each node
    defp get_nodeId(str_index, node_map) do
        hashed_id = Base.encode16(:crypto.hash(:sha256, str_index)) 
                    |> String.downcase 
                    |> String.to_atom  
        case Map.hasKey?(node_map, hashed_id) do
            true ->
                range = Application.get_env(:project3, :len_range, 4)                
                str_index = str_index <> RandomBytes.base62(:rand.uniform(range))               
                get_nodeId(str_index)
            _ ->
                hashed_id
        end
        hashed_id     
    end

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

    defp generate_routing_table do
        routing_table = form_list([
            List.duplicate(" ", 8),
            List.duplicate(" ", 8),
            List.duplicate(" ", 8),
            List.duplicate(" ", 8)
        ])
        
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