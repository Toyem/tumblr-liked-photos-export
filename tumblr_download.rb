require 'httparty'
require 'fileutils'
require 'nokogiri'
require 'cgi'
require 'uri'

class TumblrDownload

  attr_accessor :image_dir, :tumblr_db

  def initialize(image_dir)
    @image_dir          = image_dir
    @tumblr_db          = TumblrDatabase.new('sqlite.db')
  end


  def download_likes(likes)
    
    likes.each do |like|

      # Show id
      puts "Id: \033[33m#{like['id']}\033[0m"
      puts "Made by \033[37m#{like['blog_name']}\033[0m"

      # Check database
      result = @tumblr_db.select_tumblr_master(like['id'])
      if result[0][0] > 0
        puts "   Post already downloaded"
      else
        # Prepare target folder
        download_path = "./#{@image_dir}/#{like['blog_name']}/#{like['id']}"
        FileUtils.mkdir_p("#{download_path}")

        err = 0
        # Extract body text
        err = download_body_text(like, download_path)
        # Extract caption
        err = download_caption(like, download_path)
        # Extract photos
        err = download_photos(like, download_path)
        # Extract videos
        err = download_video(like, download_path)
        # Extract trails
        err = download_trails(like, download_path)
        # Generate entry in database
        if err != -1
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
      puts "\033[31mERROR\033[0m: #{e}"
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
      puts "\033[31mERROR\033[0m: #{e}"
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
        file = File.basename(uri)
        image_id = File.basename(file, ".*")
        file_path = "#{download_path}/" + file
        File.open(file_path, "wb") do |f| 
          puts "      #{uri}"
          f.write HTTParty.get(uri).parsed_response
        end
        @tumblr_db.insert_tumblr_image(like['id'], image_id, like['blog_name'], file_path)
      rescue => e
        puts "\033[31mERROR\033[0m: #{e}"
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
        url_pattern = /https?:\/\/[\S]+/
        url = row_url.match(url_pattern)[0]
        file = File.basename(url)
        video_id = File.basename(file, ".*")
        uri = URI.parse(url)
        video = uri.open('rb')
        file_path = "#{download_path}/" + file
        File.open(file_path, "wb") do |f| 
          puts "      #{url}"
          f.write(video.read)
        end
        video.close
        @tumblr_db.insert_tumblr_video(like['id'], video_id, like['blog_name'], file_path)
      end
      return 0
    rescue => e
      puts "\033[31mERROR\033[0m: #{e}"
      return -1
    end
  end


  def download_trails(like, download_path)
    # Extract trails
    puts "   Download trails"
    err = 0
    trails = like['trail']
    pattern = /<img src="([^"]+)"/
    trails.each do |trail|
      begin
        # Find all matches of the pattern in the string
        matches = trail['content'].scan(pattern)
        # Extract the URLs from the matches
        urls = matches.map { |match| match[0] }

        urls.each do |url|
          file = File.basename(url)
          image_id = File.basename(file, ".*")
          file_path = "#{download_path}/" + file
          File.open(file_path, "wb") do |f| 
            puts "      #{url}"
            f.write HTTParty.get(url).parsed_response
          end
          @tumblr_db.insert_tumblr_image(like['id'], image_id, like['blog_name'], file_path)
        end
      rescue => e
        puts "\033[31mERROR\033[0m: #{e}"
        err = -1
      end
    end if trails
    return err
  end
end