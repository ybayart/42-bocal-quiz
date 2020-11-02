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

$stdout.sync = true
logger = Logger.new($stdout)
logger.level = Logger::INFO

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

	response = ""
	findable = 0

	client.on :message do |data|
		logger.debug data

		if data.user != ENV['BOT_USER_ID'] && data.user != "USLACKBOT"
			if data.key?("text")

				case data.channel
				when ENV['CHANNEL_MASTER']
					data.text = data.text.downcase
					if data.text == "disable"
						findable = 0
						client.message channel: data.channel, text: "Game is now over"
						logger.info("Game is now over")
					elsif data.text.split(" ")[0] == "set"
						response = data.text.split(" ")[1..-1].join(" ").to_s.downcase
						client.typing channel: data.channel
						client.message channel: data.channel, text: "word is now `#{response}`"
						logger.info("word is now #{response}")
						findable = 1
					end
				when ENV['CHANNEL_USER']
					if findable == 1 && data.text.parameterize == response.parameterize
						findable = 0
						client.typing channel: data.channel
						client.message channel: data.channel, text: "Congratulation <@#{data.user}>"
						coalitions = []
						begin
							username = client.web_client.users_info(user: data.user).user.name
							apitoken = apiclient.client_credentials.get_token
							query = apitoken.get("/v2/users/#{username}/coalitions").parsed
							for coa in query do
								coalitions << coa['name']
							end
						rescue => e
							logger.info "Error" + e.to_s
							coalitions << "Unknown"
						end
						client.web_client.chat_postMessage(channel: ENV['CHANNEL_MASTER'], text: "Winner: <@#{data.user}> (#{coalitions.join(', ')}) for word `#{response}`", as_user: true)
						logger.info("Winner: #{username} (#{coalitions.join(', ')}) for word #{response}")
					end
				end
			end
		end
	end

	threads << client.start_async
end

threads.each(&:join)
