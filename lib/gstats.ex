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
  @root_link "https://api.github.com"
  @user_agent_headers [
    "User-Agent": "Gstats",
    "Accept": "application/vnd.github.drax-preview+json"
  ]

  def client(url) do
    HTTPotion.get(url, [headers: @user_agent_headers])
  end

  def client(url, query) do
    HTTPotion.get(url, [query: query, headers: @user_agent_headers])
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

  defp get_count(response) do
    count_on_page = body_length(response)
    link_header = response.headers["link"]

    if (link_header == nil) do
      count_on_page
    else
      {:ok, links} = ExLinkHeader.parse(link_header)
      last_page = String.to_integer(links.last.params.page)
      last_page_response = client(links.last.url)
      count_on_page * (last_page - 1) + body_length(last_page_response)
    end
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

  def stats(owner, repo) do
    # repo_stats = fetch_repo_stats(owner, repo)
    # open_pulls = fetch_pulls_counters(owner, repo)

    get_repo = fn -> fetch_repo_stats(owner, repo) end
    get_open_pulls = fn -> %{open_pulls: fetch_pulls_counters(owner, repo)} end
    get_closed_pulls = fn -> %{closed_pulls: fetch_pulls_counters(owner, repo, "closed")} end

    task_list = [
      get_repo,
      get_open_pulls,
      get_closed_pulls
    ]

    resc = fn(func) ->
      fn() ->
        try do
          func.()
          throw("wtf")
        catch
            x, y -> "#{x}, #{y}"
        end
      end
    end

    #
    task_list
      |> Enum.map(resc)
      |> Enum.map(&Task.async(&1))
      |> Enum.map(&Task.await(&1))
      # |> Enum.reduce(&struct(&2, &1))

      # task_list = [struct(Gstats.Repo), %{open_pulls: 154}];
      # task_list
      #   |> Enum.reduce(&struct(&2, &1))



    # closed_pulls = fetch_pulls_counters(owner, repo, "closed")
    # open_issues = fetch_issues_counters(owner, repo)
    # closed_issues = fetch_issues_counters(owner, repo, "closed")
    # contributors = fetch_contributors_counters(owner, repo)
    # %{repo_stats |
      # open_pulls: open_pulls,
      # closed_pulls: closed_pulls,
      # pulls: open_pulls + closed_pulls,
      # open_issues: open_issues,
      # closed_issues: closed_issues,
      # issues: open_issues + closed_issues,
      # contributors: contributors
    # }
  end
end
