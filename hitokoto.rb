require 'json'
require 'mini_magick'
require 'net/https'
require 'twitter'
require 'uri'

puts `ruby --version`

### get image from twitter
puts 'get images...'

ENVIRONMENT = {
	TWITTER_CONSUMER_KEY: ARGV[0],
	TWITTER_CONSUMER_SECRET: ARGV[1],
	TWITTER_ACCESS_TOKEN: ARGV[2],
	TWITTER_ACCESS_TOKEN_SECRET: ARGV[3]
}

def twitter_client
	$client ||= Twitter::REST::Client.new{
		_1.consumer_key = ENVIRONMENT[:TWITTER_CONSUMER_KEY]
		_1.consumer_secret = ENVIRONMENT[:TWITTER_CONSUMER_SECRET]
		_1.access_token = ENVIRONMENT[:TWITTER_ACCESS_TOKEN]
		_1.access_token_secret = ENVIRONMENT[:TWITTER_ACCESS_TOKEN_SECRET]
	}
end

list_url = 'https://raw.githubusercontent.com/suicai/hitokoto-list/main/list.txt'
puts "get tweet urls from #{list_url}"

tweet_urls = URI.open(list_url).read.split("\n").sample(5).map{_1.split('#').first.strip}
puts "tweet_urls:\n\t#{tweet_urls.join "\n\t"}"

#tweet_urls[0] = 'https://twitter.com/SUICAIVRC/status/1272845751769391105'

tweets = tweet_urls.map{tw = twitter_client.status _1, tweet_mode: 'extended' rescue nil; sleep 10; tw}

image_uris = tweets.map{"#{_1.media.first.media_uri_https}?name=orig" if _1 && _1.media?}
puts "image_uris:\n\t#{image_uris.join "\n\t"}"

### create directory
puts 'create directory...'
Dir.mkdir 'public' unless Dir.exists? 'public'
puts 'created: public'

### create image
FONT_SERIF = '.font/Noto_Serif_JP/NotoSerifJP-Regular.otf'
FONT_SANS = '.font/Noto_Sans_JP/NotoSansJP-Regular.otf'

puts 'create hitokoto.jpg (for forward compatibility)'
SIZE_LEGACY = "1920x1080"
r = 20
SIZE_LEGACY_IMAGE = "#{1920-16*r}x#{1080-9*r}"
MiniMagick::Tool::Convert.new{
	_1.size SIZE_LEGACY
	_1 << 'canvas:#2f2725'
	_1 << 'base_legacy.jpg'
}

MiniMagick::Image
.open('base_legacy.jpg')
.composite(
	MiniMagick::Image
	.open(image_uris.first || 'not_found.png')
	.resize(SIZE_LEGACY_IMAGE)
){
	_1.compose 'Over'
	_1.gravity 'Center'
	_1.geometry "+0+0"
}
.combine_options{
	pos = '0, 10'
	text = tweets.first ? "#{tweets.first.user.name}"[..30] : "ERROR: TWEET NOT FOUND"
	_1.font FONT_SERIF
	_1.fill '#fcfcfc'
	_1.gravity 'North'
	_1.pointsize 30
	_1.draw "text #{pos} '#{text}'"
}
.combine_options{
	pos = '0, 45'
	text = tweets.first && image_uris.first ? "@#{tweets.first.user.screen_name}\t(#{tweets.first.created_at.getlocal('+09:00').strftime("%Y年%m月%d日 %H時%M分%S秒 JST")})" : tweet_urls.first
	_1.font FONT_SANS
	_1.fill '#fcfcfc'
	_1.gravity 'North'
	_1.pointsize 25
	_1.draw "text #{pos} '#{text}'"
}
.write('public/hitokoto.jpg')
puts 'created: hitokoto.jpg'

puts 'create images...'
BASE_W = 1024
BASE_H = 1448
SIZE = 1000

MiniMagick::Tool::Convert.new{
	_1.size "#{BASE_W}x#{BASE_H}"
	_1 << 'canvas:#2f2725'
	_1 << 'base.png'
}

image = MiniMagick::Image
.open('base.png')
.combine_options{
	pos = '0, 0'
	text = '今日のことば'
	_1.font FONT_SERIF
	_1.fill '#fcfcfc'
	_1.gravity 'North'
	_1.pointsize 125
	_1.draw "text #{pos} '#{text}'"
}
.combine_options{
	margin = 3
	pos_nw = "#{margin}, #{BASE_H - 120 + margin}"
	pos_se = "#{BASE_W - margin}, #{BASE_H - margin}"
	_1.fill '#0d3e59'
	_1.draw "rectangle #{pos_nw} #{pos_se}"
}
.combine_options{
	pos = '5, 117'
	text = "※写真の権利は撮影者に帰属します。\n※宗派を問わず気まぐれに更新されます。\n※営利・勧誘目的ではありません。"
	_1.font FONT_SERIF
	_1.fill '#fcfcfc'
	_1.gravity 'SouthWest'
	_1.pointsize 20
	_1.draw "text #{pos} '#{text}'"
}
.combine_options{
	pos = '600, 117'
	text = "「VRChat 今日のことば」\nBOOTHにて配布中\n更新管理者Discord: すいかい#9599"
	_1.font FONT_SANS
	_1.fill '#fcfcfc'
	_1.gravity 'SouthWest'
	_1.pointsize 20
	_1.draw "text #{pos} '#{text}'"
}
.composite(
	MiniMagick::Image
	.open('qr.png')
	.resize("100x100")
){
	_1.compose 'Over'
	_1.gravity 'SouthEast'
	_1.geometry "+3+120"
}

image.write 'base.png'
puts 'created: base.png'

tweets.length.times{|p|
	image = MiniMagick::Image
	.open('base.png')
	.combine_options{
		pos = '0, 152'
		text = tweets[p] ? "#{tweets[p].user.name}"[..30] : "ERROR: TWEET NOT FOUND"
		_1.font FONT_SERIF
		_1.fill '#fcfcfc'
		_1.gravity 'North'
		_1.pointsize 30
		_1.draw "text #{pos} '#{text}'"
	}
	.combine_options{
		pos = '0, 186'
		text = tweets[p] && image_uris[p] ? "@#{tweets[p].user.screen_name}\t(#{tweets[p].created_at.getlocal('+09:00').strftime("%Y年%m月%d日 %H時%M分%S秒 JST")})" : tweet_urls[p]
		_1.font FONT_SANS
		_1.fill '#fcfcfc'
		_1.gravity 'North'
		_1.pointsize 25
		_1.draw "text #{pos} '#{text}'"
	}
	.composite(
		MiniMagick::Image
		.open(image_uris[p] || 'not_found.png')
		.resize("#{SIZE}x#{SIZE}")
	){
		_1.compose 'Over'
		_1.gravity 'Center'
		_1.geometry "+0+0"
	}
	
	image.write "public/hitokoto#{p}.png"
	puts "created: hitokoto#{p}.png"
}

### optimize
puts "optimize"
`pngquant --force --ext .png --speed 1 public/hitokoto*.png`
`advpng -z -4 -i 10 public/hitokoto*.png`

puts "finished"
