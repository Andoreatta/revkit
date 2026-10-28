defmodule Revkit.Engine.ChainTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Chain
  alias Revkit.Engine.Transforms.{Base64Encode, BashWrapper}

  defmodule ErrorTransform do
    def apply(_input, _options), do: {:error, {:boom, 42}}
  end

  defmodule RaiseTransform do
    def apply(_input, _options), do: raise("chain must halt before this transform")
  end

  defmodule PrefixTransform do
    def apply(input, %{prefix: prefix}), do: {:ok, prefix <> input}
  end

  defmodule SuffixTransform do
    def apply(input, %{suffix: suffix}), do: {:ok, input <> suffix}
  end

  defmodule NonBinaryTransform do
    def apply(_input, _options), do: {:ok, 123}
  end

  describe "run/2" do
    test "returns the input unchanged for an empty chain" do
      assert Chain.run("echo hi", []) == {:ok, "echo hi"}
    end

    test "applies a single transform" do
      assert Chain.run("hello", [{Base64Encode, %{}}]) == {:ok, "aGVsbG8="}
    end

    test "applies transforms in order" do
      assert Chain.run("hello", [{Base64Encode, %{}}, {BashWrapper, %{}}]) ==
               {:ok, "bash -c 'aGVsbG8='"}

      assert Chain.run("hello", [{BashWrapper, %{}}, {Base64Encode, %{}}]) ==
               {:ok, "YmFzaCAtYyAnaGVsbG8n"}
    end

    test "halts at the first error and returns it unchanged" do
      assert Chain.run("hello", [{ErrorTransform, %{}}, {RaiseTransform, %{}}]) ==
               {:error, {:boom, 42}}
    end

    test "passes each step's options to its transform" do
      assert Chain.run("payload", [
               {PrefixTransform, %{prefix: "pre-"}},
               {SuffixTransform, %{suffix: "-post"}}
             ]) == {:ok, "pre-payload-post"}
    end

    test "rejects a non-binary success" do
      assert Chain.run("hello", [{NonBinaryTransform, %{}}]) ==
               {:error, {:invalid_transform_result, NonBinaryTransform, {:ok, 123}}}
    end
  end
end
