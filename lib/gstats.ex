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

  defp body_length(response) do
    response.body |> Poison.decode! |> length
  end

  def fetch_pulls(owner, repo, state \\ "open") do
    link = pulls_link(owner, repo)
    headers = ["User-Agent": "Gstats"]
    query = %{state: state}
    response = HTTPotion.get(link, [query: query, headers: headers])
    count_on_page = body_length(response)
    link_header = response.headers["link"]

    if (link_header == nil) do
      count_on_page
    else
      {:ok, links} = ExLinkHeader.parse(link_header)
      last_page = String.to_integer(links.last.params.page)
      last_page_response = HTTPotion.get(links.last.url, [headers: headers])
      count_on_page * (last_page - 1) + body_length(last_page_response)
    end
  end

  def stats(owner, repo) do
    contents = fetch_repo(owner, repo);
    atomized = for {key, val} <- contents, into: %{}, do: {String.to_atom(key), val}
    struct(Gstats.Repo, atomized)
  end
end
