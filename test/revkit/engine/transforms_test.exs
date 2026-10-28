defmodule Revkit.Engine.TransformsTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms
  alias Revkit.Engine.Transforms.{Base64Encode, BashWrapper, UrlEncode}

  test "all/0 returns the registered transforms" do
    assert Enum.sort(Transforms.all()) == Enum.sort([Base64Encode, UrlEncode, BashWrapper])
  end

  test "fetch/1 resolves atom and string keys" do
    assert Transforms.fetch(:base64_encode) == Base64Encode
    assert Transforms.fetch("url_encode") == UrlEncode
    assert Transforms.fetch(:unknown) == nil
    assert Transforms.fetch("unknown") == nil
  end

  test "resolve/1 preserves order and options" do
    steps = [
      %{"key" => "base64_encode", "options" => %{"padding" => true}},
      %{key: "bash_wrapper", options: %{}}
    ]

    assert {:ok, [{Base64Encode, %{"padding" => true}}, {BashWrapper, %{}}]} =
             Transforms.resolve(steps)
  end

  test "resolve/1 resolves an empty chain" do
    assert Transforms.resolve([]) == {:ok, []}
  end

  test "resolve/1 rejects unknown transforms" do
    assert {:error, {:unknown_transform, "nope"}} =
             Transforms.resolve([%{"key" => "nope", "options" => %{}}])
  end

  test "resolve/1 rejects malformed steps" do
    assert {:error, {:invalid_step, %{"options" => %{}}}} =
             Transforms.resolve([%{"options" => %{}}])

    assert {:error, {:invalid_step, %{"key" => "base64_encode", "options" => "bad"}}} =
             Transforms.resolve([%{"key" => "base64_encode", "options" => "bad"}])
  end
end
