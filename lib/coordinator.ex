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

    def stop_routing(num_of_hops) do
        Genserver.cast(coordinator, {:stop_routing, num_of_hops})
    end
    ######################### callbacks ####################
    def init(%{}) do
        state = %{distance_nodes_map => %{}, node_map => %{}, sorted_node_list => [], total: 0, requests: 0, hops: 0, reports: 0}
        {:ok, state}
    end

    def handle_cast({:build_network, num_nodes, num_requests}, state) do
        for index <- 0..num_nodes - 1 do
            Worker.start_link(index) 
            #nodeId = generate_nodeId(str_index, node_map)
            nodeId = generate_nodeId(index)

            # map actor nodeId to actor pid
            node = index |> Integer.to_string |> String.to_atom
            node_map = Map.put(node_map, nodeId, node) 

            # map index to nodeId
            distance_nodes_map = Map.put(distance_nodes_map, index |> to_string |> String.to_atom, nodeId)           
        end 

        # sort the node list by nodeId to form the leaf set
        # fix the sorted list, it does not generate a sorted list here##
        #@@@@@@@@@@@@@@@@@@@@@@@@@
        sorted_node_list = node_map |> Enum.sort_by(&(elem(&1, 1)))

        init_workers(num_nodes, node_map, distance_nodes_map, sorted_node_list)
        send_requests(node_map, distance_nodes_map, num_requests, num_nodes)

        new_state = %{state | node_map: node_map, distance_nodes_map: distance_nodes_map, sorted_node_list: sorted_node_list, total: num_nodes, requests: num_requests}
        {:noreply, new_state}
    end


    def handle_cast({:stop_routing, num_of_hops}, state) do
        hops = num_of_hops + state[:hops]
        reports = state[:reports] + 1
        target_reports = num_nodes * num_requests
        if reports == target_reports do
            # calculate the average
            average = hops / reports
            IO.puts "Routing finished, average hops is: " <> Float.to_string(average)
        end
        new_state = %{state | hops: hops, reports: reports}
        {:noreply, new_state}        
    end  
    ######################### helper functions ####################
    
    # set a unique identifier for each node
    #defp gene_nodeId(str_index, node_map) do
        #hashed_id = Base.encode16(:crypto.hash(:sha256, str_index)) 
        #            |> String.downcase 
        #            |> String.to_atom 

        #case Map.hasKey?(node_map, hashed_id) do
        #   true ->
        #       range = Application.get_env(:project3, :len_range, 4)                
        #       str_index = str_index <> RandomBytes.base62(:rand.uniform(range))               
        #       get_nodeId(str_index)
        #   _ ->
        #       hashed_id
        #end
        #hashed_id 

        # generate base4 str and does not check collision
        # this generate 16 bits nodeId, if we want 128 bits, change base to 16 and
        # make changes in generate leaf_set and routing table
    
    defp generate_nodeId(index) do
        index |> Integer.to_string(4) |> String.pad_leading(8, "0")
    end

    defp init_workers(num_nodes, node_map, distance_nodes_map, sorted_node_list) do
        for i <- 0..num_nodes - 1 do
            leaf_set = generate_leaf_set(i, num_nodes, sorted_node_list)
            routing_table = generate_routing_table(i, distance_nodes_map, node_map)
            neighbor_set = generate_neighbor_set(i, num_nodes, distance_nodes_map)
            
            # send init msg to each actor in the pastry
            node_key = i |> Integer.to_string |> String.to_atom
            nodeId = Map.get(distance_nodes_map, node_key)
            worker = Map.get(node_map, nodeId)
            Worker.initi_pastry_worker(worker, num_nodes, node_map, distance_nodes_map, sorted_node_list)
        end
    end

    defp send_requests(node_map, distance_nodes_map, num_requests, num_nodes) do
        for i <- 0..num_nodes - 1 do
            source_key = i |> Integer.to_string |> String.to_atom            
            source_node = Map.get(distance_nodes_map, node_key)
            
            # send msg to every destination node
            for j <- 1..num_requests do
                dest_key = j + i |> Integer.to_string |> String.to_atom            
                dest_node = Map.get(distance_nodes_map, dest_key)
                Worker.deliver_msg(source_node, dest_node, num_of_hops)
            end
        end
    end
 