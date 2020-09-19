require 'twitter'

ENVIRONMENT = {
	TWITTER_CONSUMER_KEY: ARGV[0],
	TWITTER_CONSUMER_SECRET: ARGV[1],
	TWITTER_ACCESS_TOKEN: ARGV[2],
	TWITTER_ACCESS_TOKEN_SECRET: ARGV[3]
}

$client
def twitter_client
	return $client ||= Twitter::REST::Client.new{|config|
		config.consumer_key = ENVIRONMENT[:TWITTER_CONSUMER_KEY]
		config.consumer_secret = ENVIRONMENT[:TWITTER_CONSUMER_SECRET]
		config.access_token = ENVIRONMENT[:TWITTER_ACCESS_TOKEN]
		config.access_token_secret = ENVIRONMENT[:TWITTER_ACCESS_TOKEN_SECRET]
	}
end

def get_orig_image_uri s
	"#{s}?name=orig"
end

query = File.open('query.txt'){_1.gets}.chomp
puts "query: #{query}"

allowlist = File.open('allowlist.txt'){|f|
	f.each_line.map{|l| l.split.first.to_i}
}
puts "allowlist: #{allowlist}"

N = 50

result_tweets = twitter_client.search(
	query,
	count: N,
	result_type: 'recent',
)

puts

auto_mode = true

image_uri = nil

if auto_mode
	result_tweets.take(N).each{|tw|
		if allowlist.include? tw.user.id #or true
			sleep 10
			t = (if tw.retweet?
				tw.retweeted_status
			else
				twitter_client.status(tw, tweet_mode: 'extended')
			end)

			if t.media?
				image_uri = get_orig_image_uri t.media.first.media_uri_https
			elsif t.uris.length > 0
				t.uris.each{
					if _1.expanded_url.to_s.start_with? 'https://twitter.com'
						sleep 5
						t = twitter_client.status(_1.expanded_url, tweet_mode: 'extended')
						if t.media?
							image_uri = get_orig_image_uri t.media.first.media_uri_https
						end
					end
					break if image_uri
				}
			end
		end

		break if image_uri
	}
else
	sleep 5
	t = twitter_client.status(File.open('manual_url.txt'){_1.gets}.chomp, tweet_mode: 'extended')
	if t.media?
		image_uri = get_orig_image_uri t.media.first.media_uri_https
	end
end

image_uri ||= 'https://ureishi.github.io/hitokoto/hitokoto.jpg'

puts "image_uri: #{image_uri}"

file_name = 'hitokoto.jpg'
# 試行回数3回 タイムアップ3秒 待機時間3秒
command = "wget -t 3 -T 3 -w 3 -O #{file_name} #{image_uri}"
`#{command}`
