defmodule Gstats.Repo do
  defstruct [
    :name,
    :description,
    :created_at,
    :updated_at,
    :pushed_at,
    :watchers,
    :forks,
    :open_issues,
    :closed_issues,
    :issues,
    :pulls,
    :open_pulls,
    :closed_pulls,
    :subscribers_count,
    :language,
    :license,
    :contributors
  ]
end

defmodule Gstats do
  require Logger
  @root_link "https://api.github.com"
  @headers [
    "User-Agent": "Gstats",
    "Accept": "application/vnd.github.drax-preview+json",
    "Authorization": ~s{token #{Application.get_env(:gstats, :token)}}
  ]

  def client(url) do
    HTTPotion.get(url, [headers: @headers])
  end

  def client(url, query) do
    HTTPotion.get(url, [query: query, headers: @headers])
  end

  def repo_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}}
  end

  def pulls_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/pulls}
  end

  def issues_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/issues}
  end

  def contributors_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/contributors}
  end

  def fetch_repo(owner, repo) do
    repo_link(owner, repo)
      |> client
      |> Map.fetch!(:body)
      |> Poison.decode!
  end

  defp body_length(response) do
    response.body
      |> Poison.decode!
      |> length
  end

  defp get_count_with_paging(nil, count_on_page) do
    count_on_page
  end

  defp get_count_with_paging(link_header, count_on_page) do
    {:ok, links} = ExLinkHeader.parse(link_header)
    last_page = String.to_integer(links.last.params.page)
    last_page_response = client(links.last.url)
    count_on_page * (last_page - 1) + body_length(last_page_response)
  end

  defp get_count(response) do
    count_on_page = body_length(response)
    link_header = response.headers["link"]
    get_count_with_paging(link_header, count_on_page)
  end

  defp counter_client(link) do
    link
      |> client
      |> get_count
  end

  defp counter_client(link, state) do
    link
      |> client(%{state: state})
      |> get_count
  end

  def fetch_pulls_counters(owner, repo, state \\ "open") do
    pulls_link(owner, repo)
      |> counter_client(state)
  end

  def fetch_issues_counters(owner, repo, state \\ "open") do
    issues_link(owner, repo)
      |> counter_client(state)
  end

  def fetch_contributors_counters(owner, repo) do
    contributors_link(owner, repo)
      |> counter_client
  end

  def fetch_repo_stats(owner, repo) do
    atomized = for {key, val} <- fetch_repo(owner, repo), into: %{}, do: {String.to_atom(key), val}
    struct(Gstats.Repo, atomized)
  end

  defp rescue_task(func) do
    fn() ->
      try do
        func.()
      catch
          _, reason -> {:error, reason}
      end
    end
  end

  defp gen_task_list(owner, repo) do
    [
      fn -> fetch_repo_stats(owner, repo) end,
      fn -> %{open_pulls: fetch_pulls_counters(owner, repo)} end,
      fn -> %{closed_pulls: fetch_pulls_counters(owner, repo, "closed")} end,
      fn -> %{open_issues: fetch_issues_counters(owner, repo)} end,
      fn -> %{closed_issues: fetch_issues_counters(owner, repo, "closed")} end,
      fn -> %{contributors: fetch_contributors_counters(owner, repo)} end
    ]
  end

  def task_has_errors?(task_results) do
    Enum.any?(task_results, &match?({:error, _}, &1))
  end

  defp process_task_results(task_results) do
    if task_has_errors?(task_results) do
      IO.inspect Enum.filter(task_results, &match?({:error, _}, &1))
      Logger.error "One of task failed"
      {:error, "One of task failed"}
    else
      Enum.reduce(task_results, &struct(&2, &1))
    end
  end

  def stats(owner, repo) do
    gen_task_list(owner, repo)
      |> Enum.map(&rescue_task(&1))
      |> Enum.map(&Task.async(&1))
      |> Enum.map(&Task.await(&1))
      |> process_task_results
  end

  def measure do
    startSecond = DateTime.utc_now().second
    result = stats("facebook", "react")
    endSecond = DateTime.utc_now().second
    IO.inspect "Start: #{startSecond}, End: #{endSecond}"
    result
  end
end
