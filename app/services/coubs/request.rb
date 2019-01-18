class Coubs::Request
  method_object :tag, :page

  COUB_TEMPLATE = 'https://coub.com/api/v2/timeline/tag/%<tag>s?page=%<page>i'
  PER_PAGE = 10

  EXPIRES_IN = 1.month
  EXCEPTIONS = Network::FaradayGet::NET_ERRORS

  NO_DATA_RESPONSE = {
    coubs: [],
    per_page: PER_PAGE
  }.to_json

  def call
    Retryable.retryable tries: 2, on: EXCEPTIONS, sleep: 1 do
      PgCache.fetch pg_cache_key, expires_in: EXPIRES_IN do
        convert verify(parse(fetch))
      end
    end
  rescue *EXCEPTIONS
    nil
  end

  def self.pg_cache_key tag:, page:
    [:coub, tag, page].join('|')
  end

private

  def pg_cache_key
    self.class.pg_cache_key(
      tag: @tag,
      page: @page
    )
  end

  def convert data
    data[:coubs].map do |entry|
      build_entry entry
    end
  end

  def build_entry entry
    Coub::Entry.new(
      permalink: entry[:permalink],
      image_template: entry[:image_versions][:template],
      categories: entry[:categories].map { |v| v[:permalink] },
      tags: entry[:tags].map { |v| URI.unescape v[:value] },
      title: entry[:title],
      author: build_author(entry[:channel]),
      recoubed_permalink: entry.dig(:media_blocks, :remixed_from_coubs, 0, :coub_permalink),
      created_at: entry[:created_at]
    )
  end

  def build_author channel
    Coub::Author.new(
      permalink: channel[:permalink],
      name: channel[:title],
      avatar_template: channel[:avatar_versions][:template]
    )
  end

  def verify data
    if data[:per_page] != PER_PAGE
      raise "invalid response for tag `#{@tag}`"
    end

    data
  end

  def parse response
    JSON.parse response, symbolize_names: true
  end

  def fetch
    OpenURI.open_uri(coub_url, 'User-Agent' => 'shikimori.org').read
  rescue OpenURI::HTTPError => e
    if e.message == '404 Not Found'
      NO_DATA_RESPONSE
    else
      raise
    end
  end

  def coub_url
    format COUB_TEMPLATE, tag: URI.escape(@tag), page: @page
  end
end