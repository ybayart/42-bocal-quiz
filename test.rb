#!/usr/bin/ruby

require 'slack-ruby-client'
require 'async'
require 'dotenv'
require 'oauth2'

Dotenv.load

raise 'Missing ENV[SLACK_API_TOKENS]!' unless ENV.key?('SLACK_API_TOKENS')
raise 'Missing ENV[API_CLIENT]!' unless ENV.key?('API_CLIENT')
raise 'Missing ENV[API_SECRET]!' unless ENV.key?('API_SECRET')

apiclient = OAuth2::Client.new(ENV['API_CLIENT'], ENV['API_SECRET'], site: "https://api.intra.42.fr")
apitoken = apiclient.client_credentials.get_token

$stdout.sync = true
logger = Logger.new($stdout)
logger.level = Logger::DEBUG

threads = []

ENV['SLACK_API_TOKENS'].split.each do |token|
	logger.info "Starting #{token[0..12]} ..."

	client = Slack::RealTime::Client.new(token: token)

    client.on :hello do
        logger.info(
            "Successfully connected, welcome '#{client.self.name}' to " \
            "the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
        )
    end

	client.on :message do |data|
		username = client.web_client.users_info(user: data.user).user.name
		query = apitoken.get("/v2/users/#{username}/coalitions").parsed
		coalitions = []
	   for coa in query do
		   coalitions << coa['name']
	   end
		puts coalitions.join(", ")
	end

	threads << client.start_async
end

threads.each(&:join)
