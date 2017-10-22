defmodule App do
    def main(args) do
        nodes = Enum.at(args, 0)
        num_nodes = String.to_integer(nodes)   
        requests = Enum.at(args, 1)
        num_requests = String.to_integer(requests)
        loop(num_nodes, num_requests, 1)
    end

    def loop(num_nodes, num_requests, n) when n > 0 do            
        Coordinator.start_link
        IO.puts "Coordinator is started..." 
        Coordinator.build_network(:coordinator, num_nodes, num_requests)
        loop(num_nodes, num_requests, n - 1)
    end

    def loop(num_nodes, num_requests, n) do
        :timer.sleep 1000
        loop(num_nodes, num_requests, n)
    end
end
