Server = get_server_class
r = Server::Request.new
global_mutex = Userdata.new.shared_mutex

file = r.filename

# Also add config into access_limiter_end.rb
config = {
  # access limmiter by target
  :target => file,
}

unless r.sub_request?
  limit = AccessLimiter.new config
  max_clients_handler = MaxClientsHandler.new(
    limit,
    "/access_limiter/max_clients_handler.lmc"
  )
  if max_clients_handler.config
    # process-shared lock
    timeout = global_mutex.try_lock_loop(50000) do
      begin
        limit.increment
        current = limit.current
        Server.errlogger Server::LOG_NOTICE, "access_limiter: increment: file:#{file} counter:#{current}"
        if max_clients_handler.limit?
          Server.errlogger Server::LOG_NOTICE, "access_limiter: file:#{file} reached threshold: #{max_clients_handler.max_clients}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
          Server.return Server::HTTP_SERVICE_UNAVAILABLE
        end
      rescue => e
        raise "AccessLimiter failed: #{e}"
      ensure
        global_mutex.unlock
      end
    end
    if timeout
      Server.errlogger Server::LOG_NOTICE, "access_limiter: get timeout lock, #{file}"
    end
  end
end