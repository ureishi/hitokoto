require 'json'
require 'mini_magick'
require 'net/https'
require 'twitter'
require 'uri'

puts `ruby --version`

### get image from twitter
puts 'get image...'

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

tweet_urls = URI.open(list_url).read.split("\n").sample(5)
puts "tweet_urls:\n\t#{tweet_urls.join "\n\t"}"

#tweet_urls[0] = "https://twitter.com/chokakuji/status/1317956366795894784"

tweets = tweet_urls.map{twitter_client.status _1, tweet_mode: 'extended'}

image_uris = tweets.map{"#{_1.media.first.media_uri_https}?name=orig" if _1 && _1.media?}
puts "image_uris:\n\t#{image_uris.join "\n\t"}"

### create directory
puts 'create directory...'
Dir.mkdir 'public' unless Dir.exists? 'public'
puts 'created: public'

### create image
puts 'create hitokoto.jpg (for forward compatibility)'
SIZE_LEGACY = '1920x1080'
MiniMagick::Tool::Convert.new{
	_1.size SIZE_LEGACY
	_1 << 'canvas:#2f2725'
	_1 << 'base_legacy.jpg'
}

MiniMagick::Image
.open('base_legacy.jpg')
.composite(
	MiniMagick::Image
	.open(image_uris.first || 'default.png')
	.resize(SIZE_LEGACY)
){
	_1.compose 'Over'
	_1.gravity 'Center'
	_1.geometry "+0+0"
}
.write('public/hitokoto.jpg')
puts 'created: hitokoto.jpg'

puts 'create images...'
BASE_W = 1024
BASE_H = 1448
SIZE = 1000
NEW_ICON_X = [-146, -48, 0, 50, 148]
FONT_SERIF = '.font/Noto_Serif_JP/NotoSerifJP-Regular.otf'
FONT_SANS = '.font/Noto_Sans_JP/NotoSansJP-Regular.otf'

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

image.write 'base.png'
puts 'created: base.png'

tweets.length.times{|p|
	image = MiniMagick::Image
	.open('base.png')
	.combine_options{
		pos = '0, 152'
		text = "#{tweets[p].user.name}"[..30]
		_1.font FONT_SERIF
		_1.fill '#fcfcfc'
		_1.gravity 'North'
		_1.pointsize 30
		_1.draw "text #{pos} '#{text}'"
	}
	.combine_options{
		pos = '0, 186'
		text = "@#{tweets[p].user.screen_name}"
		_1.font FONT_SANS
		_1.fill '#fcfcfc'
		_1.gravity 'North'
		_1.pointsize 25
		_1.draw "text #{pos} '#{text}'"
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
		pos = '5, 117'
		text = "更新管理者Discord: すいかい#9599"
		_1.font FONT_SANS
		_1.fill '#fcfcfc'
		_1.gravity 'SouthEast'
		_1.pointsize 20
		_1.draw "text #{pos} '#{text}'"
	}
	.composite(
		MiniMagick::Image
		.open(image_uris[p] || 'default.png')
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