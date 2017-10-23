defmodule Coordinator do
    use GenServer

    ######################### client API ####################
    def start_link do
        GenServer.start_link(__MODULE__, %{}, [name: :coordinator])
    end

    # build network using the input parameters
    def build_network(coordinator, num_nodes, num_requests) do
        GenServer.call(coordinator, {:build_network, num_nodes, num_requests}, 30000000)
    end


    def stop_routing(coordinator, num_of_hops) do
        GenServer.cast(coordinator, {:stop_routing, num_of_hops})
    end
    ######################### callbacks ####################
    def init(%{}) do
        state = %{distance_nodes_map: %{}, node_map: %{}, sorted_node_list: [], total: 0, requests: 0, hops: 0, reports: 0}
        {:ok, state}
    end

    def handle_call({:build_network, num_nodes, num_requests}, _from, state) do
        distance_nodes_map = state[:distance_nodes_map]
        node_map = state[:node_map]

        tuple = create_workers(node_map, distance_nodes_map, num_nodes - 1)
        node_map = elem(tuple, 0)
        distance_nodes_map = elem(tuple, 1)

        # sorted_node_list stores the string id of each node(get from the node_map's keys)
        sorted_node_list = Map.keys(node_map) |> Enum.sort

        IO.puts "Start to init workers from coordinator..."
        init_workers(num_nodes, node_map, distance_nodes_map, sorted_node_list)
        IO.puts "Finish initing workers..."
        
        IO.puts "Start to send requests from coordiantor..."
        send_requests(node_map, distance_nodes_map, num_requests, num_nodes, state[:hops])

        new_state = %{state | node_map: node_map, distance_nodes_map: distance_nodes_map, sorted_node_list: sorted_node_list, total: num_nodes, requests: num_requests}
        {:reply, :ok, new_state}
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
    
    defp generate_nodeId(index) do
        index |> Integer.to_string(16) |> String.pad_leading(8, "0")
    end

    defp init_workers(num_nodes, node_map, distance_nodes_map, sorted_node_list) do
        for i <- 0..num_nodes - 1 do
            node_key = i |> Integer.to_string
            
            nodeId = Map.get(distance_nodes_map, node_key)           
            worker = Map.get(node_map, nodeId)
            Worker.init_pastry_worker(worker, distance_nodes_map, sorted_node_list, node_map)
        end
    end

    # send request to nodes that are numerically closest in index
    defp send_requests(node_map, distance_nodes_map, num_requests, num_nodes, num_of_hops) do
        for i <- 0..num_nodes - 1 do
            source_key = i |> Integer.to_string           
            
            source_node = Map.get(distance_nodes_map, source_key)
            source_pid = Map.get(node_map, source_node)
            
            # send msg to every destination node
            for j <- 1..num_requests do
                if j + i < num_nodes do
                    dest_key = j + i |> Integer.to_string                                  
                else
                    dest = i + j - num_nodes
                    dest_key = dest |> Integer.to_string 
                end

                # source_node and destination_node are strings here           
                destination_node = Map.get(distance_nodes_map, dest_key)
                Worker.deliver_msg(source_pid, source_node, destination_node, num_of_hops)
            end
        end
    end

    def create_workers(node_map, distance_nodes_map, index) when index >= 0 do
        node = Worker.start_link(index) |> elem(1)
        nodeId = generate_nodeId(index)

        # map actor nodeId to actor pid
        node_map = Map.put(node_map, nodeId, node) 
        # map index to nodeId        
        distance_nodes_map = Map.put(distance_nodes_map, index |> Integer.to_string, nodeId)             
        create_workers(node_map, distance_nodes_map, index - 1)
    end

    def create_workers(node_map, distance_nodes_map, index) do
        {node_map, distance_nodes_map}
    end
end