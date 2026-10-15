require "cgi"
require "nokogiri"
require "open-uri"

module Jekyll
  module DelimitedNumberFilter
    def delimited(input)
      digits = input.to_s.gsub(/[^\d]/, "")
      return input.to_s if digits.empty?

      digits.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end

  # Homepage totals from the Google Scholar profile (citations, h-index, article count).
  class GoogleScholarMetricsGenerator < Jekyll::Generator
    safe true
    priority :high

    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    OPEN_OPTIONS = {
      "User-Agent" => USER_AGENT,
      "Accept" => "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.9",
      read_timeout: 12,
      open_timeout: 8
    }.freeze

    def generate(site)
      user = site.data.dig("socials", "scholar_userid").to_s.strip
      cache = stringify_keys(site.data["scholar_metrics"])
      return if user.empty? && cache.empty?

      live = user.empty? ? {} : fetch_metrics(user, cache)
      site.data["scholar_metrics"] = merge_metrics(cache, live)
      Jekyll.logger.info "Scholar metrics:", format_log(site.data["scholar_metrics"])
    rescue StandardError => e
      Jekyll.logger.warn "Scholar metrics:", "using cached values (#{e.class}: #{e.message})"
    end

    def fetch_metrics(user, cache)
      first = parse_profile(fetch_profile(user, 0, 100))
      return {} if first.nil? || first[:citations].to_i <= 0

      metrics = {
        "citations" => first[:citations],
        "h_index" => first[:h_index],
        "i10_index" => first[:i10_index],
        "source" => "google_scholar",
        "retrieved" => Time.now.strftime("%Y-%m-%d")
      }

      publications = complete_publication_count(user, first, cache)
      metrics["publications"] = publications if publications
      metrics
    end

    def complete_publication_count(user, first, cache)
      return first[:page_end] if last_page?(first)

      cached = cache["publications"].to_i
      if cached > 100
        start = (cached / 100) * 100
        later = parse_profile(fetch_profile(user, start, 100))
        return later[:page_end] if later && last_page?(later)
      end

      nil
    rescue StandardError => e
      Jekyll.logger.warn "Scholar metrics:", "publication count refresh failed (#{e.message})"
      nil
    end

    def fetch_profile(user, cstart, pagesize)
      url = "https://scholar.google.com/citations?user=#{CGI.escape(user)}&hl=en&cstart=#{cstart}&pagesize=#{pagesize}"
      html = fetch_html(url)
      return html unless html.to_s.empty?

      wayback = "https://web.archive.org/web/2026/https://scholar.google.com/citations?user=#{CGI.escape(user)}&hl=en"
      fetch_html(wayback) if cstart.zero?
    end

    def fetch_html(url)
      begin
        return URI.open(url, OPEN_OPTIONS).read
      rescue StandardError => e
        Jekyll.logger.warn "Scholar metrics:", "direct fetch failed for #{url}: #{e.message}"
      end

      proxy = "https://api.allorigins.win/raw?url=#{CGI.escape(url)}"
      URI.open(proxy, OPEN_OPTIONS).read
    rescue StandardError => e
      Jekyll.logger.warn "Scholar metrics:", "proxy fetch failed for #{url}: #{e.message}"
      nil
    end

    def parse_profile(html)
      return nil if html.to_s.empty?

      doc = Nokogiri::HTML(html)
      cells = doc.css("#gsc_rsb_st td.gsc_rsb_std").map { |cell| parse_int(cell.text) }
      return nil if cells.size < 3

      rows = doc.css("tr.gsc_a_tr").size
      nn = doc.at_css("#gsc_a_nn")&.text.to_s
      page_start, page_end = parse_article_range(nn)
      more = doc.at_css("#gsc_bpf_more")
      more_enabled = more && !more["disabled"] && !Array(more["class"]).include?("disabled")

      {
        citations: cells[0],
        h_index: cells[2],
        i10_index: cells[4],
        rows: rows,
        page_start: page_start,
        page_end: page_end || (page_start ? page_start + rows - 1 : rows),
        more_enabled: more_enabled
      }
    end

    def last_page?(parsed)
      return false if parsed.nil?
      return true if parsed[:page_end].to_i > 20 && parsed[:more_enabled] == false
      return true if parsed[:rows].to_i.positive? && parsed[:rows].to_i < 100 && parsed[:page_start].to_i > 1

      false
    end

    def parse_article_range(text)
      match = text.match(/(\d+)\s*[–-]\s*(\d+)/)
      return [nil, nil] unless match

      [match[1].to_i, match[2].to_i]
    end

    def parse_int(text)
      text.to_s.gsub(/[^\d]/, "").to_i
    end

    def stringify_keys(hash)
      return {} unless hash.is_a?(Hash)

      hash.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
    end

    def merge_metrics(cache, live)
      merged = cache.merge(live) do |key, old_val, new_val|
        next old_val if new_val.nil? || new_val.to_s.empty?
        next old_val if %w[publications citations h_index i10_index].include?(key) && new_val.to_i <= 0

        new_val
      end
      %w[publications citations h_index i10_index].each do |key|
        merged[key] = merged[key].to_i if merged.key?(key)
      end
      merged
    end

    def format_log(metrics)
      "#{metrics["publications"]} pubs / #{metrics["citations"]} cites / h=#{metrics["h_index"]}"
    end
  end
end

Liquid::Template.register_filter(Jekyll::DelimitedNumberFilter)
