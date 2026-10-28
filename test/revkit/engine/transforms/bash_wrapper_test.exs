defmodule Revkit.Engine.Transforms.BashWrapperTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms.BashWrapper

  describe "apply/2" do
    test "wraps a simple payload" do
      assert BashWrapper.apply("echo hi", %{}) == {:ok, "bash -c 'echo hi'"}
    end

    test "escapes embedded single quotes" do
      assert BashWrapper.apply("echo 'hi'", %{}) == {:ok, "bash -c 'echo '\\''hi'\\'''"}
    end

    test "preserves multiline payloads inside the quotes" do
      assert BashWrapper.apply("echo one\necho two", %{}) ==
               {:ok, "bash -c 'echo one\necho two'"}
    end

    test "wraps an empty payload" do
      assert BashWrapper.apply("", %{}) == {:ok, "bash -c ''"}
    end

    test "ignores options" do
      assert BashWrapper.apply("id", %{unused: true}) == BashWrapper.apply("id", %{})
    end
  end

  describe "metadata" do
    test "exposes the wrapper contract" do
      assert BashWrapper.key() == :bash_wrapper
      assert BashWrapper.label() == "Bash wrapper"
      assert BashWrapper.kind() == :wrapper
      assert BashWrapper.requires() == ["bash"]
      assert is_list(BashWrapper.pitfalls())
    end
  end
end
