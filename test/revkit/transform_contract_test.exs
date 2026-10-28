defmodule Revkit.TransformContractTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms
  alias Revkit.Transform

  @transforms Transforms.all()

  test "all transforms implement the behaviour" do
    for transform <- @transforms do
      assert Transform in transform.module_info(:attributes)[:behaviour]
    end
  end

  test "all transforms expose unique keys" do
    keys = Enum.map(@transforms, & &1.key())

    assert length(keys) == length(Enum.uniq(keys))
  end

  test "all transforms return valid metadata" do
    for transform <- @transforms do
      assert is_atom(transform.key())
      assert is_binary(transform.label()) and transform.label() != ""
      assert transform.kind() in [:encoding, :wrapper]
      assert is_list(transform.requires())
      assert Enum.all?(transform.requires(), &is_binary/1)
      assert is_list(transform.pitfalls())
      assert Enum.all?(transform.pitfalls(), &is_binary/1)
    end
  end

  test "all transforms return a binary success for a sample payload" do
    for transform <- @transforms do
      assert {:ok, output} = transform.apply("echo 'hi'", %{})
      assert is_binary(output)
    end
  end
end
