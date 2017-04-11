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

  def repo_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}}
  end

  def pulls_link owner, repo do
    ~s{#{@root_link}/repos/#{owner}/#{repo}/pulls}
  end

  def fetch_repo(owner, repo) do
    link = repo_link owner, repo
    headers = ["User-Agent": "Gstats"]
    HTTPotion.get(link, [headers: headers])
      |> Map.fetch!(:body)
      |> Poison.decode!
  end

  def fetch_pulls(owner, repo, state \\ "open") do
    link = pulls_link owner, repo
    headers = ["User-Agent": "Gstats"]
    query = %{state: state}
    response = HTTPotion.get(link, [query: query, headers: headers])

    link = ExLinkHeader.parse!(response.headers["link"])
  end

  def stats(owner, repo) do
    contents = fetch_repo(owner, repo);
    atomized = for {key, val} <- contents, into: %{}, do: {String.to_atom(key), val}
    struct(Gstats.Repo, atomized)
  end
end
