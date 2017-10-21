defmodule InitWorkerTest do
    use ExUnit.Case
  
    test "generate leaf_set of size <= 8" do
      assert InitWorker.generate_leaf_set(1, ["1", "3", "2", "4","5", "6"])  == ["1", "3", "2", "4", "5", "6", "00000000", "00000000"]
    end
end