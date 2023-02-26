require 'httparty'
require 'fileutils'
require 'nokogiri'
require 'cgi'
require 'net/http'
require 'uri'

class TumblrDownload

  attr_accessor :cpt, :image_dir, :tumblr_db

  def initialize(image_dir)
    @cpt                = 0
    @image_dir          = image_dir
    @tumblr_db          = TumblrDatabase.new('sqlite.db')
  end


  def download_likes(likes)
    
    likes.each do |like|
      @cpt += 1

      # Show id
      puts "Post # #{@cpt}"
      puts "Processing Post Id: \033[33m#{like['id']}\033[0m"
      puts "Made by \033[37m#{like['blog_name']}\033[0m"

      # Check database
      result = @tumblr_db.select_tumblr_master(like['id'])
      if result[0][0] > 0
        puts "   Post already downloaded in DB: #{like['id']}"
      else
        # Prepare target folder
        download_path = "./#{@image_dir}/#{like['blog_name']}/#{like['id']}"
        FileUtils.mkdir_p("#{download_path}")

        err = 0
        # Extract body text
        err += download_body_text(like, download_path)
        # Extract caption
        err += download_caption(like, download_path)
        # Extract photos
        err += download_photos(like, download_path)
        # Extract videos
        err += download_video(like, download_path)
        # Extract audio
        err += download_audio(like, download_path)
        # Extract trails
        err += download_trails(like, download_path)
        # Generate entry in database
        if err == 0
          @tumblr_db.insert_tumblr_master(like['id'], like['blog_name'], like['type'])
        end
      end
      
      puts ""
    end
  end


  def download_body_text(like, download_path)
    # Extract body text
    puts "   Download body text"
    begin
      html_body = like['body']
      doc_body = Nokogiri::HTML.parse(html_body)
      body_txt = doc_body.xpath('//p[not(ancestor::figure)]/node()').map(&:text).join("\n")
      body_txt = CGI.unescapeHTML(body_txt)
      File.write("#{download_path}/body_txt.txt", body_txt)
      puts "      #{download_path}/body_txt.txt"
      return 0
    rescue => e
      puts "\033[31mERROR: #{e}\033[0m"
      return -1
    end
  end


  def download_caption(like, download_path)
    # Extract caption
    puts "   Download caption"
    begin
      html_caption = like['caption']
      doc_caption = Nokogiri::HTML.parse(html_caption)
      caption = doc_caption.xpath('//p[not(ancestor::figure)]/node()').map(&:text).join("\n")
      caption = CGI.unescapeHTML(caption)
      File.write("#{download_path}/caption.txt", caption)
      puts "      #{download_path}/caption.txt"
      return 0
    rescue => e
      puts "\033[31mERROR: #{e}\033[0m"
      return -1
    end
  end


  def download_photos(like, download_path)
    # Extract photos
    puts "   Download photos"
    err = 0
    photos = like['photos']    
    photos.each do |photo|
      begin
        uri = photo['original_size']['url']
        file_path, image_id = make_download_link(uri, download_path)
        @tumblr_db.insert_tumblr_image(like['id'], image_id, like['blog_name'], file_path)
      rescue => e
        puts "\033[31mERROR: #{e}\033[0m"
        err = -1
      end
    end if photos
    return err
  end


  def download_video(like, download_path)
    # Extract video
    puts "   Download video"
    begin
      row_url = like['video_url']
      if !(row_url.nil?)
        file_path, video_id = make_download_link(row_url, download_path)
        @tumblr_db.insert_tumblr_video(like['id'], video_id, like['blog_name'], file_path)
      end
      return 0
    rescue => e
      puts "\033[31mERROR: #{e}\033[0m"
      return -1
    end
  end


  def download_audio(like, download_path)
    # Extract audio
    puts "   Download audio"
    begin
      row_url = like['audio_url']
      if !(row_url.nil?)
        if row_url.include?("soundcloud")
          raise NameError.new("Impossible to download soundcloud audio")
        end
        file_path, audio_id = make_download_link(row_url, download_path)
        @tumblr_db.insert_tumblr_audio(like['id'], audio_id, like['blog_name'], file_path)
      end
      return 0
    rescue => e
      puts "\033[31mERROR: #{e}\033[0m"
      return -1
    end
  end


  def make_download_link(row_url, download_path)
    url_pattern = /https?:\/\/[\S]+/
    url = row_url.match(url_pattern)[0]
    file = File.basename(url)
    id = File.basename(file, ".*")
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    link = http.get(uri.request_uri)
    file_path = "#{download_path}/" + file
    File.open(file_path, "wb") do |f| 
      puts "      #{url}"
      f.write(link.body)
    end
    return file_path, id
  end


  def download_trails(like, download_path)
    # Extract trails
    puts "   Download trails"
    err = 0
    trails = like['trail']
    trails.each do |trail|
      begin
        content_row = trail["content_raw"]
        if !(content_row.nil?)
          # Download images
          pattern_img = /<img src="([^"]+)"/
          urls = find_urls_pattern(content_row, pattern_img)
          urls.each do |url|
            file_path, image_id = make_download_link(url, download_path)
            @tumblr_db.insert_tumblr_image(like['id'], image_id, like['blog_name'], file_path)
          end

          # Download video
          pattern_vid = /<source src="([^"]+)"/
          urls = find_urls_pattern(content_row, pattern_vid)
          urls.each do |url|
            file_path, video_id = make_download_link(url, download_path)
            @tumblr_db.insert_tumblr_video(like['id'], video_id, like['blog_name'], file_path)
          end
        end
      rescue => e
        puts "\033[31mERROR: #{e}\033[0m"
        err = -1
      end
    end if trails
    return err
  end


  def find_urls_pattern(content, pattern)
    # Find all matches of the pattern in the string
    matches = content.scan(pattern)
    # Extract the URLs from the matches
    urls = matches.map { |match| match[0] }
    return urls
  end
end