Server = get_server_class
r = Server::Request.new
cache = Userdata.new.shared_cache
global_mutex = Userdata.new.shared_mutex

# max_clients_handler config store
config_store = Userdata.new.shared_config_store

file = r.filename

# Also add config into access_limiter_end.rb
config = {
  # access limmiter by target
  :target => file,
}

limit = AccessLimiter.new r, cache, config
max_clients_handler = MaxClientsHandler.new(
  limit,
  config_store
)

if max_clients_handler.config
  # process-shared lock
  timeout = global_mutex.try_lock_loop(50000) do
    begin
      Server.errlogger Server::LOG_INFO, "access_limiter: cleanup_counter: file:#{file}" if limit.cleanup_counter
      limit.increment
      current = limit.current
      Server.errlogger Server::LOG_INFO, "access_limiter: increment: file:#{file} counter:#{current}"
      if max_clients_handler.limit?
        Server.errlogger Server::LOG_INFO, "access_limiter: file:#{file} reached threshold: #{max_clients_handler.max_clients}: return #{Server::HTTP_SERVICE_UNAVAILABLE}"
        Server.return Server::HTTP_SERVICE_UNAVAILABLE
      end
    rescue => e
      raise "AccessLimiter failed: #{e}"
    ensure
      global_mutex.unlock
    end
  end
  if timeout
    Server.errlogger Server::LOG_INFO, "access_limiter: get timeout lock, #{file}"
  end
end
