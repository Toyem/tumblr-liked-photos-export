require 'httparty'

require_relative 'config'
require_relative 'tumblr_download'
require_relative 'tumblr_database'

# Configuration
api_key      = ENV["TUMBLR_API_KEY"]
username     = ARGV[0] || ENV["TUMBLR_USERNAME"]
image_dir    = ARGV.count == 2 ? ARGV[1] : (ARGV[1] || "images")
limit        = 20  # number of posts requested each time

class TumblrPhotoExport

  attr_accessor :image_dir, :limit, :tumblr_db, :tumblr_download, :tumblr_config

  def initialize(image_dir, limit, api_key=nil, username=nil)

    @image_dir          = image_dir
    @limit              = limit
    @download_num       = nil
    @before             = nil
    @tumblr_db          = TumblrDatabase.new('sqlite.db')
    @tumblr_download    = TumblrDownload.new(image_dir)
    @tumblr_config      = Config.new(api_key, username)

    puts "\033[32mURL\033[0m"
    puts @tumblr_config.url

    puts "\n\033[32mUSERNAME\033[0m"
    puts @tumblr_config.username

    puts "\n\033[32mDIR\033[0m"
    puts @image_dir
    puts "\n"

    create_download_dir
  end


  def create_download_dir
    Dir.mkdir("./#{@image_dir}") unless File.directory?("./#{@image_dir}")
  end


  def get_liked_count
    response        = HTTParty.get(@tumblr_config.url + "&limit=1")
    parsed_response = JSON.parse(response.body)

    if parsed_response['meta']['status'] === 403
      puts "\033[31m#{"ERROR"}\033[0m"
      puts "Forbidden. Please, enable the 'Share posts you like' option in your tumblr settings"
      return -1
    elsif parsed_response['meta']['status'] === 401
      puts "\033[31m#{"ERROR"}\033[0m"
      puts "Unauthorized. Please, check your username and API_KEY"
      return -1
    end
    return parsed_response['response']['liked_count']
  end


  def get_photos(limit = 0)

    if @before
      response = HTTParty.get(@tumblr_config.url + "&limit=#{limit}&before=#{@before}")
    else
      response = HTTParty.get(@tumblr_config.url + "&limit=#{limit}")
    end

    parsed_response = JSON.parse(response.body)

    begin
      before = parsed_response['response']['_links']['next']['query_params']['before']
    rescue Exception => e
      puts "\033[31mERROR\033[0m: #{e}"
    end

    # Status of the request
    status_code = parsed_response['meta']['status']
    status_msg  = parsed_response['meta']['msg']

    if status_code != 200
      puts "\033[91m#{status_msg}\033[0m" 
      return
    end

    @tumblr_download.download_likes(parsed_response['response']['liked_posts'])
    @before = before
    return true
  end


  def start
    begin
      @download_num = get_liked_count
      if @download_num > 0
        download
      end

    rescue Exception => e
      puts "\033[31m#{"Error: #{e} "}\033[0m"
      puts "\033[31m#{"Error: #{e.backtrace.inspect} "}\033[0m"
    end
  end


  def download
    parsed = 0
    rest = @download_num % @limit
    if rest > 1
      rest = 1
    end

    batchs = (@download_num / @limit) + rest

    if (@download_num < @limit)
      batchs = 1
      @limit  = @download_num
    end

    puts "Downloading \033[32m#{@download_num}\033[0m posts\n"

    batchs.times do |i|
      if parsed + @limit > @download_num
        @limit = @download_num - parsed
      end
      result = get_photos(@limit)
      parsed += @limit
      break if !result
    end
    puts "\033[32m#{"Aaaaand we're done, parsed #{parsed} "}\033[0m"
  end
end

tumblr = TumblrPhotoExport.new(image_dir, limit, api_key, username)
tumblr.start
