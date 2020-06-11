require 'twitter'

ENVIRONMENT = {
	'TWITTER_CONSUMER_KEY' => ARGV[0],
	'TWITTER_CONSUMER_SECRET' => ARGV[1],
	'TWITTER_ACCESS_TOKEN' => ARGV[2],
	'TWITTER_ACCESS_TOKEN_SECRET' => ARGV[3]
}

$client
def twitter_client
	return $client ||= Twitter::REST::Client.new{|config|
		config.consumer_key = ENVIRONMENT['TWITTER_CONSUMER_KEY']
		config.consumer_secret = ENVIRONMENT['TWITTER_CONSUMER_SECRET']
		config.access_token = ENVIRONMENT['TWITTER_ACCESS_TOKEN']
		config.access_token_secret = ENVIRONMENT['TWITTER_ACCESS_TOKEN_SECRET']
	}
end

query = File.open('query.txt'){_1.gets}.chomp
puts "query: #{query}"

whitelist = File.open("whitelist.txt"){|f|
	f.each_line.map{|l| l.split.first.to_i}
}
puts "whitelist: #{whitelist}"

result_tweets = twitter_client.search(
	query,
	count: 100,
	result_type: 'recent'
)

image_uri = ''
result_tweets.take(100).each{|tw|
	if tw.media? and whitelist.include? tw.user.id
		image_uri = "#{tw.media.first.media_uri_https}?format=jpg&name=orig"
		break
	end
}

puts "image_uri: #{image_uri}"

if not image_uri.empty?
	file_name = 'hitokoto.jpg'
	# 試行回数3回 タイムアップ3秒 待機時間3秒
	command = "wget -t 3 -T 3 -w 3 -O #{file_name} #{image_uri}"
	`#{command}`
end
