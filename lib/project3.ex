defmodule Project3 do
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
