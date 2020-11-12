defmodule ChromicPDF.GhostscriptPool do
  @moduledoc false

  @behaviour NimblePool

  alias ChromicPDF.GhostscriptWorker

  @cores System.schedulers_online()
  @default_pool_size Application.compile_env(:chromic_pdf, :default_pool_size, div(@cores, 2))

  # ------------- API ----------------

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    NimblePool.start_link(
      worker: {__MODULE__, args},
      pool_size: pool_size(args),
      name: name(args)
    )
  end

  defp pool_size(args) do
    get_in(args, [:ghostscript_pool, :size]) || @default_pool_size
  end

  # Converts a PDF to PDF-A/2 using Ghostscript.
  @spec convert(atom(), binary(), keyword(), binary()) :: :ok
  def convert(chromic, pdf_path, params, output_path) do
    NimblePool.checkout!(name(chromic), :checkout, fn _from, _worker_state ->
      {GhostscriptWorker.convert(pdf_path, params, output_path), :ok}
    end)
  end

  defp name(args) when is_list(args), do: args |> Keyword.fetch!(:chromic) |> name()
  defp name(chromic) when is_atom(chromic), do: Module.concat(chromic, :GhostscriptPool)

  # ------------ Callbacks -----------

  @impl NimblePool
  def init_worker(pool_state) do
    {:ok, nil, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, worker_state, pool_state) do
    {:ok, worker_state, worker_state, pool_state}
  end
end