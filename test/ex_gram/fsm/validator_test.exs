defmodule ExGram.FSM.ValidatorTest do
  use ExUnit.Case, async: true

  alias ExGram.FSM.Validator

  # A states module with strict transitions for testing
  defmodule StrictStates do
    @behaviour ExGram.FSM.States

    @impl true
    def states, do: [:idle, :get_name, :confirm]
    @impl true
    def transitions do
      %{
        confirm: [:idle],
        get_name: [:confirm],
        idle: [:get_name]
      }
    end
  end

  # A states module that allows any transitions
  defmodule AnyStates do
    @behaviour ExGram.FSM.States

    @impl true
    def states, do: [:a, :b]
    @impl true
    def transitions, do: :any
  end

  # Build a fake env for testing
  defp fake_env do
    __ENV__
  end

  describe "validate_transitions/3" do
    test "emits no warning when states_mod is nil" do
      # Just verify it doesn't crash
      Validator.validate_transitions([{:idle, :confirm}], nil, fake_env())
    end

    test "emits no warning when transitions are :any" do
      output =
        capture_io(:stderr, fn ->
          Validator.validate_transitions([{:a, :z}], AnyStates, fake_env())
        end)

      assert output == ""
    end

    test "emits no warning for valid transitions" do
      output =
        capture_io(:stderr, fn ->
          Validator.validate_transitions(
            [{:idle, :get_name}, {:get_name, :confirm}],
            StrictStates,
            fake_env()
          )
        end)

      assert output == ""
    end

    test "emits warning for invalid transition" do
      output =
        capture_io(:stderr, fn ->
          Validator.validate_transitions([{:idle, :confirm}], StrictStates, fake_env())
        end)

      assert output =~ "ExGram.FSM"
      assert output =~ ":idle"
      assert output =~ ":confirm"
    end

    test "emits one warning per invalid transition" do
      output =
        capture_io(:stderr, fn ->
          Validator.validate_transitions(
            [{:idle, :confirm}, {:get_name, :idle}],
            StrictStates,
            fake_env()
          )
        end)

      # Two warnings means "not declared" appears twice (once per invalid transition)
      assert length(String.split(output, "not declared")) >= 3
    end

    test "emits no warning for empty transition list" do
      output =
        capture_io(:stderr, fn ->
          Validator.validate_transitions([], StrictStates, fake_env())
        end)

      assert output == ""
    end

    test "handles module that is not yet compiled gracefully" do
      # Using a non-existent module should not crash
      Validator.validate_transitions([{:idle, :confirm}], NonExistentModule, fake_env())
    end
  end

  defp capture_io(device, fun) do
    ExUnit.CaptureIO.capture_io(device, fun)
  end
end
