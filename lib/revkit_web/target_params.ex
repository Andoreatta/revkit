defmodule RevkitWeb.TargetParams do
  @moduledoc """
  Normalizes the comma-separated target-tools form field into the array stored
  on payloads and recipes.
  """

  @spec normalize(map()) :: map()
  def normalize(params) do
    tools =
      params
      |> Map.get("target_tools_text", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    params
    |> Map.delete("target_tools_text")
    |> Map.put("target_tools", tools)
  end
end
