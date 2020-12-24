ExUnit.start()

defmodule AMQP.ConnectionCheck do
  @max_retry 30

  def do_check(retry \\ 0) do
    case AMQP.Connection.open() do
      {:ok, conn} ->
        :ok = AMQP.Connection.close(conn)

      {:error, reason} ->
        message = "Cannot connect to RabbitMQ(amqp://localhost:5672): #{inspect(reason)}"

        if retry < @max_retry do
          IO.puts("#{message} (retrying...)")
          :timer.sleep(1000)
          do_check(retry + 1)
        else
          Mix.raise(message)
        end
    end
  end
end

AMQP.ConnectionCheck.do_check()
