defmodule AMQP.Transaction do
  @moduledoc """
  Functions for AMQP transactions on a channel.

  Transactions apply to publishes and acknowledgements. Call `select/1` to
  enable transactions, then `commit/1` or `rollback/1` to complete a transaction.
  The channel remains in transaction mode for subsequent transactions.

  Transactions and publisher confirms cannot be enabled on the same channel.
  """

  import AMQP.Core
  alias AMQP.{Basic, Channel}

  @doc "Enables transaction mode on a channel."
  @spec select(Channel.t()) :: :ok | Basic.error()
  def select(%Channel{pid: pid}) do
    case :amqp_channel.call(pid, tx_select()) do
      tx_select_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc "Commits publishes and acknowledgements in the current transaction."
  @spec commit(Channel.t()) :: :ok | Basic.error()
  def commit(%Channel{pid: pid}) do
    case :amqp_channel.call(pid, tx_commit()) do
      tx_commit_ok() -> :ok
      error -> {:error, error}
    end
  end

  @doc "Rolls back publishes and acknowledgements in the current transaction."
  @spec rollback(Channel.t()) :: :ok | Basic.error()
  def rollback(%Channel{pid: pid}) do
    case :amqp_channel.call(pid, tx_rollback()) do
      tx_rollback_ok() -> :ok
      error -> {:error, error}
    end
  end
end
