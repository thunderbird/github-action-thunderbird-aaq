# Raised by getKitsuneResponse when SUMO serves a JavaScript/bot challenge
# (e.g. a Cloudflare "Just a moment…" page) instead of JSON. Callers should log
# it via log_javascript_challenge and abort the run rather than silently treating
# the day as empty.
class JavascriptChallengeError < StandardError
  attr_reader :url, :response_code, :snippet

  def initialize(url:, response_code:, snippet:)
    @url = url
    @response_code = response_code
    @snippet = snippet
    super("JavaScript/bot challenge detected (HTTP #{response_code}) for #{url}")
  end
end

# Well-known substrings present in bot/JS challenge interstitials (Cloudflare and
# similar). Matched case-insensitively against the response body.
JS_CHALLENGE_MARKERS = [
  'just a moment',
  'cdn-cgi/challenge-platform',
  'cf-browser-verification',
  '_cf_chl_opt',
  'checking your browser before accessing',
  'enable javascript and cookies to continue',
  'please enable javascript',
  'ddos protection by',
  'attention required! | cloudflare'
].freeze

# True when an HTTP body looks like a JavaScript/bot challenge rather than the
# expected JSON. An HTML content-type (or an <html> body) gated by a <noscript>
# block or a "challenge" reference is treated as a corroborating signal.
def javascript_challenge?(body, content_type)
  return false if body.nil?

  text = body.to_s.downcase
  return true if JS_CHALLENGE_MARKERS.any? { |m| text.include?(m) }

  html = content_type.to_s.downcase.include?('text/html') || text.include?('<html')
  html && (text.include?('<noscript') || text.include?('challenge'))
end

# Append-only log file for detected challenges. Resolved relative to this helper
# (repo root) so it lands in the same place regardless of the script's cwd — the
# fetch scripts run from inside a year directory (e.g. 2025/).
JS_CHALLENGE_LOG = File.join(__dir__, 'javascript-challenges.log')

# Records a detected JavaScript/bot challenge: one line appended to
# JS_CHALLENGE_LOG (for audit over time) and mirrored to the logger at error
# level. context may include :script and :args for traceability.
def log_javascript_challenge(logger, error, context = {})
  stamp = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S %z')
  line = [stamp, context[:script], "HTTP #{error.response_code}",
          error.url, context[:args],
          error.snippet.to_s.gsub(/\s+/, ' ')[0, 300]].compact.join(' | ')
  File.open(JS_CHALLENGE_LOG, 'a') { |f| f.puts(line) }
  logger.error("JAVASCRIPT CHALLENGE: #{line}")
end

def getKitsuneResponse(url, params, logger)
  logger.debug "url in getKitsuneResponse: #{url}"
  logger.debug "params in getKitsuneResponse: #{params}"
  try_count = 0
  begin
    result = Typhoeus::Request.get(
      url,
      params: params
    )
    response_code = result.code
    logger.debug "response_code: #{response_code}"

    x = JSON.parse(result.body)
  rescue JSON::ParserError
    content_type = result&.headers && result.headers['Content-Type']
    if javascript_challenge?(result&.body, content_type)
      # A challenge won't clear by re-requesting the same URL, so don't retry —
      # raise so the caller can log it and abort instead of writing an empty CSV.
      raise JavascriptChallengeError.new(
        url: url, response_code: response_code,
        snippet: result.body.to_s.strip[0, 500]
      )
    end
    try_count += 1
    if try_count < 4
      logger.debug "JSON::ParserError exception, response code: #{response_code}" \
       "retry: #{try_count}"
      if [429, 502, 500].include?(response_code)
        sleep(60)
      else
        sleep(2)
      end
      retry
    else
      $stderr.printf("JSON::ParserError exception, re-trying FAILED\n")
      x = nil
    end
  end
  x
end
