defmodule Coordinator do
    use GenServer

    ######################### client API ####################
    def start_link do
        GenServer.start_link(__MODULE__, %{}, [name: :coordinator])
    end

    # build network using the input parameters
    def build_network(coordinator, num_nodes, num_requests) do
        GenServer.cast(coordinator, {:build_network, num_nodes, num_requests})
    end


    def stop_routing(coordinator, num_of_hops) do
        GenServer.cast(coordinator, {:stop_routing, num_of_hops})
    end
    ######################### callbacks ####################
    def init(%{}) do
        state = %{distance_nodes_map: %{}, node_map: %{}, sorted_node_listz: [], total: 0, requests: 0, hops: 0, reports: 0}
        {:ok, state}
    end

    def handle_cast({:build_network, num_nodes, num_requests}, state) do
        distance_nodes_map = state[:distance_nodes_map]
        node_map = state[:node_map]
        for index <- 0..num_nodes - 1 do
            Worker.start_link(index) 
            #nodeId = generate_nodeId(str_index, node_map)
            nodeId = generate_nodeId(index)

            # map actor nodeId to actor pid
            node = index |> Integer.to_string |> String.to_atom
            node_map = Map.put(state[:node_map], nodeId, node) 

            Enum.each(node_map, fn(node) -> IO.inspect node end)
            # map index to nodeId
            distance_nodes_map = Map.put(distance_nodes_map, index |> to_string |> String.to_atom, nodeId)  
            Enum.each(distance_nodes_map, fn(node) -> IO.inspect node end)
            
        end 

        # sorted_node_list stores the string id of each node(get from the node_map's keys)
        sorted_node_list = Map.keys(state[:node_map]) |> Enum.sort

        IO.puts "Start to init workers from coordinator..."
        init_workers(num_nodes, node_map, distance_nodes_map, sorted_node_list)
        send_requests(node_map, distance_nodes_map, num_requests, num_nodes, state[:num_of_hops])

        new_state = %{state | node_map: node_map, distance_nodes_map: distance_nodes_map, sorted_node_list: sorted_node_list, total: num_nodes, requests: num_requests}
        {:noreply, new_state}
    end


    def handle_cast({:stop_routing, num_of_hops}, state) do
        hops = num_of_hops + state[:hops]
        reports = state[:reports] + 1
        target_reports = state[:total] * state[:requests]
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
            IO.puts "In the for loop..."            
            node_key = i |> Integer.to_string |> String.to_atom
            nodeId = Map.get(distance_nodes_map, node_key)
            IO.inspect nodeId
            
            worker = Map.get(node_map, nodeId)
            IO.inspect worker

            Worker.init_pastry_worker(worker, distance_nodes_map, sorted_node_list)
        end
        IO.puts "Finish init workers..."
    end

    # send request to nodes that are numerically closest in index
    defp send_requests(node_map, distance_nodes_map, num_requests, num_nodes, num_of_hops) do
        for i <- 0..num_nodes - 1 do
            source_key = i |> Integer.to_string |> String.to_atom            
            source_node = Map.get(distance_nodes_map, source_key)
            source_pid = Map.get(node_map, source_node)
            
            # send msg to every destination node
            for j <- 1..num_requests do
                dest_key = j + i |> Integer.to_string |> String.to_atom 
                # source_node and destination_node are strings here           
                destination_node = Map.get(distance_nodes_map, dest_key)
                source_pid = Map.get(distance_nodes_map, dest_key)
                source_pid = String.to_atom(source_node)
                Worker.deliver_msg(source_pid, source_node, destination_node, num_of_hops)
            end
        end
    end
end