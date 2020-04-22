if Rack::Server.new.options[:Port] != 9292 # rals s -p PORT
  local_port = Rack::Server.new.options[:Port]
else
  local_port = ENV['PORT'] || '3000'
end

ENV['LOCAL_PORT'] = local_port.to_s[0] ? local_port.to_s : '3000'
