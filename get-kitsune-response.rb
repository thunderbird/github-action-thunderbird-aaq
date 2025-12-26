def getKitsuneResponse(url, params, logger)
  logger.debug "url in getKitsuneResponse: #{url}"
  logger.debug "params in getKitsuneResponse: #{params}"
  try_count = 0
  begin
    result = Typhoeus::Request.get(
      url,
      params: params
    )
    logger.debug "result: #{result.ai}"
    x = JSON.parse(result.body)
  rescue JSON::ParserError
    try_count += 1
    if try_count < 4
      $stderr.printf("JSON::ParserError exception, retry:%d\n",\
                     try_count)
      sleep(2)
      retry
    else
      $stderr.printf("JSON::ParserError exception, retrying FAILED\n")
      x = nil
    end
  end
  x
end
