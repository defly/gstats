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
    :pulls,
    :open_pulls,
    :closed_pulls,
    :subscribers_count,
    :language
  ]
end

defmodule Gstats do
  @root_link "https://api.github.com"
  @user_agent_headers ["User-Agent": "Gstats"]

  def repo_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}}
  end

  def pulls_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/pulls}
  end

  def issues_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/issues}
  end

  def fetch_repo(owner, repo) do
    link = repo_link owner, repo
    headers = ["User-Agent": "Gstats"]
    HTTPotion.get(link, [headers: headers])
      |> Map.fetch!(:body)
      |> Poison.decode!
  end

  defp body_length(response) do
    response.body |> Poison.decode! |> length
  end

  defp get_count(response) do
    count_on_page = body_length(response)
    link_header = response.headers["link"]

    if (link_header == nil) do
      count_on_page
    else
      {:ok, links} = ExLinkHeader.parse(link_header)
      last_page = String.to_integer(links.last.params.page)
      last_page_response = HTTPotion.get(links.last.url, [headers: @user_agent_headers])
      count_on_page * (last_page - 1) + body_length(last_page_response)
    end
  end

  def fetch_pulls_counters(owner, repo, state \\ "open") do
    link = pulls_link(owner, repo)
    query = %{state: state}
    HTTPotion.get(link, [query: query, headers: @user_agent_headers])
      |> get_count
  end

  def fetch_issues_counters(owner, repo, state \\ "open") do
    link = issues_link(owner, repo)
    query = %{state: state}
    HTTPotion.get(link, [query: query, headers: @user_agent_headers])
      |> get_count
  end

  def stats(owner, repo) do
    contents = fetch_repo(owner, repo);
    atomized = for {key, val} <- contents, into: %{}, do: {String.to_atom(key), val}
    repo_stats = struct(Gstats.Repo, atomized)
    open_pulls = fetch_pulls_counters(owner, repo)
    closed_pulls = fetch_pulls_counters(owner, repo, "closed")
    %{repo_stats |
      open_pulls: open_pulls,
      closed_pulls: closed_pulls,
      pulls: open_pulls + closed_pulls
    }
  end
end
