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
